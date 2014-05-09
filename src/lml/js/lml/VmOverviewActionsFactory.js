angular.module('lml-app')
  .service('VmOverviewActionsFactory', function VmOverviewActionsFactory($log, $location, $filter, $modal, AjaxCallService, $http) {
    'use strict';

    function closeAllPopups(scope) {
      scope.vmOverviewPopup.display = false;
      scope.vmOverviewPicturePopup.display = false;
    }

    // the controller for popups
    function modalInstanceCtrl($scope, $modalInstance, items, action) {

      $scope.items = items;
      $scope.action = action;
      $scope.ok = function () {
        $modalInstance.close();
      };

      $scope.cancel = function () {
        $modalInstance.dismiss('cancel');
      };
    }

    function getDetonateAction(scope, vms, rebuildVmModel) {

      return function detonate() {

        closeAllPopups(scope);
        var selectedVms = $filter("filter")(scope.filteredData, { selected: true }),
          uuids = selectedVms.map(function (vm) {
            return "hosts=" + vm.uuid;
          }).join("&") + "&action=detonate";


        if (selectedVms.length === 0) {
          scope.errorMsgs = "Number of selected vms must be greater than zero.";
          window.scroll(0, 0);
          return;
        }
        if (selectedVms.length > 3) {
          scope.errorMsgs = "Number of selected vms must be lower than four.";
          window.scroll(0, 0);
          return;
        }
        scope.errorMsgs = "";

        var modalInstance = $modal.open({
          templateUrl: 'modalContent.html',
          controller: modalInstanceCtrl,
          resolve: {
            items: function () {
              return selectedVms;
            },
            action: function () {
              return 'detonate';
            }
          }
        });

        scope.errorMsgs = "";

        modalInstance.result.then(function (selectedItem) {
          $log.info("detonate: " + uuids);
          scope.$apply();
          scope.setServerRequestRunning(true);
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
              scope.setServerRequestRunning(false);
            })
            .error(function (failure) {
              scope.setServerRequestRunning(false);
              scope.errorMsgs = "Unkannter Fehler";
              window.scroll(0, 0);
            });
        }, function () {
          $log.info('Detonate modal dismissed at: ' + new Date());
        });

      };
    }


// when the user clicks on the destroy button
    function getDestroyAction(scope, vms, rebuildVmModel) {
      return function destroy() {
        closeAllPopups(scope);
        var selectedVms = $filter("filter")(scope.filteredData, { selected: true }),
          uuids = selectedVms.map(function (vm) {
            return "hosts=" + vm.uuid;
          }).join("&") + "&action=destroy";

        if (selectedVms.length === 0) {
          scope.errorMsgs = "Number of selected vms must be greater than zero.";
          window.scroll(0, 0);
          return;
        }
        if (selectedVms.length > 3) {
          scope.errorMsgs = "Number of selected vms must be lower than four.";
          window.scroll(0, 0);
          return;
        }
        scope.errorMsgs = "";

        var modalInstance = $modal.open({
          templateUrl: 'modalContent.html',
          controller: modalInstanceCtrl,
          resolve: {
            items: function () {
              return selectedVms;
            },
            action: function () {
              return 'physically delete';
            }
          }
        });

        modalInstance.result.then(function (selectedItem) {
          $log.info("destroy: " + uuids);
          scope.$apply();
          scope.setServerRequestRunning(true);
          $http.post("restricted/vm-control.pl?action=destroy", uuids, {headers: {"Content-Type": "application/x-www-form-urlencoded"}})
            .success(function (detonated_uuids) {
              detonated_uuids.forEach(function (detonated_uuid) {
                selectedVms.forEach(function (selectedVM) {
                  var indexOfDeletedElement = null, i;
                  if (detonated_uuid === selectedVM.uuid) {
                    for (i = 0; i < vms.length; i++) {
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
              scope.setServerRequestRunning(false);
            })
            .error(function (failure) {
              scope.setServerRequestRunning(false);
              scope.errorMsgs = "Unkannter Fehler";
            });
        }, function () {
          $log.info('Destroy modal dismissed at: ' + new Date());
        });
      };
    }

    return {
      getDestroyAction: getDestroyAction,
      getDetonateAction: getDetonateAction
    };
  });


