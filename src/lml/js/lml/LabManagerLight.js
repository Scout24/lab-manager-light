(function () {
  "use strict";

  window.lml = window.lml || {};

  angular.module('lml-app', ['ui.bootstrap', 'ngCsv','ui.bootstrap.position'])
    .directive('remotePictureTooltip', lml.TooltipPictureDirective)
    .directive('remoteTooltip', lml.TooltipDirective)
    .controller('LmlController', lml.LmlController)
    .controller('VmOverviewController', lml.VmOverviewController)
    .controller('NewVmController', lml.NewVmController)
    .controller('HostOverviewController', lml.HostOverviewController)
    .controller('ConfigurationController', lml.ConfigurationController)
    .controller('ToolsController', lml.ToolsController)
    .controller('MainController', lml.MainController)
    .service('AjaxCallService', lml.AjaxCallService)
    .config(function ($routeProvider) {
      $routeProvider.
        when('/vm-overview', {templateUrl: 'html/vm_overview.html'}).
        when('/new-vm', {templateUrl: 'html/new_vm.html'}).
        when('/host-overview', {templateUrl: 'html/host_overview.html'}).
        when('/tools', {templateUrl: 'html/tools.html'}).
        when('/configuration', {templateUrl: 'html/configuration.html'}).
        otherwise({redirectTo: '/vm-overview'});
    })
    .run(function run() {

      if (typeof String.prototype.startsWith != 'function') {
        String.prototype.startsWith = function (str) {
          return this.slice(0, str.length) == str;
        };
      }

    });
})();
