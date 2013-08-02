(function () {
  "use strict";

window.lml = window.lml || {};

angular.module('lml-app', [])
    .controller('VmOverviewController', lml.VmOverviewController)
    .controller('NewVmController', lml.NewVmController)
    .controller('ConfigurationController', lml.ConfigurationController)
    .service('AjaxCallService',  lml.AjaxCallService )
})();
