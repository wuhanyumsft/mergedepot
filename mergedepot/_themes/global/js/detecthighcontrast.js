$(function(){
	var $div = $('<div>')
				.css({"position": "absolute","top": "0","left": "-2300px","background-color": "#878787"})
				.text('hc')
				.appendTo("body");
	var testcolor = $div.css("background-color").toLowerCase();
	$div.remove();
	if (testcolor != "#878787" && testcolor != "rgb(135, 135, 135)") {
		$('html').addClass('highContrast');
	}
});