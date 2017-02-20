(function ($) {
	msDocs.functions.renderPdfLink = function(){
		var urlTocQueryName = 'toc';
		var pdfUrl = msDocs.functions.getParam('pdf_url_template', 'meta');
		var tocQueryUrl = msDocs.functions.getParam(urlTocQueryName);
		if(pdfUrl !== undefined && tocQueryUrl === undefined)
		{			
			var branchName = msDocs.functions.cookies.get("CONTENT_BRANCH");
			if(typeof branchName === 'undefined') {
				branchName = "live";
			}

			pdfUrl = pdfUrl.replace(/\{branchName\}/, branchName);

			//TODO: change to loc 'downloadPdf' when available
			var downloadText = "Download PDF";
			var $div = $(".pdfDownloadHolder");
			if($div.length){
				var $link = $("<a href='" + pdfUrl + "' ms.cmpnm='downloadPdf'>" + downloadText + "</a>");
				$div.append($link);
				$div.show();
			}
		}
	};

	$(function(){
		msDocs.functions.renderPdfLink();
	})

})(jQuery);