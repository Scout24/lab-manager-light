/*global angular */
angular.module('lml-app')
  .controller('VmOverviewController', function VmOverviewController($scope, $log, $filter, AjaxCallService, VmOverviewActionsFactory) {
    'use strict';
    var queuedSearch, // remembers the search filter timeout to throttle down the search intervall when the user enters a search string
      vms = [];


    function closeAllPopups(){
      $scope.vmOverviewPopup.display = false;
      $scope.vmOverviewPicturePopup.display = false;
    }

    // rebuild the displayed vm array according to the current page and filter and sorting criteria
    function rebuildVmModel() {
      vms.forEach(function (vm) {
        vm.selected = false;
      });
      closeAllPopups();
      var filteredVMs = $filter("filter")(vms, $scope.searchTerm);
      var sortedVMs = $filter('orderBy')(filteredVMs, $scope.sort.column, $scope.sort.descending);
      $scope.filteredData = sortedVMs.slice($scope.itemsPerPage * ($scope.currentPage - 1), $scope.itemsPerPage * ($scope.currentPage - 1) + $scope.itemsPerPage);
      $scope.totalItems = filteredVMs.length;
    }
    // filter the vms regarding the current search filter
    function filterVms(query) {
      $scope.currentPage = 1;
      rebuildVmModel();
    }

    // when a user enters a search filter wait for 300 ms befor sending the next query, so fast typing do not lead to a request each letter
    function throttledFilterVms(query) {
      if (queuedSearch) {
        clearTimeout(queuedSearch);
        queuedSearch = null;
      }

      queuedSearch = setTimeout(function () {
        filterVms(query);
        $scope.$apply();
      }, 300);
    }



    $scope.searchTerm = ""; // search filter
    $scope.globals.activeTab = 'vm_overview'; // set the current tab so it get be marked as active when the controller is loaded via routing
    $scope.errorMsgs = ''; // current error messages which will be displayed to the user

    // pagination
    $scope.itemsPerPage = 20;
    $scope.totalItems = 0;
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

    // used for the print button
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
    $scope.detonate = VmOverviewActionsFactory.getDetonateAction($scope, vms, rebuildVmModel);

    // when the user clicks on the destroy button
    $scope.destroy = VmOverviewActionsFactory.getDestroyAction($scope, vms, rebuildVmModel);


    $scope.$watch("searchTerm", throttledFilterVms);
    $scope.$watch("currentPage", rebuildVmModel);


    // initial request to load all vms
    AjaxCallService.get('api/vm_overview.pl', function successCallback(data) {
      $scope.errorMsgs = "";
      $log.info("Received vm overview data: ", data);
      vms = data.vm_overview;
      $scope.totalItems = vms.length;
      rebuildVmModel();

      $scope.setServerRequestRunning(false);
    }, function errorCallback(data) {
      $scope.errorMsgs = data;
      $scope.setServerRequestRunning(false);
    });
  });


