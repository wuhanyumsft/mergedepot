(function ($) {
	var azureHeaderAPIServer = 'https://azure.microsoft.com/';
	var azureHeaderAPIPath = '/asset/header/';
	var azureHeaderAPI = azureHeaderAPIServer + msDocs.data.userLocale + azureHeaderAPIPath;
	var azureJsAPIServer = 'https://azure.microsoft.com/';
	var azureJsAPIPath = '/asset/menujs/';
	var azureJsAPI = azureJsAPIServer + msDocs.data.userLocale + azureJsAPIPath;
	var headerHolderClass = 'azure-header_temp';

	var getHeader = $.get(azureHeaderAPI);
	var getJs = $.get({
			url: azureJsAPI,
			dataType: 'text'
		});

	$.when(getHeader, getJs).done(function(headerHTML, headerJs){
		$(function(){
			$('.' + headerHolderClass).replaceWith(headerHTML[0]);
			//yep, eval :)
			eval(headerJs[0]);
		});
	});

})(jQuery);