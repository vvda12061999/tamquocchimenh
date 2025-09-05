import os
import re
import hashlib
import pathlib
from urllib.parse import urlparse, urljoin, unquote

try:
	import requests
	from bs4 import BeautifulSoup
except ImportError:
	raise SystemExit("Please install dependencies first: pip install requests beautifulsoup4")

# Configuration
PROJECT_ROOT = pathlib.Path(__file__).resolve().parents[1]
HTML_EXTENSIONS = {".html", ".htm"}
IMAGES_DIR = PROJECT_ROOT / "imgs"
IMAGES_DIR.mkdir(parents=True, exist_ok=True)

OLD_DOMAIN = "chienloantamquoc.vn"
NEW_DOMAIN = "tamquocchimenh.com"

# Consider these attributes as image sources: <img src>, <link rel="icon" href>, <meta property="og:image" content>
IMG_TAG_ATTRS = [
	("img", "src"),
	("link", "href"),  # we'll filter by rel attributes later
	("meta", "content"),  # we'll filter by property/name later
]

ICON_REL_VALUES = {"icon", "shortcut icon", "apple-touch-icon", "apple-touch-icon-precomposed"}
META_IMAGE_KEYS = {"og:image", "twitter:image", "og:image:secure_url"}

SESSION = requests.Session()
SESSION.headers.update({
	"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127 Safari/537.36"
})


def is_http_url(url: str) -> bool:
	return url.startswith("http://") or url.startswith("https://")


def sanitize_filename_from_url(url: str) -> str:
	parsed = urlparse(url)
	# decode path and strip query/hash
	path = unquote(parsed.path)
	name = os.path.basename(path) or "image"
	# Ensure we have an extension
	root, ext = os.path.splitext(name)
	if not ext:
		ext = ".img"
	# add short hash to avoid collisions and preserve uniqueness across query variants
	hash_suffix = hashlib.sha256(url.encode("utf-8")).hexdigest()[:10]
	clean_root = re.sub(r"[^A-Za-z0-9_.-]", "-", root)[:80] or "image"
	return f"{clean_root}-{hash_suffix}{ext}"


def download_image(url: str) -> str:
	filename = sanitize_filename_from_url(url)
	target_path = IMAGES_DIR / filename
	if target_path.exists() and target_path.stat().st_size > 0:
		return filename
	resp = SESSION.get(url, timeout=30)
	resp.raise_for_status()
	with open(target_path, "wb") as f:
		f.write(resp.content)
	return filename


def replace_domain_references(html_text: str) -> str:
	# Replace domain references in plain text and attributes
	html_text = html_text.replace("https://" + OLD_DOMAIN, "https://" + NEW_DOMAIN)
	html_text = html_text.replace("http://" + OLD_DOMAIN, "https://" + NEW_DOMAIN)
	html_text = html_text.replace(OLD_DOMAIN, NEW_DOMAIN)
	return html_text


def should_process_link_tag(tag) -> bool:
	rel = (tag.get("rel") or [])
	if isinstance(rel, list):
		rel_value = " ".join(rel).lower()
	else:
		rel_value = str(rel).lower()
	return any(val in rel_value for val in ICON_REL_VALUES)


def should_process_meta_tag(tag) -> bool:
	prop = (tag.get("property") or tag.get("name") or "").lower()
	return prop in {k.lower() for k in META_IMAGE_KEYS}


def process_html_file(file_path: pathlib.Path) -> None:
	text = file_path.read_text(encoding="utf-8", errors="ignore")
	# First, update domain references
	text = replace_domain_references(text)
	
	soup = BeautifulSoup(text, "html.parser")
	updated = False

	# Collect candidates
	candidates = []
	for tag_name, attr in IMG_TAG_ATTRS:
		for tag in soup.find_all(tag_name):
			if tag_name == "link" and not should_process_link_tag(tag):
				continue
			if tag_name == "meta" and not should_process_meta_tag(tag):
				continue
			url = tag.get(attr)
			if not url:
				continue
			if not is_http_url(url):
				# Skip non-http(s) references for image download
				continue
			candidates.append((tag, attr, url))

	for tag, attr, url in candidates:
		try:
			local_name = download_image(url)
			# Update reference to local path
			tag[attr] = f"imgs/{local_name}"
			updated = True
		except Exception as e:
			print(f"[WARN] Failed to download {url} referenced in {file_path.name}: {e}")

	if updated:
		# Write back pretty-printed HTML, but keep original as much as possible
		# Use original doctype and avoid reformatting by replacing body only would be complex; write full content.
		file_path.write_text(str(soup), encoding="utf-8")


def iter_html_files(root: pathlib.Path):
	for dirpath, _, filenames in os.walk(root):
		for name in filenames:
			if pathlib.Path(name).suffix.lower() in HTML_EXTENSIONS:
				yield pathlib.Path(dirpath) / name


def main():
	print(f"Project root: {PROJECT_ROOT}")
	print(f"Images dir: {IMAGES_DIR}")
	count = 0
	for html_file in iter_html_files(PROJECT_ROOT):
		if "\\imgs\\" in str(html_file) or "/imgs/" in str(html_file):
			continue
		print(f"Processing {html_file}")
		process_html_file(html_file)
		count += 1
	print(f"Processed {count} HTML files.")


if __name__ == "__main__":
	main()
