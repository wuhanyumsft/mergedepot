/*
*
* These functions assume locale is at the begining of path, begins with /, is 5 characters long and charater 3 is -
*
* GK
* 11/2016
*
*/

(function ($) {
	msDocs.functions.getLocaleFromPath = function(path){
		if(path && (path.charAt(0) === '/') && (path.charAt(6) === '/') && (path.charAt(3) === '-')){
			return path.substr(1,5);
		}
		return path;
	};

	msDocs.functions.removeLocaleFromPath = function(path){
		if(path && (path.charAt(0) === '/') && (path.charAt(6) === '/') && (path.charAt(3) === '-')){
			return path.substr(6);
		}
		return path;
	};

	msDocs.data.userLocale = msDocs.functions.getLocaleFromPath(location.pathname);

})(jQuery);