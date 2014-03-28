  
window.lml = window.lml || {};


window.lml.ToolsController = function ToolsController($scope,AjaxCallService, $log) {

	$scope.globals.activeTab = 'tools';

  $scope.content = '';
  $scope.title = '';

  $scope.showVSphereTimeSyncCheck = function(event){
    event.preventDefault();
    $scope.title = 'vSphere Time Sync Check';
    $scope.content = '>>> request running - please wait...';
    AjaxCallService.get("hostdatetime.pl",
      function success(data){
        $log.info('received VSphereTimeSynchCheck: ', data);
        $scope.content = angular.toJson(data,true);
      },
      function error(e){
        $log.error('error while requesting VSphereTimeSynchCheck', e);
        $scope.content = '>>> an error occured (look at the browser console to see more details)';
      });
  };

  $scope.showSoftwareLicenses = function(event){
    event.preventDefault();
    $scope.title = 'Software License';
    $scope.content = '>>> request running - please wait...';
    AjaxCallService.get("LICENSE.TXT",
      function success(data){
        $log.info('received Software License: ');
        $scope.content = data;
      },
      function error(e){
        $log.error('error while requesting Software License', e);
        $scope.content = '>>> an error occured (look at the browser console to see more details)';
      });
  };

  $scope.clear = function(){
    $scope.content = '';
    $scope.title = '';
  };
};

