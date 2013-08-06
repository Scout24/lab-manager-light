  
window.lml = window.lml || {};


window.lml.ConfigurationController = function ConfigurationController($scope, $log, AjaxCallService) {

  $scope.data = "";
  $scope.files = [];
  $scope.globals.activeTab = 'configuration';

  $scope.setServerRequestRunning(true);
  AjaxCallService.sendAjaxCall('/lml/api/configuration.pl',{}, function successCallback(data){
    //$log.info("Received configuration data: ",data);
    $scope.data = data;
  });

  AjaxCallService.sendAjaxCall('/lml/api/configuration_files.pl',{}, function successCallback(data){
    $log.info("Received configuration_files data: ",data);
    $scope.files = data;
   $scope.setServerRequestRunning(false); 
  }, function errorCallback(){
    $scope.setServerRequestRunning(false); 
  });

};


