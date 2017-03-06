/*
* Handles requsting TOC from query string or meta tag
* Building html toc
* Setting selected node
*
* Requires jQuery, getParam, ifThen
*
* version 0.1
* September, 2016
* GK
*
* version 0.2
* Adding filtering
* October, 2016
*
* version 0.3
* changing filtering. Moving to a data-title attribute
* makeing text nodes triggers for expansion
* October, 2016
*
* version 0.4
* Adding breadcrumb handling
* November, 2016
*/

(function ($) {
	var urlTocQueryName = 'toc';
	var urlTocMetaName = 'toc_rel';
	var urlBcQueryName = 'bc';
	var urlBcMetaName = 'breadcrumb_path';
	var pagetypeMetaName = 'pagetype';

	var selectedClass = 'selected';
	var selectedHolderClass = 'selectedHolder';
	var rotateClass = 'rotate';
	var noSubsClass = 'noSubs';
	var noSibsClass = 'noSibs';
	var filterClassName = 'tocFilter';
	var emptyFilterClassName = 'emptyFilter';
	var emptyFilterMessageClassName = 'emptyFilterMessage';
	var hideFocusClass = 'hideFocus';
	var tocHolderSelector = '.toc';
	var filterHolderSelector = '.filterHolder';

	var breadcrumbClass = 'breadcrumbs';

	var eventNamespace = 'msDocs';

	var mTocSubNodeIndent = '&nbsp;&nbsp;&nbsp;';
	var noLinkClass = 'noLink';
	var mTocHolderSelector = '#menu-nav select';

	var isTouchEvent = false;
	/* this is used because the click target of the ul's is bigger than it should be (really bad in Chrome) when using touch.
	   when a touch event is initiated, the stopPropagation method is not called in the outter parts of a the element that is being used as a block.
	   the amount excluded is just a guess at this point.
	*/

	var timeout = 10000;
	var otherTocDelay = 510;    //how many milliseconds to wait until drawing secondary TOC

	var relativeCanonicalUrl = '';
	var relativeCanonicalUrlNoQuery = '';
	var relativeCanonicalUrlUniformIndex = '';
	var tocUrl = '';
	var tocFolder = '';
	var bcUrl = '';
	var bcFolder = '';
	var locale = '';
	var locationFolder = '';
	var $savedToc;
	var tocJson = [];

	var tocQueryUrl = msDocs.functions.getParam(urlTocQueryName);
	var tocMetaUrl = msDocs.functions.getParam(urlTocMetaName, 'meta');

	var bcQueryUrl = msDocs.functions.getParam(urlBcQueryName);
	if(bcQueryUrl){
		bcQueryUrl = decodeURIComponent(bcQueryUrl);
	}
	var bcMetaUrl = msDocs.functions.getParam(urlBcMetaName, 'meta');

	var pagetype = msDocs.functions.getParam(pagetypeMetaName, 'meta');
	var tocBestMatch = [];
	//This should have been a promise. Maybe change it someday
	var tocFinished = false;
	var bcFinished = false;

	var cleanTitle =  function(value) {
		if(value && value.length){
			return value
				.replace(/&/g, '&amp;')
				.replace(/"/g, '&quot;')
				.replace(/'/g, '&#39;')
				.replace(/</g, '&lt;')
				.replace(/>/g, '&gt;');
		}
		return value;
	};

	var breakDots =  function(str) {
		if(str && str.length){
			return str.split('.').join('\u200B.');
		}
		return str;
	};

	var resolveRelativePath = function(path, folder){
		if(!path || !path.length){
			return path;
		}

		folder = folder || locationFolder;
		var firstChar = path.charAt(0);

		if(firstChar === '/'){
			if((path.charAt(6) === '/') && (path.charAt(3) === '-')){
				return path;
			}
			return '/' + locale + path;
		}

		if((path.substr(0,7) === 'http://') || (path.substr(0,8) === 'https://')){
			return path;
		}

		if(firstChar !== '.'){
			return '/' + locale + folder + '/' + path;
		}

		if(path.substr(0,3) === '../'){
			return resolveRelativePath(path.substr(3), getFolder(folder));
		}

		if(path.substr(0,2) === './'){
			return '/' + locale + folder + '/' + path.substr(2);
		}

		return path;
	};

	var removeQueryString = function(path){
		if(path && path.length){
			var index = path.indexOf('?');
			if(index > 0){
				path = path.substring(0, index);
			}
		}
		return path;
	};

	var getUniformIndex = function(path){
		// if path ends with /, /index or /index.xxx, ruturn path up to last /, else return empty string
		if(path && path.length){
			if(path.charAt(path.length-1) == '/'){
				return path;
			}
			var whackIndex = path.lastIndexOf('/');
			var indexIndex = path.indexOf('index', whackIndex);
			if(indexIndex > 0){
				if(indexIndex == path.length-5){
					return path.substring(0, indexIndex);
				}
				var dotIndex = path.indexOf('.', whackIndex);
				if(dotIndex > 0){
					path = path.substring(0, dotIndex);
					if(path.substring(path.length-6) == '/index'){
						return path.substring(0, path.length-5);
					}
				}
			}
		}
		return '';
	};

	var getRelativeCanonicalUrl = function(removeTheQueryString){
		var canonicalUrl = $('link[rel="canonical"]').attr('href');
		if(canonicalUrl && canonicalUrl.length){
			if((canonicalUrl.substr(0,7) === 'http://') || (canonicalUrl.substr(0,8) === 'https://')){
				canonicalUrl = canonicalUrl.substring(canonicalUrl.indexOf('//')+2);
				canonicalUrl = canonicalUrl.substring(canonicalUrl.indexOf('/'));
			}
		}else{
			canonicalUrl = document.location.pathname;
		}
		canonicalUrl = msDocs.functions.removeLocaleFromPath(canonicalUrl);
		if(removeTheQueryString){
			canonicalUrl = removeQueryString(canonicalUrl);
		}
		return canonicalUrl;
	}

	var getFolder = function(path){
		return path.substring(0, path.lastIndexOf('/'));
	};

	var thisIsMe = function(href){
		href = href.toLowerCase();
		var hrefNoQuery = removeQueryString(msDocs.functions.removeLocaleFromPath(href));
		if(relativeCanonicalUrlNoQuery === hrefNoQuery){
			return true;
		}
		//Canonical is an index page
		if(relativeCanonicalUrlUniformIndex){
			if( href.lastIndexOf('/') == href.length-1 ){
				if(relativeCanonicalUrlUniformIndex === hrefNoQuery ){
					return true;
				}
			}

			//the word index comes after the last /
			if( href.indexOf('index', href.lastIndexOf('/')) > 0 ){
				if(relativeCanonicalUrlUniformIndex === getUniformIndex(hrefNoQuery) ){
					return true;
				}
			}
		}
		return false;
	};

	var toggleAriaExpanded = function(el){
		var $el = $(el);
		var $tempEl;
		var tempHeight;
		var hasGrandKids = false;

		if($el.attr('aria-expanded') == 'true'){

			$el.addClass(rotateClass).children('ul').each(function(i, el){
				var $tempEl = $(el);
				$tempEl.css({'height': $tempEl.height()}).animate({'height': 0}, 200, function(){
					$(this).css('height', '');
					$el.attr('aria-expanded', 'false').removeClass(rotateClass);
				});
			});
		}else{
			var $ulKids = $el.children('ul');

			$el.attr('aria-expanded', 'true');
			$ulKids.find('li').css('display', '');
			$ulKids.each(function(i, el){
				var $tempEl = $(el);
				tempHeight = $tempEl.height();
				$tempEl.css({'height': '0'}).animate({'height': tempHeight}, 200, function(){
					$(this).css('height', '');
				});
			});
		}
	};

	var stopSomePropagation = function(e, direction){
		switch (direction){
			case 'top':
				if(isTouchEvent){
					if(e.offsetY > 20){
						e.stopPropagation();
					}
				}else{
					e.stopPropagation();
				}
				break;
			case 'left':
				if(isTouchEvent){
					if(e.offsetX > 15){
						e.stopPropagation();
					}
				}else{
					e.stopPropagation();
				}
				break;
		}
	};

	var drawToc = function(json){
		var createTocNode = function(node, ul, nodeMap){
			var aNode;
			var href;
			var aCleanTitle;
			var nodeSelected = false;
			var displayName;

			nodeMap.push(-1);

			ul.setAttribute('aria-treegrid', 'true');
			ul.addEventListener('click', function(e){
				stopSomePropagation(e, 'top');
			});

			for(var i=0; i<node.length; i++){
				aNode = node[i];
				aCleanTitle = cleanTitle(aNode.toc_title);
				//if displayName exists on a TOC node, add it to the data-text attribute
				if (aNode.displayName && aNode.displayName.length) {
					displayName = cleanTitle(aNode.displayName);
				}
				else {
					displayName = "";
				}

				nodeMap[nodeMap.length-1] = i;

				var nextNode = document.createElement('li');
				var titleHolder;

				if(aNode.href && aNode.href.length){
					href = resolveRelativePath(aNode.href, tocFolder);
					titleHolder = document.createElement('a');
					if(i == 0){
						titleHolder.addEventListener('click', function(e){
							stopSomePropagation(e, 'left');
						});
					};
					titleHolder.setAttribute('tabindex', '1');
					if(thisIsMe(href)){
						titleHolder.classList.add(selectedClass);
						nodeSelected = true;
						if(!nodeMap.length || (tocBestMatch.length < nodeMap.length) ){
							tocBestMatch = nodeMap.slice(0);
						}
					}else{
						nodeSelected = false;
					};
					if(aNode.maintainContext){
						titleHolder.setAttribute('href', href + ((href.indexOf('?') > -1)? '&': '?') + tocUrlTerm + '&' + bcUrlTerm);
					}else{
						titleHolder.setAttribute('href', href);
					}
				}else{
					titleHolder = document.createElement('span');
				}

				titleHolder.setAttribute('data-text', aCleanTitle.toLowerCase() + " " + displayName.toLowerCase());
				titleHolder.innerHTML = breakDots(aCleanTitle);
				nextNode.appendChild(titleHolder);

				if(aNode.children && aNode.children.length){
					if(nodeSelected){
						nextNode.setAttribute('aria-expanded', 'true');
					}else{
						nextNode.setAttribute('aria-expanded', 'false');
					}
					nextNode.setAttribute('tabindex', '1');
					nextNode.setAttribute('aria-treeitem', 'true');
					nextNode.addEventListener('click', function(e){
						e.stopPropagation();
						toggleAriaExpanded(this);
					});
					hasGrandKids = false;
					for(var j=0; j<aNode.children.length; j++){
						if(aNode.children[j].children && aNode.children[j].children.length){
							hasGrandKids = true;
							break;
						}
					}
					if(!hasGrandKids){
						nextNode.classList.add(noSubsClass);
					}
					var nextUL = document.createElement('ul');
					createTocNode(aNode.children, nextUL, nodeMap.slice(0));
					nextNode.appendChild(nextUL);
				}

				ul.appendChild(nextNode);
			}
		};

		var createFilter = function(){
			var $filter = $('<form>')
				.addClass(filterClassName)
				.submit(function(e){
					e.preventDefault();
				})
				.append(
					$('<input>')
						.attr('placeholder', 'Filter')
						.attr('aria-label', 'Filter')
						.attr('type', 'search')
						.keypress(function(e) {
							if ( e.which === 13 ) {
								e.preventDefault();
								return;
							}
						})
						.keyup(function(){
							filterToc(this);
						})
				)
				.append(
					$('<a>')
						.attr('href', '#')
						.attr('title', 'clear filter')
						.addClass('clearInput')
						.html('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><g><path class="bar" d="M6,6l14,14Z" /></g><g><path class="bar" d="M20,6l-14,14Z" /></g></svg>')
						.on('click', function(e){
									e.stopPropagation();
									e.preventDefault();
									var ipt = $('.' + filterClassName + ' input[type=search]');
									ipt.val('');
									filterToc(ipt);
								})
				);

			//TODO: This needs to be internationalized
			var $noResults = $('<div>')
				.addClass(emptyFilterMessageClassName)
				.html('No results');

			return [$filter, $noResults];
		};

		var toc = document.createElement('ul');

		createTocNode(json, toc, []);

		var $toc = $(toc);
		$toc.find('.' + selectedClass).parent().addClass(selectedHolderClass).parents('li[aria-expanded="false"]').attr('aria-expanded', 'true');
		$toc.on('touchstart pointerdown MSPointerDown', function(e){
			if(e.type == 'touchstart' || ( ( (e.type == 'pointerdown') || (e.type == 'MSPointerDown') ) && (e.originalEvent.pointerType == 'touch') ) ){
				isTouchEvent = true;
				setTimeout(function(){
					isTouchEvent = false;
				}, 700);
			}
		})
		.on('mousedown', function(e){
			$(this).addClass(hideFocusClass);
		})
		.on('mouseup', function(e){
			$(e.target).blur().parent().blur();
			$(this).removeClass(hideFocusClass);
		})
		.on('keypress', 'li', function(e){
			if(e.which == '13' && !$toc.hasClass(noSibsClass)){
				e.stopPropagation();
				toggleAriaExpanded($(this));
			}
		})
		.on('keypress', 'a', function(e){
			if(e.which == '13'){
				e.stopPropagation();
			}
		});

		if(json.length == 1){
			$toc.addClass(noSibsClass);
			$toc.children('li').attr('aria-expanded', 'true').off('click.' + eventNamespace).removeAttr('tabindex');
		}

		var arrfilter = createFilter();


		$(function () {
			//there is only one tocHolder, and toc is up to date, so fall back to native append. Save almost 100ms in IE11 for a 9000 node toc
			$(tocHolderSelector).attr('role', 'application')[0].appendChild(toc);
			$(filterHolderSelector).prepend(arrfilter);

			setTimeout(function(){
				msDocs.functions.setTocHeight(0, true);
			}, 200);

			tocFinished = true;
			if(bcFinished && msDocs.settings.extendBreadcrumb){
				extendBc();
			}
		});
	};

	var drawMToc = function(json){
		/* create mobile toc. This will be removed soon, so it is built as a completely seperate creation path */

		var createMTocNode = function(node, indent, $mToc){
			var aNode;
			var href;

			for(var i=0; i<node.length; i++){
				aNode = node[i];

				$mToc
					.append(
						$('<option>')
							.html(indent + cleanTitle(aNode.toc_title))
							.ifThen((aNode.href && aNode.href.length),
								function(){
									href = resolveRelativePath(aNode.href, tocFolder);
									if(aNode.maintainContext){
										this.attr('value', href + ((href.indexOf('?') > -1)? '&': '?') + urlTocQueryName + '=' + encodeURIComponent(tocUrl) + '&' + urlBcQueryName + '=' + encodeURIComponent(bcUrl));
									} else {
										this.attr('value', href);
									}
									if(thisIsMe(href)){
										this.attr('selected', 'selected');
									}
								},
								function(){
									this.addClass(noLinkClass);
								}
							)
					)
					.ifThen((aNode.children && aNode.children.length),
						function(){
							createMTocNode(aNode.children, indent + mTocSubNodeIndent, $mToc);
						}
					);
			}
		};

		var $mToc = $('<select>')
			.on('change', function(){
				var target = $(this).find('option:selected').attr('value');
				if(target && target.length){
					$(location).attr('href', target);
				}
			});
		createMTocNode(json, '', $mToc);
		$(function () {
			$(mTocHolderSelector).replaceWith($mToc);
		});
	};

	var filterToc = function(inputField){
		var val = cleanTitle($(inputField).val().toLowerCase());
		var $tocHolder = $(tocHolderSelector);
		var $filterHolder = $(filterHolderSelector);

		$filterHolder.removeClass(emptyFilterClassName);

		if(val && val.length){
			$('.' + filterClassName).addClass('clearFilter');

			var resultIsEmpty = true;
			var $currentToc = $tocHolder.children('ul[aria-treegrid="true"]').detach();
			if(!$savedToc){
				$savedToc = $currentToc.clone(true, true);
			}
			$currentToc.find('li').css('display', 'none').filter('[aria-expanded]').attr('aria-expanded', 'false');
			var $this;
			$currentToc.find('a, span').each(function(a){
				$this = $(this);
				if($this.attr('data-text').indexOf(val) !== -1 ){
					resultIsEmpty = false;
					$this.parents('li').css('display', '').filter('[aria-expanded]').not($this.parent()).attr('aria-expanded', 'true');
				}
			});
			$tocHolder.append($currentToc);
			if(resultIsEmpty){
				$filterHolder.addClass(emptyFilterClassName);
			}
		}else if($savedToc){
			$('.' + filterClassName).removeClass('clearFilter');

			$tocHolder.children('ul[aria-treegrid="true"]').replaceWith($savedToc);
			$savedToc = null;
		}
	};

	var getTocData = function(url, fallbackToMeta){
		$.ajax({
			url: url,
			dataType: 'json',
			timeout: timeout
		})
		.done(function(data, textStatus, jqXHR){
			tocUrl = resolveRelativePath(url)
			tocFolder = getFolder(msDocs.functions.removeLocaleFromPath(tocUrl));
			tocJson = jqXHR.responseJSON


			if( window.matchMedia( "(max-width: 768px)" ).matches ){
				drawMToc(jqXHR.responseJSON);

				$(function(){
					setTimeout(function(){
						drawToc(jqXHR.responseJSON);
					}, otherTocDelay);
				});
			}else{
				drawToc(jqXHR.responseJSON);

				$(function(){
					setTimeout(function(){
						drawMToc(jqXHR.responseJSON);
					}, otherTocDelay);
				});
			}
		})
		.fail(function(){
			if(fallbackToMeta && tocMetaUrl && tocMetaUrl.length){
				getTocData(tocMetaUrl);
			};
		});
	};

	var extendBc = function(){
		//this can only run after DOM ready and should only be called after toc and bc have been drawn
		var $breadcrumbs = $('.' + breadcrumbClass);

		var addNodeToBc = function(node, bestMatch){
			var href = node.href;
			var aCleanTitle = breakDots(cleanTitle(node.toc_title));

			$breadcrumbs.ifThen( !href || !href.length || (!bestMatch.length && (relativeCanonicalUrlUniformIndex === getUniformIndex(node.href).toLowerCase())),
				function(){
					this.append(
						$('<li>').html(aCleanTitle)
					);
				},
				function(){
					this.append(
						$('<li>').append(
							$('<a>')
								.attr('href', resolveRelativePath(href, tocFolder))
								.html(aCleanTitle)
						)
					);
				}
			);

			if( bestMatch.length && node.children && node.children.length ){
				addNodeToBc(node.children[bestMatch.shift()], bestMatch);
			}
		};

		if(tocBestMatch.length){
			addNodeToBc(tocJson[tocBestMatch.shift()], tocBestMatch);
		}
	};

	var drawBc = function(json){
		var relativeCanonicaFolder = getFolder(relativeCanonicalUrlNoQuery) + '/';	//relativeCanonicalUrlNoQuery is all lowercase
		var bestMatch = [];
		var $breadcrumbs = $('<ul>').addClass(breadcrumbClass);
		var node;
		var nodeHrefNoQuery;

		var findBestMatch = function(json, nodeMap){
			//this will find the deepest match. First match at that level wins.
			nodeMap.push(-1);

			for(var i=0; i<json.length; i++){
				node = json[i];
				nodeMap[nodeMap.length-1] = i;

				if(!nodeMap.length || (bestMatch.length < nodeMap.length) ){
					if (node.href) {
						nodeHrefNoQuery = node.href.split('?')[0].toLowerCase();
						if(relativeCanonicaFolder.indexOf(nodeHrefNoQuery) ===  0  || relativeCanonicalUrlNoQuery === nodeHrefNoQuery) {
							bestMatch = nodeMap.slice(0);
						}
					}
				}

				if(node.children && node.children.length){
					findBestMatch(node.children, nodeMap.slice(0));
				}
			}
		};

		var makeDisplayHtml = function($breadcrumbs, node, bestMatch){
			var href =  node.homepage || node.href || '';
			var aCleanTitle = breakDots(cleanTitle(node.toc_title));

			$breadcrumbs.ifThen( !href || !href.length || (!bestMatch.length && (relativeCanonicalUrlUniformIndex === getUniformIndex(node.href).toLowerCase())),
				function(){
					this.append(
						$('<li>').html(aCleanTitle)
					);
				},
				function(){
					this.append(
						$('<li>').append(
							$('<a>')
								.attr('href', resolveRelativePath(href, bcFolder))
								.html(aCleanTitle)
						)
					);
				}
			);

			if( bestMatch.length && node.children && node.children.length ){
				makeDisplayHtml($breadcrumbs, node.children[bestMatch.shift()], bestMatch);
			}
		};

		findBestMatch(json, []);
		if( bestMatch.length ){
			makeDisplayHtml($breadcrumbs, json[bestMatch.shift()], bestMatch);
		}

		$(function () {
			$('.' + breadcrumbClass).replaceWith($breadcrumbs);
			bcFinished = true;
			if(tocFinished && msDocs.settings.extendBreadcrumb){
				extendBc();
			}
		});
	};

	var getBcData = function(url, fallbackToMeta){
		$.ajax({
			url: resolveRelativePath(url),
			dataType: 'json',
			timeout: timeout
		})
		.done(function(data, textStatus, jqXHR){
			bcUrl = url;
			bcFolder = getFolder(msDocs.functions.removeLocaleFromPath(bcUrl));
			drawBc(jqXHR.responseJSON);
		})
		.fail(function(){
			if(fallbackToMeta && bcMetaUrl && bcMetaUrl.length){
				getBcData(bcMetaUrl);
			};
		});
	};

	/* start here */
	relativeCanonicalUrl = getRelativeCanonicalUrl();
	relativeCanonicalUrlNoQuery = getRelativeCanonicalUrl(true).toLowerCase();
	relativeCanonicalUrlUniformIndex = getUniformIndex(relativeCanonicalUrlNoQuery);
	locale = msDocs.functions.getLocaleFromPath(document.location.pathname);
	locationFolder = getFolder(msDocs.functions.removeLocaleFromPath(document.location.pathname));

	if(tocQueryUrl && tocQueryUrl.length){
		tocQueryUrl = decodeURIComponent(tocQueryUrl);
		tocQueryUrl = resolveRelativePath(tocQueryUrl);
		getTocData(tocQueryUrl, true);
	}else if(tocMetaUrl && tocMetaUrl.length){
		getTocData(tocMetaUrl);
	}

	var hideBc = msDocs.functions.getParam('hide_bc', 'meta');
	if(hideBc === undefined || hideBc !== 'true') {
		if(bcQueryUrl && bcQueryUrl.length){
			getBcData(bcQueryUrl, true);
		}else if(bcMetaUrl && bcMetaUrl.length){
			getBcData(bcMetaUrl);
		}
	}

})(jQuery);