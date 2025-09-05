var base_url_path = typeof BASE_URL_PATH != "undefined" ? BASE_URL_PATH : "";
// console.log(base_url_path);
// if(base_url_path === '') {
//     var pathname = window.location.pathname;
//     pathname = pathname.split("/");
//     var strgame = pathname[1];
//     base_url_path = BASE_URL + '/' + strgame;
// }

function isLogin() {
  //   jQuery
  //     .ajax({
  //       method: "POST",
  //       url: base_url_path + "/is-login.html",
  //       dataType: "json",
  //     })
  //     .done(function (msg) {
  //       if (msg.isLogin == true) {
  //         jQuery("#login-box").html(msg.result);
  //         jQuery("#btn_dk_tk").removeClass("DangKy").addClass("TaiKhoan");
  //         jQuery("#btn_dk_tk").attr("title", "Tài khoản");
  //         is_login = true;
  //       }
  //     });
}

function login() {
  if (!jQuery("input#username").val()) {
    alert("Vui lòng nhập tên đăng nhập");
    jQuery("input#username").focus();
    return false;
  }
  if (!jQuery("input#user_password").val()) {
    alert("Vui lòng nhập mật khẩu");
    jQuery("input#user_password").focus();
    return false;
  }
  $("#user_password").val(MD5($("#user_password").val()));
  $("#login").submit();
}

var bolSubmit = false;
var objPassword = jQuery("input#user_password");
function submitLogin() {
  if (bolSubmit) {
    return false;
  }
  var t = objPassword.val() ? MD5(objPassword.val()) : "";
  objPassword.val(t);
  bolSubmit = true;
  return true;
}

function refreshCaptcha() {
  jQuery("#captcha").attr("src", base_url_path + "/captcha.png");
}

function getThuCuoi(id) {
  jQuery
    .ajax({
      method: "POST",
      url: base_url_path + "/thu-cuoi.html",
      data: {
        id: id,
      },
      dataType: "json",
    })
    .done(function (data) {
      if (data.error == 1) {
        console.log("Không lấy được thú cưỡi");
      }
      jQuery("#" + id).html(data.html);
      Skill();
    });
}

jQuery(document).ready(function () {
  jQuery("#login").attr(
    "action",
    PAY_URL + "/dang-nhap.html?ref=" + encodeURIComponent(document.URL)
  );
  jQuery(".ul-tab-new li:not(.last-child) a").click(function () {
    var url = jQuery(this).attr("data-url");
    jQuery("#viewmore").attr("href", url);
  });
  $("#login").keydown(function (event) {
    // enter has keyCode = 13, change it if you want to use another button
    if (event.keyCode == 13) {
      return $(this).submit();
    }
  });
  /*getThuCuoi('canh');
    getThuCuoi('than');
    getThuCuoi('thucuoi');
    getThuCuoi('phapbao');
    getThuCuoi('binh');*/
});
jQuery(document).on("click", "#btn_play", function (e) {
  e.stopImmediatePropagation();
  var url = jQuery("#server-boxlogin").val();
  if (url == "") {
    alert("Vui lòng chọn server!");
    return;
  }
  window.location.href = url;
});
