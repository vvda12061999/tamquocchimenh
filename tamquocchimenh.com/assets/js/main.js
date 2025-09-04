var widthWD;
var heightWD;



jQuery(document).ready(function () {
  widthWD = jQuery(window).width();
  heightWD = jQuery(document).height();

  
  jQuery(document).click(function() {
  //   if(play()) {
  //     stop();
  //   } else {
  //     play();
  //   }
  })
  jQuery(document).trigger( "click" );
  new Swiper('.banner-slider', {
    pagination: {
      el: '.banner-slider-swiper-pagination',
      type: "bullets",
      clickable: true
    },
    // autoplay: {
    //   delay: 3000,
    //   disableOnInteraction: false
    // },
    navigation: {
      nextEl: '.banner-slider-next',
      prevEl: '.banner-slider-prev',
    },
    loop: true
  });


  /*---- Top Button -----*/
  jQuery('.top').click(function () {
    jQuery('html, body').animate({ scrollTop: 0 }, 300);
  });
  /*---- End Top Button -----*/

  jQuery(document).on('click', '.call-popup', function (event) {
    showPopup(jQuery(this).attr('data-popup'));
  })

  /*- Fancy box -*/
  jQuery(".fancybox").fancybox({
    type: "iframe",
    padding: 0,
    fitToView: false,
    width: '100%',
    height: '100%',
    openEffect: 'true',
    closeEffect: 'true',
    autoplay: 'true'
  });


})
jQuery(window).on('load', function () {
  // showPopup('popup-giftcode');

  /*--- Character slider ---*/
  for (let i = 1; i <= jQuery('.character-swiper-large').length; i++) {
    new Swiper('.character-swiper-large-'+i, {
      spaceBetween: 0,
      loop: true,
      autoplay: {
        delay: 5000,
        disableOnInteraction: false,
        pauseOnMouseEnter: true,
      },
      navigation: {
        nextEl: '.character-button-next',
        prevEl: '.character-button-prev'
      },
      
      thumbs: {
        swiper: {
          el: '.character-swiper-nav-'+i,
          navigation: {
            nextEl: '.nav-button-next',
            prevEl: '.nav-button-prev'
          },
          spaceBetween: 0,
          // slidesPerColumn: 1,
          // direction: 'row',
          observer: true,
          observeParents: true,
          // loop: true,
          // speed: 1000,
          slidesPerView: 3,
          spaceBetween: 0,
          // centeredSlides: true
        }
      },
      observer: true,
      observeParents: true
    });
  }



  new Swiper('.dacsac-slider', {
    loop: true,
    speed: 1000,
    autoplay: {
      delay: 5000,
    },
    pagination: {
      el: '.dacsac-slider-swiper-pagination',
      type: "bullets",
      clickable: true
    },
    // effect: 'coverflow',
    grabCursor: true,
    centeredSlides: true,
    // slidesPerView: 2,
    // observer: true,
    // observeParents: true,
    // coverflowEffect: {
    //     rotate: 0,
    //     stretch: 140,
    //     depth: 130,
    //     modifier: 1,
    //     slideShadows: false,
    // },

    // Navigation arrows
    navigation: {
        nextEl: '.next-btn',
        prevEl: '.prev-btn',
    },
  })


  /*- Tabs -*/
  jQuery('.tab-content > ').not(".active").hide();
  jQuery(document).on('click', '[role="tab"]:not(.active)', function (event) {
    jQuery(this).parent().siblings('li').find('a').removeClass('active');
    jQuery(this).addClass('active');
    jQuery(this).parent().parent().siblings('.tab-content').find('> *').hide().removeClass('active');
    var _tabID = $(this).data('tab');
    jQuery('#'+_tabID).fadeIn(300).addClass('active');   
  });
});;


function showPopup(object) {
  if(jQuery('.popup-bg').length == 0) {
    jQuery(".popup").prepend('<div class="popup-bg"></div>');
  }
  jQuery("." + object).parent().addClass('active');
  
  jQuery(document).on('click', '.popup-bg,.popup-close', function (event) {
    jQuery("." + object).parent().removeClass('active');
  });
  
}

jQuery(".floating").on('click', '.close-btn', function() {
  jQuery('.floating').toggleClass("back");
});