var framework_height = 130;
var framework_datatables_height = framework_height + 110;
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
    $("#overview").append("<div id='waiting'><img src='lib/images/wait.gif' /></div>");

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
                $('#create_vm_form *').hide();
                $('#vm_create_error').hide();
                $('#new_vm_success_title').hide();
                $("#info_message").text( 'Please wait while the VM will be provisioned. This can take a while ...' );
                $('#new_vm_progress_title').show();
                $('#vm_create_info').show();
            },
            success: function(data) {
                $('#vm_create_error').hide();
                $('#new_vm_progress_title').hide();
                $('#new_vm_success_title').show();
                $("#info_message").text( 'The new VM was created with the UUID ' + data );
                $('#vm_create_info').removeClass("info");
                $('#vm_create_info').addClass("success");
                setTimeout(function(){
                    $('#new_vm_screenshot').attr('src', 'vmscreenshot.pl?stream=1;uuid=' + data );
                }, 13000);
            },
            error: function(request, status, error) {
                $('#vm_create_info').hide();
                $("#error_message").text(request.responseText);
                $('#vm_create_error').show();
            },
            url: "restricted/vm-create.pl",
            data: formData
        });
        return false;
    });

    $("#detonate_button").on('click', function(){
        var form_data = $("#vm_action_form").serialize() + "&action=detonate";
        $.ajax({
            type: "POST",
            beforeSend: function() {
                /* disable the form */
                $('#vm_action_form *').prop("disabled", "disabled");
                $('#waiting').show();
                /* deactivate previous error messages */
                $('#vm_action_error').hide();
                $('.dataTables_scrollBody').css('height',
                        (myWindowHeight() - framework_datatables_height));
            },
            success: function(data) {
                /* uncheck the checkbox of detonated machines */
                var json = $.parseJSON(data);
                $.each(json, function(index, value){
                    $('#' + value + " input[type='checkbox']").attr('checked', false);
                });
                /* reactivate the form */
                $('#vm_action_form *').removeAttr("disabled");
                $('#waiting').hide();
            },
            error: function(request, status, error) {
                $('#vm_action_error').show();
                $("#vm_action_error_message").text(request.responseText);
                /* resize the result table */
                $('.dataTables_scrollBody').css('height',
                        (myWindowHeight() - framework_datatables_height - $('#vm_action_error').outerHeight() - 8));
                /* reactivate the form */
                $('#vm_action_form *').removeAttr("disabled");
                $('#waiting').hide();
            },
            url: "restricted/vm-control.pl?action=detonate",
            data: form_data
        });
        return false;
    });

    $.fn.destroy = function() {
        var form_data = $("#vm_action_form").serialize() + "&action=destroy";
        $.ajax({
            type: "POST",
            beforeSend: function() {
                /* disable the form */
                $('#vm_action_form *').prop("disabled", "disabled");
                $('#waiting').show();
                /* deactivate previous error messages */
                $('#vm_action_error').hide();
                $('.dataTables_scrollBody').css('height',
                        (myWindowHeight() - framework_datatables_height));
            },
            success: function(data) {
                /* remove the destroyed vms from our list */
                var json = $.parseJSON(data);
                $.each(json, function(index, value){
                    $('#' + value).remove();
                });
                /* reactivate the form */
                $('#vm_action_form *').removeAttr("disabled");
                $('#waiting').hide();
            },
            error: function(request, status, error) {
                $('#vm_action_error').show();
                $("#vm_action_error_message").text(request.responseText);
                /* resize the result table */
                $('.dataTables_scrollBody').css('height',
                        (myWindowHeight() - framework_datatables_height - $('#vm_action_error').outerHeight() - 8));
                /* reactivate the form */
                $('#vm_action_form *').removeAttr("disabled");
                $('#waiting').hide();
            },
            url: "restricted/vm-control.pl?action=destroy",
            data: form_data
        });
        return false;
    };

    $("#dialog").dialog({
        modal: true,
        bgiframe: true,
        width: 450,
        height: 215,
        autoOpen: false,
        title: 'Really delete?'
    });

    $("a.confirm").click(function(link) {
        link.preventDefault();
        var message = $(this).attr("rel");

        // set windows content
        $('#dialog').html('<p>' + message + '</p>');

        $("#dialog").dialog('option', 'buttons', {
            "Delete" : function() {
                $(this).dialog("close");
                $.fn.destroy();
            },
            "Cancel" : function() {
                $(this).dialog("close");
            }
        });
        $("#dialog").dialog("open");
    });
});

$(window).resize(function() {
            $('.dataTables_scrollBody').css('height',
                    (myWindowHeight() - framework_datatables_height));
            $('.tabsLite-panel').css('height',
                    (myWindowHeight() - framework_height));
});