window.lml = window.lml || {};
window.lml.VmOverviewController = function VmOverviewController($scope, $log, $location, $filter, $modal, AjaxCallService, $http) {
  'use strict';
  var queuedSearch, // remembers the search filter timeout to throttle down the search intervall when the user enters a search string
    vms = [];

  $scope.searchTerm = ""; // search filter
  $scope.detonateDisabled = false; // flag whether the detonate button is disabled or not
  $scope.destroyDisabled = false; // flag whether the destroy button is disabled or not
  $scope.globals.activeTab = 'vm_overview'; // set the current tab so it get be marked as active when the controller is loaded via routing
  $scope.errorMsgs = ''; // current error messages which will be displayed to the user

  // pagination
  $scope.itemsPerPage = 20;
  $scope.totaItems = 0;
  $scope.currentPage = 1;
  $scope.maxSize = 5;

  $scope.setServerRequestRunning(true); // will be set to false if vms were loaded

  // popup for the vm screenshot (there is only one popup which will be repositioned with reloaded content regarding the selected vm)
  $scope.vmOverviewPicturePopup = {
    style: {
      top: '0px',
      left: '0px'
    },
    display: false,
    currentVM: null,
    close: function close() {
      $scope.vmOverviewPicturePopup.display = false;
    }
  };
  // popup for the vm info (there is only one popup which will be repositioned with reloaded content regarding the selected vm)
  $scope.vmOverviewPopup = {
    style: {
      top: '0px',
      left: '0px'
    },
    display: false,
    currentVM: null,
    content: '',
    close: function close() {
      $scope.vmOverviewPopup.display = false;
    }
  };

  // mapping from vm json data
  $scope.tableHeaders = [
    { name: "fullname", title: "Hostname"},
    { name: "vm_path", title: "VM Path"},
    { name: "contact_id", title: "Contact User ID"},
    { name: "expires", title: "Expires"},
    { name: "esxhost", title: "ESX Host"}
  ];

  // sorting options
  $scope.sort = {
    column: '',
    descending: false
  };

  // used for the export as csv
  $scope.getCsvValues = function () {
    return vms; // return not only the displayed but all vms
  };

  $scope.print = function () {
    return window.print();
  };

  // when the user clicks on a table header
  $scope.changeSorting = function (column) {
    if ($scope.sort.column === column) {
      $scope.sort.descending = !$scope.sort.descending;
    } else {
      $scope.sort.column = column;
      $scope.sort.descending = false;
    }
    $scope.currentPage = 1;
    rebuildVmModel(); // for paging we need only the first (filtered) vms
  };


  // when the user clicks on the detonate button
  $scope.detonate = function () {
    $scope.vmOverviewPopup.display = false;
    $scope.vmOverviewPicturePopup.display = false;
    var selectedVms = $filter("filter")($scope.filteredData, { selected: true }),
      uuids = selectedVms.map(function (vm) {
        return "hosts=" + vm.uuid
      }).join("&") + "&action=detonate";


    if (selectedVms.length === 0) {
      $scope.errorMsgs = "Anzahl VMs ist 0.";
      window.scroll(0, 0);
      return;
    }
    if (selectedVms.length > 3) {
      $scope.errorMsgs = "Anzahl VM > 3";
      window.scroll(0, 0);
      return;
    }

    var modalInstance = $modal.open({
      templateUrl: 'modalContent.html',
      controller: ModalInstanceCtrl,
      resolve: {
        items: function () {
          return selectedVms;
        },
        action: function () {
          return 'neu aufsetzen';
        }
      }
    });

    $scope.errorMsgs = "";

    modalInstance.result.then(function (selectedItem) {
      $log.info("detonate: " + uuids);
      $scope.$apply();
      $scope.setServerRequestRunning(true);
      $http.post("restricted/vm-control.pl?action=detonate", uuids, {headers: {"Content-Type": "application/x-www-form-urlencoded"}})
        .success(function (detonated_uuids) {
          detonated_uuids.forEach(function (detonated_uuid) {
            selectedVms.forEach(function (selectedVM) {
              if (detonated_uuid === selectedVM.uuid) {
                selectedVM.selected = false;
                $log.info("detonation of " + detonated_uuid + " was successful");
              }
            });
          });
          window.scroll(0, 0);
          $scope.setServerRequestRunning(false);
        })
        .error(function (failure) {
          $scope.setServerRequestRunning(false);
          $scope.errorMsgs = "Unkannter Fehler";
          window.scroll(0, 0);
        });
    }, function () {
      $log.info('Detonate modal dismissed at: ' + new Date());
    });

  };

  // when the user clicks on the destroy button
  $scope.destroy = function () {
    $scope.vmOverviewPopup.display = false;
    $scope.vmOverviewPicturePopup.display = false;
    var selectedVms = $filter("filter")($scope.filteredData, { selected: true }),
      uuids = selectedVms.map(function (vm) {
        return "hosts=" + vm.uuid
      }).join("&") + "&action=destroy";

    if (selectedVms.length === 0) {
      $scope.errorMsgs = "Anzahl VMs ist 0.";
      window.scroll(0, 0);
      return;
    }
    if (selectedVms.length > 3) {
      $scope.errorMsgs = "Anzahl VM > 3";
      window.scroll(0, 0);
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
        action: function () {
          return 'physikalisch l\u00F6schen';
        }
      }
    });

    modalInstance.result.then(function (selectedItem) {
      $log.info("destroy: " + uuids);
      $scope.$apply();
      $scope.setServerRequestRunning(true);
      $http.post("restricted/vm-control.pl?action=destroy", uuids, {headers: {"Content-Type": "application/x-www-form-urlencoded"}})
        .success(function (detonated_uuids) {
          detonated_uuids.forEach(function (detonated_uuid) {
            selectedVms.forEach(function (selectedVM) {
              if (detonated_uuid === selectedVM.uuid) {
                var indexOfDeletedElement = null;
                for (var i = 0; i < vms.length; i++) {
                  if (detonated_uuid === vms[i].uuid) {
                    indexOfDeletedElement = i;
                    break;
                  }
                }
                if (indexOfDeletedElement !== null) {
                  vms.splice(indexOfDeletedElement, 1);
                }

                $log.info("destroying of " + detonated_uuid + " was successful");
              }
            });
          });
          if (detonated_uuids.length > 0) {
            rebuildVmModel();
          }
          window.scroll(0, 0);
          $scope.setServerRequestRunning(false);
        })
        .error(function (failure) {
          $scope.setServerRequestRunning(false);
          $scope.errorMsgs = "Unkannter Fehler";
        });
    }, function () {
      $log.info('Destroy modal dismissed at: ' + new Date());
    });
  };

  // filter the vms regarding the current search filter
  function filterVms (query) {
    $scope.currentPage = 1;
    rebuildVmModel();
  }

  // when a user enters a search filter wait for 300 ms befor sending the next query, so fast typing do not lead to a request each letter
  function throttledFilterVms (query) {
    if (queuedSearch) {
      clearTimeout(queuedSearch);
      queuedSearch = null;
    }

    queuedSearch = setTimeout(function () {
      filterVms(query);
      $scope.$apply();
    }, 300);
  }

  // rebuild the displayed vm array according to the current page and filter and sorting criteria
  function rebuildVmModel () {
    vms.forEach(function (vm) {
      vm.selected = false;
    });
    $scope.vmOverviewPopup.display = false;
    $scope.vmOverviewPicturePopup.display = false;
    var filteredVMs = $filter("filter")(vms, $scope.searchTerm);
    var sortedVMs = $filter('orderBy')(filteredVMs, $scope.sort.column, $scope.sort.descending);
    $scope.filteredData = sortedVMs.slice($scope.itemsPerPage * ($scope.currentPage - 1), $scope.itemsPerPage * ($scope.currentPage - 1) + $scope.itemsPerPage);
    $scope.totaItems = vms.length;
  }

  // the controller for popups
  function ModalInstanceCtrl($scope, $modalInstance, items, action) {

    $scope.items = items;
    $scope.action = action;
    $scope.ok = function () {
      $modalInstance.close();
    };

    $scope.cancel = function () {
      $modalInstance.dismiss('cancel');
    };
  }


  $scope.$watch("searchTerm", throttledFilterVms);
  $scope.$watch("currentPage", rebuildVmModel);


  // initial request to load all vms
  AjaxCallService.get('api/vm_overview.pl', function successCallback(data) {
    $scope.errorMsgs = "";
    $log.info("Received vm overview data: ", data);
    vms = data.vm_overview;
    $scope.totaItems = vms.length;
    rebuildVmModel();

    $scope.setServerRequestRunning(false);
  }, function errorCallback() {
    $scope.setServerRequestRunning(false);
  });
};


