/// <reference path="jquery.ifThen.js" />
/*!
* ifThen
*
* Written with jQuery 1.10.2 and tested on this version
* Should work with all versions of jQuery.
*
*
* Use this when doing long chaining. It creates an 'if', 'else if', 'else' option in the chain.
* At least 2 arguments must be passed.
* The first arguement will be evaluated for truethyness. If truethy and the next arguement is a function, then the next argument will be called and the orignal jquery object will be returned, providing an 'if'.
* If false, the next two arguments will be handled in the same way, providing an 'else if'.
* If there is only one argument remaining, and it is a function, it will be called and the orignal jquery object will be returned, provideing an 'else'.
* In all cases, the orignal jquery object will be returned.
*
*
* Example
*
* var testObj = [
* 	{
* 		name: 'name 1',
* 		email: 'name1@aol.com',
* 		isAdmin: true,
* 		userType: 'public'
* 	},
* 	{
* 		name: 'name 2',
* 		email: '',
* 		isAdmin: true,
* 		userType: 'paid'
* 	},
* 	{
* 		name: 'name 3',
*		email: 'name2@aol.com',
* 		isAdmin: false,
* 		reports:[
* 			{
* 				name: 'name 5',
* 				email: 'name5@aol.com',
* 				isAdmin: true
* 			},
* 			{
* 				name: 'name 6',
* 				email: '',
* 				isAdmin: false,
* 				userType: 'public'
* 			},	{
* 				name: 'name 7',
* 				email: 'name7@aol.com',
* 				isAdmin: false,
* 				userType: 'edu'
* 			},
* 			{
* 				name: 'name 8',
* 				email: '',
* 				isAdmin: false
* 			}
* 		]
* 	},
* 	{
* 		name: 'name 4',
* 		email: '',
* 		isAdmin: false,
* 		userType: 'public'
* 	},
* 	{
*		name: 'name 9',
* 		email: '',
* 		isAdmin: false,
* 		userType: 'paid'
* 	},
* 	{
* 		name: 'name 10',
* 		email: '',
* 		isAdmin: false,
*		userType: 'edu'
* 	}
* ];
*
* var makePeopleList = function(people) {
*
* 	var $obj = $('<ul></ul>')
*

* 	$.each(people, function(i, person){
* 		$('<li></li')
* 			.addClass('person')
* 			.ifThen(person.isAdmin, function(){
* 					this.addClass('admin');
* 				}
* 			)
* 			.ifThen(person.userType === 'public', function(){
* 					this.addClass('public');
* 				},
* 				person.userType === 'paid', function(){
* 					this.addClass('paid');
* 				},
* 				person.userType === 'edu', function(){
* 					this.addClass('edu');
* 				}
* 			)
* 			.ifThen(person.reports, function(){
* 					this.addClass('manager');
* 				}
* 			)
* 			.append(
* 				$('<div></div')
* 				.addClass('name')
* 				.ifThen(person.email.length > 0, function(){
* 						this.append(
* 							$('<a></a>')
* 							.attr('href', 'mailTo:'+ person.email)
* 							.text(person.name)
* 						);
* 					},
* 					function(){
* 						this.text(person.name);
* 					}
* 				)
* 			)
* 			.ifThen(person.reports, function(){
* 				this.append(makePeopleList(person.reports))
* 			})
* 		.appendTo($obj);
* 	});
*
* 	return $obj;
*
* };
*
* version 1.0
* April 22, 2014
* GK
*
*
*/

jQuery.fn.extend({
	ifThen: function () {
		var args = arguments;

		if (args.length < 2) {
			return this;
		}

		for (var i = 0; i < args.length; i = i + 2) {
			if (args[i] && jQuery.isFunction(args[i + 1])) {
				args[i + 1].call(this);
				return this;
			}
		}

		if (args.length % 2 && (typeof args[args.length - 1] === "function")) {
			args[args.length - 1].call(this);
		}

		return this;
	}
});