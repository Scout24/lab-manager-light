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

if (typeof String.prototype.startsWith != 'function') {
	String.prototype.startsWith = function(str) {
		return this.slice(0, str.length) == str;
	};
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
		$('a[href="' + location.hash + '"]').trigger('click');
	}

	var tools_content = $("#tools_content");
	var tools_title = $("#tools_title");
	var tools_frame = $("#tools_frame");
	tools_frame.hide();

	var clear_tools_frame = function() {
		tools_content.html("");
		tools_title.html("");
		tools_frame.hide();

	};

	clear_tools_frame();

	// tools buttons
	$("#clear_button").click(clear_tools_frame);

	$("#tools a.button").click(function() {
		var title = $(this).attr("title");
		var source = $(this).attr("href");
		tools_frame.show();
		tools_title.html(title);
		tools_content.html("Loading ...");
		$.get(source, function(data, status, xhr) {
			var content_type = xhr.getResponseHeader('Content-Type');
			if (content_type.startsWith("application/json") || typeof data == "object") {
				data = $("<pre>").html(JSON.stringify(data, null, 2));
			} else if (content_type.startsWith("text/plain")) {
				data = $("<pre>").html(data);
			}
			tools_content.html(data);
		});
		return false;
	});

    $("#create_vm_form").submit(function(event) {
        /* stop form from submitting normally */
        event.preventDefault();
        var formData = $("#create_vm_form").serialize();
        $.ajax({
            type: "POST",
            beforeSend: function() {
                $('#create_vm_form *').prop("disabled", "disabled");
                $('#vm_create_error').hide();
                $('#vm_create_success').hide();
                $('#vm_create_info').show();
            },
            success: function(data) {
                $('#vm_create_info').hide();
                $('#vm_create_error').hide();
                $("#success_message").text(data);
                $('#vm_create_success').show();
                $('#create_vm_form *').removeAttr("disabled");
            },
            error: function(request, status, error) {
                $('#vm_create_info').hide();
                $('#vm_create_success').hide();
                $("#error_message").text(request.responseText);
                $('#vm_create_error').show();
                $('#create_vm_form *').removeAttr("disabled");
            },
            url: "vm-create.pl",
            data: formData
        });
        return false;
    });
});

$(window).resize(
		function() {
			$('.dataTables_scrollBody').css('height',
					(myWindowHeight() - framework_datatables_height));
			$('.tabsLite-panel').css('height',
					(myWindowHeight() - framework_height));
		});