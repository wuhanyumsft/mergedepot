/*
* Handles theme switching, storing and loading
*
* Requires jQuery, loclStorage.js, jquery.addState
*
* version 0.2
* September, 2016
* GK
*/

(function ($) {
	var selectorId = 'theme-selector';
	var storageName = 'theme';
	var classNamespace = 'theme';
	var placeholderClass = 'removedOnload';

	var getStorageValue = function(){
		return msDocs.functions.getLocalStorage(storageName);
	};

	var updateThemeClass = function(){
		var currentTheme = getStorageValue();
		if(currentTheme && currentTheme.length){
			currentTheme = currentTheme.replace( classNamespace, '');
			$('html').addState(classNamespace, currentTheme);
			if (currentTheme === '_night')
			{
				currentTheme = 'dark';
			}
			msDocs.data.currentTheme = currentTheme;
		} else {
			$('html').removeState(classNamespace);
			msDocs.data.currentTheme = 'light';
		}
	};

	$.lald('#' + selectorId, 'change', function(e){
		var currentValue = $(this).val();
		if(currentValue && currentValue.length){
			msDocs.functions.setLocalStorage(storageName, currentValue);
		} else {
			msDocs.functions.setLocalStorage(storageName);
		}

		updateThemeClass();
	});

	updateThemeClass();
	$(function(){
		var $selector = $('#' + selectorId);
		$selector.find('.' + placeholderClass).remove();

		var currentTheme = getStorageValue();
		if(currentTheme && currentTheme.length){
			$selector.val(currentTheme);
		}
	});

})(jQuery);