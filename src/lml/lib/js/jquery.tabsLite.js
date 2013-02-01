//
// jquery.tabsLite.1.0.js
//
// A lighter version of jQuery UI's tabs. For when you
// just need simple tab functionality and don't need
// to include the entire jQuery UI library.
//
//
// REQUIRED HTML:
//
// <div id="tabs">
//   <ul>
//     <li><a href="#tab-1">Tab One</a></li>
//     <li><a href="#tab-2">Tab Two</a></li>
//   </ul>
//   <div id="tab-1">
//     <p>Tab one.</p>
//   </div>
//   <div id="tab-2">
//     <p>Tab two.</p>
//   </div>
// </div>
//
//
// REQUIRED JS:
//
// $('#tabs').tabsLite();
//
(function( $ ){
	$.fn.tabsLite = function() {
		
		this.each(function() {
			var mainDiv = $(this);
			var tabs = mainDiv.children('ul').children('li');
			var panels = mainDiv.children('div');
			var selectedTab = panels.first();
			
			mainDiv.addClass('tabsLite-mainDiv');
			tabs
				.addClass('tabsLite-tab')
				.first()
				.addClass('tabsLite-tab-selected');
			panels
				.addClass('tabsLite-panel')
				.hide()
				.first()
				.show()
				.addClass('tabsLite-panel-selected');
			
			tabs.click(function(){
				selectedTab = $(this).children('a').attr('href');
				
				tabs.removeClass('tabsLite-tab-selected');
				panels
					.hide()
					.removeClass('tabsLite-panel-selected');
				
				$(this).addClass('tabsLite-tab-selected');
				$(selectedTab)
					.show()
					.addClass('tabsLite-panel-selected');
				
			}).children('a').click(function(event){
				event.preventDefault();
			});
		});
		
		return this;
	
	};
})( jQuery );