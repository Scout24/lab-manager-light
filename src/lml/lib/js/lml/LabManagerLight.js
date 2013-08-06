(function () {
  "use strict";

  window.lml = window.lml || {};

  angular.module('lml-app', [])
  .controller('LmlController', lml.LmlController)
  .controller('VmOverviewController', lml.VmOverviewController)
  .controller('NewVmController', lml.NewVmController)
  .controller('HostOverviewController', lml.HostOverviewController)
  .controller('ConfigurationController', lml.ConfigurationController)
  .controller('ToolsController', lml.ToolsController)
  .service('AjaxCallService',  lml.AjaxCallService )
  .config(function($routeProvider) {
    $routeProvider.
    when('/vm-overview', {templateUrl:'/lml/lib/html/vm_overview.html'}).
    when('/new-vm', {templateUrl:'/lml/lib/html/new_vm.html'}).
    when('/host-overview', {templateUrl:'/lml/lib/html/host_overview.html'}).
    when('/tools', {templateUrl:'/lml/lib/html/tools.html'}).
    when('/configuration', {templateUrl:'/lml/lib/html/configuration.html'}).
    otherwise({redirectTo:'/vm_overview'});
  })
  .run(function run($rootScope){

  $rootScope.globals = {activeTab : "vm_overview"};


    // TODO: Do it in angular style
    window.framework_height = 130;
    window.framework_datatables_height = framework_height + 110;
    window.min_window_height = 500;

    /* customize above */
    // TODO: Do it in angular style
    window.myWindowHeight = function myWindowHeight() {
      var w = $(window).height();
      if (w < min_window_height) {
        return (min_window_height);
      } else {
        return (w);
      }
    }

  // TODO: Do it in angular style
    if (typeof String.prototype.startsWith != 'function') {
      String.prototype.startsWith = function(str) {
        return this.slice(0, str.length) == str;
      };
    }

    // TODO: Do it in angular style
    $(document).ready(function() {
      $("#vm_overview").append("<div id='waiting'><img src='lib/images/wait.gif' /></div>");

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



    });

    // TODO: Do it in angular style
    $(window).resize(function() {
      $('.dataTables_scrollBody').css('height',
        (myWindowHeight() - framework_datatables_height));
      $('.tabsLite-panel').css('height',
        (myWindowHeight() - framework_height));
    });

  })
})();
