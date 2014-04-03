angular.module('lml-app')
  .controller('HostOverviewController', function HostOverviewController($scope, $log, AjaxCallService) {
    "use strict";

    $scope.hosts = [];
    $scope.globals.activeTab = 'host_overview';

    $scope.setServerRequestRunning(true);
    var result_promise = AjaxCallService.get('api/host_overview.pl', function successCallback(data) {
      $log.info("Received hosts data for overview: ", data);
      $scope.hosts = data.host_overview_json.hosts;
      $scope.setServerRequestRunning(false);
    }, function errorCallback() {
      $scope.setServerRequestRunning(false);
    });

  });


