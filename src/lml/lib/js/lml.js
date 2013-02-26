var framework_height = 130;
var framework_datatables_height = framework_height + 80;
var min_window_height = 500;

/* customize above */

function myWindowHeight() {
	var w = $(window).height();
	if (w < min_window_height) {
		return (min_window_height);
	} else {
		return (w);
	}
}

$(document).ready(function() {
	$('a.tip').cluetip({
		attribute : 'href',
		activation : 'click',
		sticky : true,
		closePosition : 'title',
		arrows : true,
		width : 500,
		cluetipClass : 'rounded',
		ajaxCache : false,
		waitImage : true
	});

	$('#tabs').tabsLite();

	$('#vmlist_table').dataTable({
		"bPaginate" : false,
		"bProcessing" : true,
		"sScrollY" : ($(window).height() - framework_datatables_height),
		"sDom" : 'Tlfrtip', // T places TableTools
		"oTableTools" : {
			"sSwfPath" : "lib/swf/copy_csv_xls_pdf.swf"
		},
		"oLanguage" : {
			/* // without pagination only the total is interesting */
			"sInfo" : "Showing _TOTAL_ entries" 
		}
	});

	// adjust height of tabs content to fit into window
	$('.tabsLite-panel').css('height', (myWindowHeight() - framework_height));

	// jump to tab given by #tag in url
	if (location.hash) {
		/* click on link with this href */
		$('a[href="'+location.hash+'"]').trigger('click');
	}

});

$(window).resize(
		function() {
			$('.dataTables_scrollBody').css('height',
					(myWindowHeight() - framework_datatables_height));
			$('.tabsLite-panel').css('height',
					(myWindowHeight() - framework_height));
		});