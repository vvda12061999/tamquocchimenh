(function ($) {
    var loginIframe = null;
    var registerIframe = null;

    // Function to create backdrop
    function createBackdrop() {
        if ($('#auth-backdrop').length === 0) {
            $('<div>', {
                id: 'auth-backdrop',
                css: {
                    position: 'fixed',
                    top: 0,
                    left: 0,
                    width: '100%',
                    height: '100%',
                    background: 'rgba(0, 0, 0, 0.5)',
                    zIndex: 9999,
                    display: 'none',
                    cursor: 'pointer' // Indicate clickable backdrop
                },
                click: function () {
                    // Close all open iframes when backdrop is clicked
                    closeIframe('login');
                    closeIframe('register');
                }
            }).appendTo('body');
        }
    }

    // Function to show backdrop
    function showBackdrop() {
        createBackdrop();
        $('#auth-backdrop').fadeIn(300);
    }

    // Function to hide backdrop
    function hideBackdrop() {
        $('#auth-backdrop').fadeOut(300, function () {
            $(this).remove();
        });
    }

    // Function to create iframe container
    function createIframeContainer(type) {
        var containerId = type === 'login' ? 'login-iframe-container' : 'register-iframe-container';
        if ($(`#${containerId}`).length === 0) {
            var isMobile = $(window).width() <= 768;
            $('<div>', {
                id: containerId,
                css: {
                    position: 'fixed',
                    top: '50%',
                    left: '50%',
                    transform: 'translate(-50%, -50%)',
                    width: isMobile ? '80%' : '500px',
                    height: '600px',
                    background: '#fff',
                    zIndex: 10000,
                    boxShadow: '0 4px 8px rgba(0,0,0,0.2)',
                    display: 'none',
                    overflow: 'hidden' // Prevent scrolling in container
                }
            }).appendTo('body');

            // Add close button
            $(`#${containerId}`).append(
                $('<button>', {
                    text: 'Close',
                    css: {
                        position: 'absolute',
                        top: '10px',
                        right: '10px',
                        padding: '5px 10px',
                        cursor: 'pointer',
                        zIndex: 10001,
                        background: '#f44336',
                        color: '#fff',
                        border: 'none',
                        borderRadius: '3px'
                    },
                    click: function () {
                        closeIframe(type);
                    }
                })
            );
        }
    }

    // Function to open login iframe
    function openLoginIframe(url) {
        createIframeContainer('login');
        showBackdrop();
        $('#login-iframe-container').html(
            $('<iframe>', {
                id: 'login-iframe',
                src: url,
                scrolling: 'no', // Disable iframe scrolling
                css: {
                    width: '100%',
                    height: '100%',
                    border: 'none'
                }
            })
        ).fadeIn(300);
        loginIframe = $('#login-iframe')[0];
    }

    // Function to open register iframe
    function openRegisterIframe(url) {
        createIframeContainer('register');
        showBackdrop();
        $('#register-iframe-container').html(
            $('<iframe>', {
                id: 'register-iframe',
                src: url,
                scrolling: 'no', // Disable iframe scrolling
                css: {
                    width: '100%',
                    height: '100%',
                    border: 'none'
                }
            })
        ).fadeIn(300);
        registerIframe = $('#register-iframe')[0];
    }

    // Function to close a specific iframe
    function closeIframe(type) {
        if (type === 'login' && loginIframe) {
            $('#login-iframe-container').fadeOut(300, function () {
                $(this).remove();
                loginIframe = null;
            });
        } else if (type === 'register' && registerIframe) {
            $('#register-iframe-container').fadeOut(300, function () {
                $(this).remove();
                registerIframe = null;
            });
        }
        // Only hide backdrop if no iframes are open
        if (!loginIframe || !registerIframe) {
            hideBackdrop();
        }
    }

    // Listen for postMessage events from the iframes
    $(window).on('message', function (event) {
        var origin = event.originalEvent.origin;
        // For security, replace '*' with your allowed origin(s), e.g., 'https://yourdomain.com'
        if (origin !== window.location.origin && origin !== '*') {
            return; // Ignore messages from untrusted origins
        }
        var data = event.originalEvent.data;
        if (data && data.event === 'login_success' && typeof window.onLoginSuccess === 'function') {
            window.onLoginSuccess(data.data || {});
            closeIframe('login');
        } else if (data && data.event === 'register_success' && typeof window.onRegisterSuccess === 'function') {
            window.onRegisterSuccess(data.data || {});
            closeIframe('register');
        }
    });

    // Expose the library as a global object
    window.AuthLib = {
        openLogin: openLoginIframe,
        openRegister: openRegisterIframe,
        closeLogin: function () {
            closeIframe('login');
        },
        closeRegister: function () {
            closeIframe('register');
        }
    };
})(jQuery);