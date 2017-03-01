$('html').removeClass('no-js').addClass('js');

if(('ontouchstart' in window) || window.DocumentTouch && document instanceof DocumentTouch) {
    $('html').addClass('hasTouch');
} else {
    $('html').addClass('noTouch');
}