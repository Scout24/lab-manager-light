angular.module('lml-app')
  .controller('ConfigurationController', function ConfigurationController($scope, $log, AjaxCallService) {
    "use strict";
    $scope.data = "";
    $scope.files = [];
    $scope.globals.activeTab = 'configuration';

    $scope.setServerRequestRunning(true);
    AjaxCallService.get('api/configuration.pl', function successCallback(data) {
      //$log.info("Received configuration data: ",data);
      $scope.data = data;
    });

    AjaxCallService.get('api/configuration_files.pl', function successCallback(data) {
      $log.info("Received configuration_files data: ", data);
      $scope.files = data;
      $scope.setServerRequestRunning(false);
    }, function errorCallback() {
      $scope.setServerRequestRunning(false);
    });

  });


