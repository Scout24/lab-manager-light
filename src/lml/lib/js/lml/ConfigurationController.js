  
window.lml = window.lml || {};


window.lml.ConfigurationController = function ConfigurationController($q,$scope, $log, AjaxCallService) {

  $scope.data = "";
  $scope.files = [];

  AjaxCallService.sendAjaxCall('/lml/web/configuration.pl',{}, function successCallback(data){
    $log.info("Received configuration data: ",data);
    $scope.data = data;
  });

  AjaxCallService.sendAjaxCall('/lml/web/configuration_files.pl',{}, function successCallback(data){
    $log.info("Received configuration_files data: ",data);
    $scope.files = data;
  });

};


