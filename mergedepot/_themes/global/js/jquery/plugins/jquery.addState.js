/*
*
* Useful when you have an exclusive state that an element can be in.
* Example, airlinePassenger could be in the 'location_' state:
* 'inParkingLot'
* 'atCounter'
* 'atSecurity'
* 'atGate'
* 'onPlane'
* Only one of these states should be applied at any one time.
* The state is stored as a class with the name: namespace+state
* example: 'location_onPlane
*
* $('someSelector').addState(namespace, state)
* This will remove all classes that begin with the string: namespace and add a class: namespace+newClass
*
* $('someSelector').toggleState(namespace, state [, switch])
* functions the same as .toggleClass()
*
* $('someSelector').removeState(namespace)
* This will remove all classes that begin with the string: namespace
*
* Written with jQuery 1.10.2 and tested on this version
* Should work with all versions of jQuery.
*
* version 0.2
* January, 2014
* GK
*/


(function ($) {

	$.fn.removeState = function (namespace) {
		$(this).each(function () {
			var $this = $(this);
			if ($this.attr("class") && $this.attr("class").indexOf(namespace) >= 0) {
				var otherClasses = $.grep( $this.attr("class").split(" "), function(aClass) {
					return aClass.lastIndexOf(namespace, 0) !== 0;
				});
				$this.attr("class", otherClasses.join(" "));
			}
		});
		return this;
	};

	$.fn.addState = function (namespace, state) {
		this.removeState(namespace);
		this.addClass(namespace + state);
		return this;
	};

	$.fn.toggleState = function (namespace, state, switchVal) {
		var $this = $(this);
		if (typeof switchVal === "boolean") {
			if (switchVal) {
				$this.addState(namespace, state);
			} else {
				$this.removeClass(namespace + state);
			}
			return this;
		}

		if ($this.hasClass(namespace + state)) {
			$this.removeClass(namespace + state);
		} else {
			$this.addState(namespace, state);
		}
		return this;
	};

})(jQuery);