angular.module('lml-app')
  .controller('HostOverviewController', function HostOverviewController($scope, $log, $filter, AjaxCallService) {
    "use strict";

    var hosts =[], queuedSearch;

    $scope.hosts = [];
    $scope.globals.activeTab = 'host_overview';
    // mapping from vm json data
    $scope.tableHeaders = [
      { name: "name", title: "Name", sortable: true},
      { name: "state_sortable", title: "State", sortable: true},
      { name: "cpuUsage", title: "CPU (GHz)", sortable: false},
      { name: "memoryUsage", title: "MEM (GB)", sortable: false},
      { name: "fairness", title: "Fairness", sortable: false},
      { name: "network_name_type", title: "Networks", sortable: false},
      { name: "datastores", title: "Datastores", sortable: true},
      { name: "hardware", title: "Hardware", sortable: true},
      { name: "product", title: "Product", sortable: true}
    ];

    // sorting options
    $scope.sort = {
      column: '',
      descending: false
    };

    $scope.searchTerm = ""; // search filter
    // pagination
    $scope.itemsPerPage = 3;
    $scope.totalItems = 0;
    $scope.currentPage = 1;
    $scope.maxSize = 5;
    $scope.filteredData = [];



    // rebuild the displayed vm array according to the current page and filter and sorting criteria
    function rebuildVmModel() {
      var filteredHosts = $filter("filter")(hosts, $scope.searchTerm);
      var sortedHosts = $filter('orderBy')(filteredHosts, $scope.sort.column, $scope.sort.descending);
      $scope.filteredData = sortedHosts.slice($scope.itemsPerPage * ($scope.currentPage - 1), $scope.itemsPerPage * ($scope.currentPage - 1) + $scope.itemsPerPage);
      $scope.totalItems = filteredHosts.length;
    }

    // filter the vms regarding the current search filter
    function filterHosts(query) {
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
        filterHosts(query);
        $scope.$apply();
      }, 300);
    }

    $scope.$watch("searchTerm", throttledFilterVms);
    $scope.$watch("currentPage", rebuildVmModel);
    $scope.$watch("itemsPerPage", rebuildVmModel);



    // when the user clicks on a table header
    $scope.changeSorting = function (column, sortable) {
      if (!sortable){
        return;
      }
      if ($scope.sort.column === column) {
        $scope.sort.descending = !$scope.sort.descending;
      } else {
        $scope.sort.column = column;
        $scope.sort.descending = false;
      }
      $scope.currentPage = 1;
      rebuildVmModel(); // for paging we need only the first (filtered) vms
    };

    $scope.setServerRequestRunning(true);

    var result_promise = AjaxCallService.get('api/host_overview.pl', function successCallback(data) {
      var i, j, hostItem, property;
      $log.info("Received hosts data for overview: ", data);

      for (i = 0; i < data.host_overview_json.hosts.length;i++){
        hostItem = data.host_overview_json.hosts[i];

        // make datastores searchable
        for (j = 0; j < hostItem.datastores.length;j++){
          hostItem['ds_' + j] = hostItem.datastores[j];
        }

        // make state searchable
        hostItem.state_sortable = hostItem.overallStatus === 'green' ? '0' : (hostItem.overallStatus === 'yellow' ? '1' : '2');

        j = 0;
        // make network names searchable
        for (property in hostItem.network_name_type) {
          if (hostItem.network_name_type.hasOwnProperty(property)) {
            hostItem['network_name_type_' + j++] = property;
          }
        }

        hosts.push(hostItem);
      }
      $scope.totalItems = hosts.length;
      rebuildVmModel();
      $scope.setServerRequestRunning(false);
    }, function errorCallback() {
      $scope.setServerRequestRunning(false);
    });

  });


