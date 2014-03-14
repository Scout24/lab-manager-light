
window.lml = window.lml || {};


window.lml.VmOverviewController = function VmOverviewController($scope, $log, $location, $filter, $modal,AjaxCallService, $http) {
  'use strict';
  var queuedSearch,vms = [];
  $scope.searchTerm = "";
  $scope.detonateDisabled = false;
  $scope.destroyDisabled  = false;
  $scope.globals.activeTab = 'vm_overview';
  $scope.setServerRequestRunning(true);
  $scope.errorMsgs = '';

  // pagination
  $scope.itemsPerPage = 10;
  $scope.totaItems = 0;
  $scope.currentPage = 1;
  $scope.maxSize = 5;


  $scope.vmOverviewPicturePopup={
    style: {
      top: '0px',
      left: '0px'
    },
    display: false,
    currentVM: null,
    close: function close(){
      $scope.vmOverviewPicturePopup.display = false;
    }
  };
  $scope.vmOverviewPopup={
    style: {
      top: '0px',
      left: '0px'
    },
    display: false,
    currentVM: null,
    content: '',
    close: function close(){
      $scope.vmOverviewPopup.display = false;
    }
  };

  $scope.tableHeaders = [
    { name: "fullname",   title: "Hostname"},
    { name: "vm_path",    title: "VM Path"},
    { name: "contact_id", title: "Contact User ID"},
    { name: "expires",    title: "Expires"},
    { name: "esxhost",    title: "ESX Host"}
  ];

  $scope.sort = {
    column: '',
    descending: false
  };

  $scope.getCsvValues = function(){
    return  $scope.filteredData;
  };

  $scope.print = function(){
    return  window.print();
  };

  $scope.changeSorting = function(column) {
    $scope.vmOverviewPopup.display = false;
    $scope.vmOverviewPicturePopup.display = false;
    var sort = $scope.sort;

    if (sort.column === column) {
      sort.descending = !sort.descending;
    } else {
      sort.column = column;
      sort.descending = false;
    }
    vms.forEach(function(vm){ vm.selected = false; });
    $scope.currentPage = 1;
    rebuildVmModel();
  };


  var filterVms = function(query){
    var filteredVMs = $filter("filter")(vms, query);
    $scope.vmOverviewPopup.display = false;
    $scope.vmOverviewPicturePopup.display = false;

    filteredVMs.forEach(function(vm){ vm.selected = false; });
    $scope.filteredData = filteredVMs.slice(0, $scope.itemsPerPage ) // TODO anstelle der DOM-Manipulation besser Sichtbarkeit setzen (Performance-Issue)
    $scope.totaItems = filteredVMs.length;
    $scope.currentPage = 1;
  };

  var throttledFilterVms = function(query){
    if (queuedSearch){
      clearTimeout(queuedSearch);
      queuedSearch = null;
    }

    queuedSearch = setTimeout(function(){
      filterVms(query);
      $scope.$apply();
    }, 300);
  };

  var updatePage = function(){
    rebuildVmModel();
  };

  $scope.$watch("searchTerm", throttledFilterVms);
  $scope.$watch("currentPage", updatePage);


  var rebuildVmModel = function(){
    $scope.vmOverviewPopup.display = false;
    $scope.vmOverviewPicturePopup.display = false;
    var filteredVMs = $filter("filter")(vms, $scope.searchTerm);
    var sortedVMs = $filter('orderBy')(filteredVMs, $scope.sort.column, $scope.sort.descending);
    $scope.filteredData = sortedVMs.slice($scope.itemsPerPage * ($scope.currentPage -1), $scope.itemsPerPage * ($scope.currentPage -1)+ $scope.itemsPerPage);
    $scope.totaItems = vms.length;
  };

  var ModalInstanceCtrl = function ($scope, $modalInstance, items, action) {

    $scope.items = items;
    $scope.action = action;
    $scope.ok = function () {
      $modalInstance.close();
    };

    $scope.cancel = function () {
      $modalInstance.dismiss('cancel');
    };
  };

  $scope.detonate = function(){
    $scope.vmOverviewPopup.display = false;
    $scope.vmOverviewPicturePopup.display = false;
    var selectedVms = $filter("filter")($scope.filteredData, { selected : true }),
        uuids = selectedVms.map(function(vm){ return "hosts=" + vm.uuid }).join("&") + "&action=detonate";



    if (selectedVms.length === 0 ){
      $scope.errorMsgs = "Anzahl VMs ist 0.";
      window.scroll(0,0);
      return;
    }
    if (selectedVms.length > 3){
      $scope.errorMsgs = "Anzahl VM > 3";
      window.scroll(0,0);
      return;
    }

    var modalInstance = $modal.open({
      templateUrl: 'modalContent.html',
      controller: ModalInstanceCtrl,
      resolve: {
        items: function () {
          return selectedVms;
        },
        action: function(){
          return 'neu aufsetzen';
        }
      }
    });

    $scope.errorMsgs = "";

    modalInstance.result.then(function (selectedItem) {
     $log.info("detonate: " + uuids);
     $scope.$apply();
      $scope.setServerRequestRunning(true);
      $http.post("restricted/vm-control.pl?action=detonate", uuids, {headers: {"Content-Type" : "application/x-www-form-urlencoded"}})
        .success(function(detonated_uuids){
          detonated_uuids.forEach(function(detonated_uuid){
            selectedVms.forEach(function(selectedVM){
              if (detonated_uuid ===  selectedVM.uuid){
                selectedVM.selected = false;
                $log.info("detonation of "+ detonated_uuid +" was successful");
              }
            });
          });
          window.scroll(0,0);
          $scope.setServerRequestRunning(false);
        })
        .error(function(failure){
          $scope.setServerRequestRunning(false);
          $scope.errorMsgs = "Unkannter Fehler";
          window.scroll(0,0);
        });
    }, function () {
      $log.info('Detonate modal dismissed at: ' + new Date());
    });

  };

    $scope.destroy = function(){
      $scope.vmOverviewPopup.display = false;
      $scope.vmOverviewPicturePopup.display = false;
      var selectedVms = $filter("filter")($scope.filteredData, { selected : true }),
        uuids = selectedVms.map(function(vm){ return "hosts=" + vm.uuid }).join("&")+ "&action=destroy";

      if (selectedVms.length === 0 ){
        $scope.errorMsgs = "Anzahl VMs ist 0.";
        window.scroll(0,0);
        return;
      }
      if (selectedVms.length > 3){
        $scope.errorMsgs = "Anzahl VM > 3";
        window.scroll(0,0);
        return;
      }
      $scope.errorMsgs = "";

      var modalInstance = $modal.open({
        templateUrl: 'modalContent.html',
        controller: ModalInstanceCtrl,
        resolve: {
          items: function () {
            return selectedVms;
          },
          action: function(){
            return 'physikalisch l\u00F6schen';
          }
        }
      });

      modalInstance.result.then(function (selectedItem) {
        $log.info("destroy: " + uuids);
        $scope.$apply();
        $scope.setServerRequestRunning(true);
        $http.post("restricted/vm-control.pl?action=destroy", uuids, {headers: {"Content-Type" : "application/x-www-form-urlencoded"}})
          .success(function(detonated_uuids){
            detonated_uuids.forEach(function(detonated_uuid){
              selectedVms.forEach(function(selectedVM){
                if (detonated_uuid ===  selectedVM.uuid){
                  var indexOfDeletedElement = null;
                  for (var i = 0; i < vms.length; i++){
                    if (detonated_uuid == vms.uuid){
                      indexOfDeletedElement = i;
                      break;
                    }
                  }
                  if (indexOfDeletedElement !== null){
                    vms.splice(indexOfDeletedElement, 1);
                  }

                  $log.info("destroying of "+ detonated_uuid +" was successful");
                }
              });
            });
            if (detonated_uuids.length > 0){
              rebuildVmModel();
            }
            window.scroll(0,0);
            $scope.setServerRequestRunning(false);
          })
          .error(function(failure){
            $scope.setServerRequestRunning(false);
            $scope.errorMsgs = "Unkannter Fehler";
          });
      }, function () {
        $log.info('Destroy modal dismissed at: ' + new Date());
      });


    };

  AjaxCallService.get('api/vm_overview.pl',function successCallback(data){
    $scope.errorMsgs = "";
    $log.info("Received vm overview data: ",data);
    vms = data.vm_overview;
    $scope.totaItems = vms.length;
    rebuildVmModel();

    $scope.setServerRequestRunning(false);
  }, function errorCallback(){
    $scope.setServerRequestRunning(false);
  });
};


