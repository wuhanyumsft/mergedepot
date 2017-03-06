var updateSearchForm = function(){
	var $searchForm = $('#searchForm');

	//update action locale
	$searchForm.attr('action', 'https://docs.microsoft.com/' + msDocs.data.userLocale + '/search/index')
		.find('#search').removeAttr('name');

	//insert search scope element	
	var scopes = msDocs.functions.getParam('scope', 'meta');
	var hideScope = msDocs.functions.getParam('hideScope', 'meta');

	if(hideScope === 'true')
	{
		scopes = undefined;
	}

	var isSearchPage = false;
	if(scopes === undefined){
		isSearchPage = $("body.searchPage").length > 0;
		if(isSearchPage){
			scopes = msDocs.functions.getParam('scope');
		}            
	}

	if(scopes != undefined){
		var scopesArr = scopes.split(", ");
		if(scopesArr.length){
			//TODO: get from localization when available
			var searchScopeInfo = "Search filter set to ";
			var searchScopeAction = "Tap to remove filter.";

			var scopeStr = scopesArr[scopesArr.length-1];

			if(isSearchPage){
				//scrub input
				var sv = encodeURIComponent(decodeURIComponent(scopeStr.replace(/\+/g, " ")));
				sv = sv.replace(/%23/g, "#").replace(/%20/g, " ").replace(/%2b/gi, "+").replace(/%22/g, '"');
				scopeStr = sv.replace(/%26/g, "&").replace(/%3c/gi, "<").replace(/%3e/gi, ">").replace(/%2f/gi, "/").replace(/%5c/gi, "\\");
			}

			var $link = $("<a>")
						.addClass("searchScope")
						.attr("href", "#")                            
						.on('click', function(e){
							e.stopPropagation();
							e.preventDefault();                                
							$(this).remove();
							$searchForm.find('input[name="scope"]').remove();
							$searchForm.find('input[name="search"]').animate({'padding-left': '10px'}, 'fast');
						})
						.attr("title", searchScopeInfo + " '" + scopeStr + "'. " + searchScopeAction)
						.text(scopeStr);
			
			$searchForm.append($link);
			$searchForm.find('input[name="search"]').css("padding-left", ($link.width() + 34) + 'px');

			var $input = $("<input>")
							.attr('type', 'hidden')
							.attr('name', 'scope')
							.attr('value', scopeStr)

			$searchForm.append($input);
		}
	}
}

var loadUhfCss = function(uhfData, callback){
	if(!uhfData || !uhfData.cssIncludes || !uhfData.cssIncludes.length){
		return;	
	}

	if (document.createStyleSheet){
		//IE10 support
		for (i = 0; i < uhfData.cssIncludes.length; i++) {
			document.createStyleSheet(uhfData.cssIncludes[i]);
		}
	} else {
		var $head = $("head");
		for (i = 0; i < uhfData.cssIncludes.length; i++) {			
			$head.append($('<link rel="stylesheet" href="' + uhfData.cssIncludes[i] + '" type="text/css" media="all" />'));
		}
	}

	//workaround to get css read callback
	var cssUrl = uhfData.cssIncludes[0];
	var img = document.createElement('img');
	img.onerror = function(){
		if(callback){
			callback(uhfData);
		} 
	}
	img.src = cssUrl;
}

var getUhfData = function(){
	if(msDocs.data.brand === 'azure') {
		return;
	}

	//retrieve header id
	var uhfHeaderId = msDocs.functions.getParam('uhfHeaderId', 'meta');
	if(!uhfHeaderId) {
		uhfHeaderId = 'MSDocsHeader-DocsL1';
	}

	var uhfUrl = 'https://docs.microsoft.com/api/GetUHF?locale=' + msDocs.data.userLocale + '&headerId=' + uhfHeaderId + '&footerId=MSDocsFooter';

	$.ajax({
		url: uhfUrl,
		dataType: 'json',
		timeout: 10000
	})
	.done(function(data, textStatus, jqXHR){		
		var uhfData = jqXHR.responseJSON;
		loadUhfCss(uhfData, function(uhfData) {
			$(function(){
				$('#uhfPlaceHolder').replaceWith($(uhfData.headerHTML));
				updateSearchForm();

				//cancel Search Suggestions
				var shellOptions = {
					as: {
						callback: function () {}
					}
				};

				if (window.msCommonShell) {
					window.msCommonShell.load(shellOptions);
				} else {
					window.onShellReadyToLoad = function () {
						window.onShellReadyToLoad = null;
						window.msCommonShell.load(shellOptions);
					};
				}
			});
		});
	});
};
getUhfData();