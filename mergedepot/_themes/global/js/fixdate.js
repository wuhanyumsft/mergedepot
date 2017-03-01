	$(function() {
        var timeSelect = $("time[datetime]");
        timeSelect.each(function () {
            var backToDate = new Date(this.getAttribute("datetime"));
            $(this).text(backToDate.toLocaleDateString());
        });
		$(".metadata .meta").removeClass("loading");
    });
