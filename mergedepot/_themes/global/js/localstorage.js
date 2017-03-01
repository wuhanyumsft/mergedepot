/*!
 * get and set local storage.
 *
 * Assumes msDocs.functions
 *
* version 0.1
* September, 2016
* GK
*/;(function(){
	msDocs.functions.setLocalStorage = function(key, value){
		if(!value){
			window.localStorage.removeItem(key);
		}else{
			window.localStorage.setItem(key, value);
		}
	};

	msDocs.functions.getLocalStorage = function(key){
		return window.localStorage.getItem(key);
	};
})();
