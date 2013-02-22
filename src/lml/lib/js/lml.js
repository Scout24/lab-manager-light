$(document).ready(function() {
	$('a.tip').cluetip({
		attribute: 'href',
		activation: 'click',
		sticky: true,
		closePosition: 'title',
		arrows: true,
		width: 500,
		cluetipClass: 'rounded',
		ajaxCache: false,
		waitImage: true
	});
	$('#tabs').tabsLite();
});
