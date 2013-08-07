  
window.lml = window.lml || {};


window.lml.ToolsController = function ToolsController($scope) {

	$scope.globals.activeTab = 'tools';



	// TODO: do this in angular style
	var tools_content = $("#tools_content");
	var tools_title = $("#tools_title");
	var tools_frame = $("#tools_frame");
	tools_frame.hide();

	// TODO: do this in angular style
	var clear_tools_frame = function() {
		tools_content.html("");
		tools_title.html("");
		tools_frame.hide();

	};

	// TODO: do this in angular style
	clear_tools_frame();
 	
 	// tools buttons
    $("#clear_button").click(clear_tools_frame);

    // TODO: do this in angular style
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

};

