/*global jasmine, angular, describe, beforeEach, afterEach, it, expect, spyOn, module, inject */
describe('HostOverviewController', function () {
  'use strict';
  var scope, AjaxCallService;

  beforeEach(module('lml-app'));
  beforeEach(module('testing-utils'));

  beforeEach(inject(function (_AjaxCallService_) {
    AjaxCallService = _AjaxCallService_;
    spyOn(AjaxCallService, 'get'); // mock server response
  }));

  beforeEach(inject(function (_$rootScope_) {
    scope = _$rootScope_.$new();
    scope.globals = {};
    scope.setServerRequestRunning = jasmine.createSpy('setServerRequestRunningMock');
  }));

  describe('on instanciation', function () {

    beforeEach(inject(function ($controller) {
      $controller('VmOverviewController', {
        $scope: scope
      });
    }));

    it('should call setServerRequestRunning with true, so that a spinners signals the running request to the user', function () {
      expect(scope.setServerRequestRunning).toHaveBeenCalledWith(true);
    });

    it('should request api/vm_overview.pl', function () {
      expect(AjaxCallService.get).toHaveBeenCalledWith('api/vm_overview.pl', jasmine.any(Function), jasmine.any(Function));
      expect(AjaxCallService.get.calls.length).toBe(1);
    });

    it('should rebuild scoped vm model with response data when request to api/vm_overview.pl was successful', function () {
      var successHandler = AjaxCallService.get.calls[0].args[1]; // the second argument when calling the AjaxCallService is the success handler

      successHandler(window.__testdata__.vm_overview_json);

      expect(scope.totalItems).toBe(window.__testdata__.vm_overview_json.vm_overview.length);
    });

    it('should call setServerRequestRunning with false, when request to api/vm_overview.pl was successful, so that the spinner disapears', function () {
      var successHandler = AjaxCallService.get.calls[0].args[1]; // the second argument when calling the AjaxCallService is the success handler

      successHandler(window.__testdata__.vm_overview_json);

      expect(scope.setServerRequestRunning).toHaveBeenCalledWith(false);
    });

    it('should call setServerRequestRunning with false, when request to api/vm_overview.pl failed, so that the spinner disapears', function () {
      var failureHandler = AjaxCallService.get.calls[0].args[2]; // the third argument when calling the AjaxCallService is the failure handler

      failureHandler({});

      expect(scope.setServerRequestRunning).toHaveBeenCalledWith(false);
    });

  });

  describe('view', function () {
    var view_host_overview, uiHelper;

    beforeEach(inject(function ($templateCache, directiveHelperService) {
      uiHelper = directiveHelperService.init('vm_overview.html', 'src/lml/html/vm_overview.html');

      view_host_overview = uiHelper.compile($templateCache.get('vm_overview.html'), scope);
    }));

    it('should show the mapped data in table rows', function () {
      var successHandler = AjaxCallService.get.calls[0].args[1]; // the second argument when calling the AjaxCallService is the success handler

      successHandler(window.__testdata__.vm_overview_json); // see in testdata folder
      scope.$apply();

      expect(angular.element(uiHelper.getChildById(view_host_overview,'#row_0_vm1_uuid')).text()) // just compare the text (so ordering and mapping is approved)
        .toEqualAfterNormalizedWhiteSpace('vm1_full.name vm1_extra_link_text vm1_path mustermann 2014-10-24 vm1_esxHost');

      expect(angular.element(uiHelper.getChildById(view_host_overview,'#row_1_vm2_uuid')).text()) // just compare the text (so ordering and mapping is approved)
        .toEqualAfterNormalizedWhiteSpace('vm2_full.name vm2_extra_link_text vm2_path mustermann 2014-10-24 vm2_esxHost');

     expect(angular.element(uiHelper.getChildById(view_host_overview,'#row_19_vm20_uuid')).text()) // 20 items per page
        .toEqualAfterNormalizedWhiteSpace('vm20_full.name vm20_extra_link_text vm20_path mustermann 2014-10-24 vm20_esxHost');
    });

    it('should show the result information "Ergebnis: x von y"', function () {
      var successHandler = AjaxCallService.get.calls[0].args[1]; // the second argument when calling the AjaxCallService is the success handler

      successHandler(window.__testdata__.vm_overview_json); // see in testdata folder
      scope.$apply();

      expect(angular.element(uiHelper.getChildById(view_host_overview,'#search_result_info')).text())
        .toEqualAfterNormalizedWhiteSpace('Ergebnis: 20 von 21');
    });

    it('should show the paged result which is currently 20 items per page', function () {
      var successHandler = AjaxCallService.get.calls[0].args[1]; // the second argument when calling the AjaxCallService is the success handler

      successHandler(window.__testdata__.vm_overview_json); // see in testdata folder
      scope.$apply();

      expect(angular.element(uiHelper.getChildById(view_host_overview,'#result_pagination')).text())
        .toEqualAfterNormalizedWhiteSpace('FirstPrevious12NextLast'); // we grab only the text to be sure that there 2 pages so the pagination plugin works - we don't test the plugin itself
    });

    it('should hide errormsg box when server responds successful', function () {
      var successHandler = AjaxCallService.get.calls[0].args[1]; // the second argument when calling the AjaxCallService is the success handler

      successHandler(window.__testdata__.vm_overview_json); // see in testdata folder
      scope.$apply();

      expect(angular.element(uiHelper.getChildById(view_host_overview,'#vm_action_error')).hasClass('ng-hide')).toBeTruthy();
    });

    it('should show errormsg box when server responds with a failure', function () {
      var failureHandler = AjaxCallService.get.calls[0].args[2]; // the third argument when calling the AjaxCallService is the failure handler

      failureHandler('Some error msg');
      scope.$apply();

      expect(angular.element(uiHelper.getChildById(view_host_overview,'#vm_action_error')).hasClass('ng-hide')).toBeFalsy();
      expect(angular.element(uiHelper.getChildById(view_host_overview,'#vm_action_error')).text())
        .toEqualAfterNormalizedWhiteSpace('Problems while performing action The following error occured: Some error msg');
    });

    it('should hide popups when page loaded initially', function () {
      var successHandler = AjaxCallService.get.calls[0].args[1]; // the second argument when calling the AjaxCallService is the success handler

      successHandler(window.__testdata__.vm_overview_json); // see in testdata folder
      scope.$apply();

      expect(angular.element(uiHelper.getChildById(view_host_overview,'#vm_overview_popup')).hasClass('ng-hide')).toBeTruthy();
      expect(angular.element(uiHelper.getChildById(view_host_overview,'#vm_overviev_picture_popup')).hasClass('ng-hide')).toBeTruthy();
    });

  });
});