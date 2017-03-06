(function($){
    $.fn.oldReady = $.fn.ready;
    $.fn.ready = function(fn){
        return $.fn.oldReady( function(){ try{ if(fn) fn.apply($,arguments); } catch(e){}} );
    }
})(jQuery);