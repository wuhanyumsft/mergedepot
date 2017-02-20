/*!
* Live and Let Die
*
* Requires jquery 1.7 +
*
*
* Two plugins: Live and Let Die and Live and Die
*
* Live and Let Die:
* This allows events to be attached before the DOM is ready
* Before DOM has loaded, delegated $(document).on() events are used
* When DOM is ready, .off() removes the delegated events and events are directly bond
*
*
* Live and Die:
* This simply attaches delegated events to the document and then removes them when the DOM is ready
*
*
* syntax:
* $.lald( selector, event [, data ], handler(eventObject) )
* $.lad( selector, event [, data ], handler(eventObject) )
*
*
* version 0.2
* February 3, 2010
* GK
*
* version 0.3
* August 4, 2011
* Bug fix to check for arg3 when binding. jQuery 1.6.2+ does not work with undefined or null as the 3rd argument of .bind()
* GK*
*
* version 0.3
* August 13, 2013
* Totally rewritten to use .on() and .off() instead of .live() and .die()
* Has new api
* Currently only supports single 'event' per call, not 'events' like .on. Clould be modified in the future to support 'events'
* GK
*
*/

(function ($) {
	var domReady = false;
	var $document = $(document);

	var handleAttachment = function (selector, event, arg1, arg2, namespace) {
		var namespacedEvent = event + '.' + namespace;
		var data = arg2 ? arg1 : null;
		var handler = arg2 ? arg2 : arg1;

		if (!domReady) {
			if (data) {
				$document.on(namespacedEvent, selector, data, handler);
			} else {
				$document.on(namespacedEvent, selector, handler);
			}
		}

		$(function () {
			domReady = true;
			$document.off(namespacedEvent, selector, handler);	//should handler be included here?
			if (namespace === 'lald') {
				if (data) {
					$(selector).on(namespacedEvent, data, handler);
				} else {
					$(selector).on(namespacedEvent, handler);
				}
			}
		});

	};

	$.lald = function (selector, event, arg1, arg2) {
		handleAttachment(selector, event, arg1, arg2, 'lald');
	};

	$.lad = function (selector, event, arg1, arg2) {
		handleAttachment(selector, event, arg1, arg2, 'lad');
	};

}(jQuery));