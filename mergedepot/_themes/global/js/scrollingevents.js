(function ($) {

	var isPinned = false;
	var pinBuffer = 18;
	var footerBuffer = 150;
	var footerTop = 99999;
	var footerDiff = 0;
	var isFooterVisible = false;
	var currentDocOutlineItemIndex = -1;
	var desktopWidth = 1024;

	var pageActionContentClass = "#page-actions-content";
	var sidebarContentClass = "#sidebarContent";

	msDocs.data.h2Tops = [];
	msDocs.data.isOutlineHighlighted = false;
	var isPageActionsAvailable = false;
	var isSidebarAvailable = false;
	msDocs.data.savedWindowWidth = $(window).width();
	msDocs.data.savedWindowHeight = $(window).height();

	msDocs.functions.updateH2Tops = function(isRefresh) {
		if(msDocs.data.isOutlineHighlighted)
		{
			msDocs.data.h2Tops = [];
			var mainh2s = $('main h2');

			if(mainh2s.length > 1) {
				mainh2s.each(function(){
					msDocs.data.h2Tops.push(Math.floor($(this).offset().top-10));
				});

				if(isRefresh){
					msDocs.functions.updateDocOutlineSelection($(window).scrollTop());
				}

				return true;
			} else {
				return false;
			}
		}
	}

	msDocs.functions.selectDocOutlineItem = function(index, override){
		if(!override && currentDocOutlineItemIndex === index) {
			return;
		}

		currentDocOutlineItemIndex = index;
		$(".doc-outline li").removeClass('selected');

		var $selectedLi = $(".doc-outline li:eq(" + index + ")");
		$selectedLi.addClass('selected');

		if(isPinned)
		{
			var liTop = $selectedLi.position().top;

			var $pac = $(pageActionContentClass);
			var st = $pac.scrollTop();
			var ht = $pac.height();

			if(liTop + 24 - st > ht - st)
			{
				var inc = liTop + 24 - ht + st;
				if(override) {
					$pac.scrollTop(inc);
				} else {
					$pac.animate({ scrollTop: inc }, "fast");
				}
			}
			else if(liTop < 0){
				var dec = st + liTop;
				if(override) {
					$pac.scrollTop(dec);
				} else {
					$pac.animate({ scrollTop: dec }, "fast");
				}
			}
		}
	}

	msDocs.functions.updateDocOutlineSelection = function(scrollTop){
		var h2Tops = msDocs.data.h2Tops;
		for (i = 0; i < h2Tops.length; i++) {
			if(i === 0 && h2Tops.length > 1 && h2Tops[1] > scrollTop){
				msDocs.functions.selectDocOutlineItem(0);
				break;
			}
			else if(i === h2Tops.length-1 && h2Tops[i] < scrollTop) {
				msDocs.functions.selectDocOutlineItem(i);
				break;
			}
			else if(h2Tops[i] <= scrollTop && h2Tops[i+1] > scrollTop) {
				msDocs.functions.selectDocOutlineItem(i);
				break;
			}
		}
	};

	msDocs.functions.setTocHeight = function(heightOffset, isFirstRun){
		var $toc = $(".toc");
		if(!$toc.length){
			return;
		}

		var tocTop = 24;
		var fhh = $(".filterHolder").height() + 24; //fhh padding-top
		var pdh = $(".pdfDownloadHolder").height();		
		if(pdh > 0)
		{
			pdh += 34; //pdh margin-top + bottom buffer
		} else {
			pdh = 10; //bottom buffer
		}

		if(!isPinned) {
			tocTop += $("#sidebar").offset().top;
		}

		var mh = msDocs.data.savedWindowHeight - tocTop - fhh - pdh - heightOffset;
		if(mh < 32){
			mh = 32;
		}

		$toc.css("max-height", mh + "px");

		if(isPinned) {
			$(".tocSpace").height(($(sidebarContentClass).height() + pinBuffer * 6) + "px");
		}

		if(isFirstRun && $toc.scrollTop() === 0)
		{
			setTimeout(function() {
				var $selectedLinks = $(".toc a.selected");
				if($selectedLinks.length > 0)
				{
					var $link = $($selectedLinks[0]);
					var totalOffset = 0;
					$link.parentsUntil(".toc").each(function( index ) {
						if($(this).prop("tagName") == "LI")
						{
							totalOffset += $(this).position().top;
						}
					});
					totalOffset = totalOffset - $(".toc").height();
					$toc.scrollTop(totalOffset);
				}
			}, 200);
		}
	}

	$(function(){
		isPageActionsAvailable = $(pageActionContentClass).length > 0;
		isSidebarAvailable = $(sidebarContentClass).length > 0;
		msDocs.data.isOutlineHighlighted = $(".doc-outline").length > 0;

		if(msDocs.data.isOutlineHighlighted)
		{
			msDocs.data.isOutlineHighlighted = msDocs.functions.updateH2Tops(false);
			if(msDocs.data.isOutlineHighlighted) {
				setTimeout(function(){
					msDocs.functions.selectDocOutlineItem(0);
				}, 40);
			}
		}

		if(msDocs.data.isOutlineHighlighted || isPageActionsAvailable || isSidebarAvailable) {

			$(window).scroll(function() {
				var scrollTop = $(window).scrollTop();

				if(msDocs.data.isOutlineHighlighted) {
					msDocs.functions.updateDocOutlineSelection(scrollTop);
				}

				if(isPageActionsAvailable || isSidebarAvailable) {
					if (scrollTop > 145) {
						if(!isPinned) {
							isPinned = true;
							setFooterTop();
							setPinnedPositions();
						}

						//TODO: remove safety check once footer insert is changed
						if(footerTop === 99999)
						{
							setFooterTop();
						}

						evalFooterState(scrollTop);
					} else {
						if(isPinned) {
							isPinned = false;
							setStaticPositions();
						}
					}
				}
			});

			$(window).resize(function() {
				msDocs.data.savedWindowHeight = $(window).height();

				var w = $(window).width();
				if(msDocs.data.savedWindowWidth !== w)
				{
					msDocs.data.savedWindowWidth = w;
					msDocs.functions.updateH2Tops(true);
				}

				if(isSidebarAvailable) {
					if(!isPinned) {
						msDocs.functions.setTocHeight(0, false);
					}
				}

				if(isPageActionsAvailable || isSidebarAvailable) {
					setFooterTop();

					if(isPinned) {
						setPinnedPositions();
						evalFooterState($(window).scrollTop());
					}
				}
			});
		}

		var evalFooterState = function(scrollTop){
			if(scrollTop + msDocs.data.savedWindowHeight > footerTop) {
				footerDiff = scrollTop + msDocs.data.savedWindowHeight - footerTop;
				isFooterVisible = true;
				setPinnedPositions();
				if(msDocs.data.isOutlineHighlighted) {
					msDocs.functions.selectDocOutlineItem(currentDocOutlineItemIndex, true);
				}
			} else {
				if(isFooterVisible)
				{
					isFooterVisible = false;
					setPinnedPositions();
					if(msDocs.data.isOutlineHighlighted) {
						msDocs.functions.selectDocOutlineItem(currentDocOutlineItemIndex, true);
					}
				}
			}
		}

		var setFooterTop = function(){
			var $ft = $("#footer");
			if($ft.length > 0) { //safety check needed due to current footer replcement technique
				footerTop = $ft.offset().top;
			}
		}

		var setPinnedPositions = function(){
			if(isPageActionsAvailable){
				var $pac = $(pageActionContentClass);

				if(msDocs.data.savedWindowWidth >= desktopWidth){
					$pac.css({"top": pinBuffer + "px", "width": ($("#page-actions").innerWidth() - pinBuffer) + "px"});
				} else {
					$pac.css({"top": "0", "width": "100%"});
				}

				$pac.addClass("pinned-actions");
				if(isFooterVisible){
					$pac.css("max-height", (msDocs.data.savedWindowHeight - footerDiff - pinBuffer * 2) + "px");
				} else {
					$pac.css("max-height", (msDocs.data.savedWindowHeight - pinBuffer * 2) + "px");
				}
			}

			if(isSidebarAvailable){
				var $sc = $(sidebarContentClass);
				$sc.css({"top": pinBuffer + "px", "width": $("#sidebar").innerWidth() + "px"});

				$(".tocSpace").height(($sc.height() + pinBuffer * 6) + "px");

				$sc.addClass("fixed");
				if(isFooterVisible){
					msDocs.functions.setTocHeight(footerDiff, false);
				} else {
					msDocs.functions.setTocHeight(0, false);
				}
			}
		}

		var setStaticPositions = function(){
			$(pageActionContentClass).css({"width": "auto", "max-height": "none"})
				.removeClass("pinned-actions");

			$(sidebarContentClass).css("width", "auto")
				.removeClass("fixed");

			$(".tocSpace").height("0");

			msDocs.functions.setTocHeight(0, false);
		};
	});
})(jQuery);