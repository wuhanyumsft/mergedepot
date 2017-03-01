/* Copyright (c) 2006 Mathias Bank (http://www.mathias-bank.de)
* Dual licensed under the MIT (http://www.opensource.org/licenses/mit-license.php)
* and GPL (http://www.opensource.org/licenses/gpl-license.php) licenses.
*
* Thanks to Hinnerk Ruemenapf - http://hinnerk.ruemenapf.de/ for bug reporting and fixing.
*/
/*
*
* Reworked from original, and added ability to specify 'search', 'hash', or 'meta' with a name value
* The 'meta' option requires jQuery
*
* GK
* 09/2016
*
*/


(function ($) {
	msDocs.functions.getParam = function(paramName, type){
		if(type === 'meta' && $){
			return $('meta[name="' + paramName + '"]').attr('content');
		} else {
			var frag = (type === 'hash') ? window.location.hash : window.location.search;
			if (frag && frag.length>0) {
				frag = frag.substring(1);
				var cmpstring = paramName + "=";
				var cmplen = cmpstring.length;
				var temp = frag.split("&");
				for (var i = 0; i < temp.length; i++) {
					if (temp[i].substr(0, cmplen) == cmpstring) {
						return temp[i].substr(cmplen);
					}
				}
			}
			return undefined;
		}
	};
})(jQuery);