  
window.lml = window.lml || {};


window.lml.MainController = function MainController($scope) {
  $scope.globals = {activeTab : "vm_overview"};
  $scope.isServerRequestRunning = false;
  $scope.setServerRequestRunning = function setWaitingStatus(status){
    $scope.isServerRequestRunning = status;
  };

};

