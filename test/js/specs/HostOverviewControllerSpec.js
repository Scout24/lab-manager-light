/*global jasmine, angular, describe, beforeEach, afterEach, it, expect, spyOn, module, inject, realEstateId */
describe('HostOverviewController', function () {
  'use strict';
  var scope, AjaxCallService;

  beforeEach(module('lml-app'));
  beforeEach(module('testing-utils'));

  beforeEach(inject(function (_AjaxCallService_) {
    AjaxCallService = _AjaxCallService_;
    spyOn(AjaxCallService, 'get');
  }));

  beforeEach(inject(function (_$rootScope_) {
    scope = _$rootScope_.$new();
    scope.globals = {};
    scope.setServerRequestRunning = jasmine.createSpy('setServerRequestRunningMock');
  }));

  describe('on instanciation', function () {

    beforeEach(inject(function ($controller) {
      $controller('HostOverviewController', {
        $scope: scope
      });
    }));

    it('should call setServerRequestRunning with true, so that a spinners signals the running request to the user', function () {
      expect(scope.setServerRequestRunning).toHaveBeenCalledWith(true);
    });

    it('should request api/host_overview.pl', function () {
      expect(AjaxCallService.get).toHaveBeenCalledWith('api/host_overview.pl', jasmine.any(Function), jasmine.any(Function));
      expect(AjaxCallService.get.calls.length).toBe(1);
    });

    it('should fill scope.hosts with response data when request to api/host_overview.pl was successful', function () {
      var successHandler = AjaxCallService.get.calls[0].args[1]; // the second argument when calling the AjaxCallService is the success handler

      successHandler({host_overview_json: {hosts: ['host1', 'host2']}});

      expect(scope.hosts.length).toBe(2);
      expect(scope.hosts[0]).toBe('host1');
      expect(scope.hosts[1]).toBe('host2');
    });

    it('should call setServerRequestRunning with false, when request to api/host_overview.pl was successful, so that the spinner disapears', function () {
      var successHandler = AjaxCallService.get.calls[0].args[1]; // the second argument when calling the AjaxCallService is the success handler

      successHandler({host_overview_json: {hosts: ['host1', 'host2']}});

      expect(scope.setServerRequestRunning).toHaveBeenCalledWith(false);
    });

    it('should call setServerRequestRunning with false, when request to api/host_overview.pl failed, so that the spinner disapears', function () {
      var failureHandler = AjaxCallService.get.calls[0].args[2]; // the third argument when calling the AjaxCallService is the failure handler

      failureHandler({host_overview_json: {hosts: ['host1', 'host2']}});

      expect(scope.setServerRequestRunning).toHaveBeenCalledWith(false);
    });

  });

  describe('view', function () {
    var view_host_overview, uiHelper;

    beforeEach(inject(function ($templateCache, directiveHelperService) {
      uiHelper = directiveHelperService.init('host_overview.html', 'src/lml/html/host_overview.html');

      view_host_overview = uiHelper.compile($templateCache.get('host_overview.html'), scope);
    }));

    it('should show the mapped data', function () {
      var successHandler = AjaxCallService.get.calls[0].args[1]; // the second argument when calling the AjaxCallService is the success handler

      successHandler({host_overview_json: {hosts: [
        { id: 'host1_id',
          path: 'host1_path',
          name: 'host1_name',
          overallStatus: 'host1_overallStatus',
          active: 0,
          cpuUsage: 'host1_cpuUsage',
          memoryUsage: 'host1_memoryUsage',
          fairness: 'host1_fairness',
          network_name_type: {'host1_net1':'host1_network1', 'host1_net2':'host1_network2'},
          datastores: ["host1_datastore1","host1_datastore2"],
          hardware: 'host1_hardware1',
          product: 'host1_product'
        },
        { id: 'host2_id',
          path: 'host2_path',
          name: 'host2_name',
          overallStatus: 'host2_overallStatus',
          active: 0,
          cpuUsage: 'host2_cpuUsage',
          memoryUsage: 'host2_memoryUsage',
          fairness: 'host2_fairness',
          network_name_type: {'host2_net1':'host2_network1', 'host2_net2':'host2_network2'},
          datastores: ["host2_datastore1","host2_datastore2"],
          hardware: 'host2_hardware1',
          product: 'host2_product'
        }]}});

      scope.$apply();

      expect(uiHelper.getChildById(view_host_overview,'#host1_id').children[0].title).toEqualAfterNormalizedWhiteSpace('host1_id host1_path');

      expect(angular.element(uiHelper.getChildById(view_host_overview,'#host1_id')).text()) // just compare the text (so ordering and mapping is approved)
        .toEqualAfterNormalizedWhiteSpace('host1_name OK host1_cpuUsage host1_memoryUsage host1_fairness host1_net1 host1_net2 host1_datastore1 host1_datastore2 host1_hardware1 host1_product');

      expect(angular.element(uiHelper.getChildById(view_host_overview,'#host2_id')).text()) // just compare the text (so ordering and mapping is approved)
        .toEqualAfterNormalizedWhiteSpace('host2_name OK host2_cpuUsage host2_memoryUsage host2_fairness host2_net1 host2_net2 host2_datastore1 host2_datastore2 host2_hardware1 host2_product');
    });
  });
});