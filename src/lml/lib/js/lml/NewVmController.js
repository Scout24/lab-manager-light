  
window.lml = window.lml || {};


window.lml.NewVmController = function NewVmController($q,$scope, $log, AjaxCallService) {

  $scope.hosts = [];
  $scope.host = "auto_placement";

  var result_promise = AjaxCallService.sendAjaxCall('/lml/web/new_vm.pl',{}, function successCallback(data){
    $log.info("Received hosts data for create new vm: ",data);
    $scope.hosts = data.create_new_vm.hosts;

   
  });

};


