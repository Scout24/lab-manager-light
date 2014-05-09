/*global jasmine, angular, describe, beforeEach, afterEach, it, expect, spyOn, module, inject */
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



  describe('view', function () {
    var view_host_overview, uiHelper;

    beforeEach(inject(function ($templateCache, directiveHelperService) {
      uiHelper = directiveHelperService.init('vm_overview.html', 'src/lml/html/vm_overview.html');

      view_host_overview = uiHelper.compile($templateCache.get('vm_overview.html'), scope);
    }));

    it('should show the mapped data', function () {
      var successHandler = AjaxCallService.get.calls[0].args[1]; // the second argument when calling the AjaxCallService is the success handler

      successHandler(window.__testdata__.vm_overview_json); // see in testdata folder

      scope.$apply();

      expect(angular.element(uiHelper.getChildById(view_host_overview,'#vm1_uuid')).text()) // just compare the text (so ordering and mapping is approved)
        .toEqualAfterNormalizedWhiteSpace('vm1_full.name vm1_extra_link_text vm1_path mustermann 2014-10-24 vm1_esxHost');


    });
  });
});