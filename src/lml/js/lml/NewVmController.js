angular.module('lml-app')
  .controller('NewVmController', function NewVmController($scope, $log, AjaxCallService) {
    "use strict";
    $scope.hosts = [];
    $scope.paths = [];
    $scope.globals.activeTab = 'new_vm';

    $scope.vm_creation_in_progress = false;
    $scope.vm_creation_success = false;
    $scope.vm_creation_failure = false;
    $scope.vm_created_uuid = '';
    $scope.vm_creation_failure_message = '';

    $scope.new_vm_name = '';
    $scope.host = "auto_placement";
    $scope.user_name = '';
    $scope.expiration = '';
    $scope.path = '';


    $scope.setServerRequestRunning(true);
    AjaxCallService.get('api/new_vm.pl', function successCallback(data) {
      $log.info("Received hosts data for create new vm: ", data);
      $scope.hosts = data.create_new_vm.hosts;
      $scope.paths = data.create_new_vm.paths;
      $scope.expiration = data.create_new_vm.expiration;
      $scope.setServerRequestRunning(false);
    }, function errorCallback() {
      $scope.setServerRequestRunning(false);
    });

    $scope.createNewVm = function (event) {

      var postData = 'name=' + encodeURIComponent($scope.new_vm_name)
        + '&esx_host=' + encodeURIComponent($scope.host)
        + '&username=' + encodeURIComponent($scope.user_name)
        + '&expiration=' + encodeURIComponent($scope.expiration)
        + '&folder=' + encodeURIComponent($scope.path);
      console.log(postData);

      $scope.vm_creation_in_progress = true;
      $scope.vm_creation_success = false;
      $scope.vm_creation_failure = false;
      $scope.vm_created_uuid = '';
      $scope.vm_creation_failure_message = '';

      AjaxCallService.post('restricted/vm-create.pl', postData, function successCallback(data) {
        $log.info("Received successfully create new VM result: ", data);
        $scope.vm_creation_in_progress = false;
        $scope.vm_creation_success = true;
        $scope.vm_created_uuid = data;

      }, function errorCallback(e) {
        $log.error('Received failure for create vm: ', e);
        $scope.vm_creation_in_progress = false;
        $scope.vm_creation_failure = true;
        $scope.vm_creation_failure_message = e;
      });
    };
  });


