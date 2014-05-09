/*global jasmine, angular, describe, beforeEach, afterEach, it, expect, spyOn, module, inject, runs, waits */
describe('VmOverviewController', function () {
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

    it('should show the result information "Results: x of y"', function () {
      var successHandler = AjaxCallService.get.calls[0].args[1]; // the second argument when calling the AjaxCallService is the success handler

      successHandler(window.__testdata__.vm_overview_json); // see in testdata folder
      scope.$apply();

      expect(angular.element(uiHelper.getChildById(view_host_overview,'#search_result_info')).text())
        .toEqualAfterNormalizedWhiteSpace('Results: 20 of 21');
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

    it('should show next page items with udpated result info block', function () {
      var successHandler = AjaxCallService.get.calls[0].args[1]; // the second argument when calling the AjaxCallService is the success handler

      successHandler(window.__testdata__.vm_overview_json); // see in testdata folder
      scope.$apply();

      var paginationElements = uiHelper.getChildById(view_host_overview,'#result_pagination').children[0].children;
      var nextPageElement =paginationElements[paginationElements.length-2]; // pagination elements [0]: first, [1]: previous, ... [n-2]: next, [n-1]: last
      uiHelper.simulateClickOn(nextPageElement.children[0]);

      expect(angular.element(uiHelper.getChildById(view_host_overview,'#row_0_vm21_uuid')).text()) // just compare the text (so ordering and mapping is approved)
        .toEqualAfterNormalizedWhiteSpace('vm21_full.name vm21_extra_link_text vm21_path mustermann 2014-10-24 vm21_esxHost');

      expect(angular.element(uiHelper.getChildById(view_host_overview,'#search_result_info')).text())
        .toEqualAfterNormalizedWhiteSpace('Results: 1 of 21'); // only one left on page 2
    });

    it('should filter search results and update result info and pagination element', function () {
      var successHandler = AjaxCallService.get.calls[0].args[1]; // the second argument when calling the AjaxCallService is the success handler

      successHandler(window.__testdata__.vm_overview_json); // see in testdata folder
      scope.$apply();

      runs(function () {
        var searchTermInput = uiHelper.getChildById(view_host_overview,'#search_term_input');
        uiHelper.simulateInput(searchTermInput, 'vm3_full.name');
      });

      waits(750); // we have to wait until the throttling mechanism fires the filtering

      runs(function () {
        expect(angular.element(uiHelper.getChildById(view_host_overview, '#search_result_info')).text())
          .toEqualAfterNormalizedWhiteSpace('Results: 1 of 1');

        expect(angular.element(uiHelper.getChildById(view_host_overview,'#row_0_vm3_uuid')).text()) // just compare the text (so ordering and mapping is approved)
          .toEqualAfterNormalizedWhiteSpace('vm3_full.name vm3_extra_link_text vm3_path mustermann 2014-10-24 vm3_esxHost');

        expect(angular.element(uiHelper.getChildById(view_host_overview,'#result_pagination')).text())
          .toEqualAfterNormalizedWhiteSpace('FirstPrevious1NextLast'); // only on page left
      });
    });


    it('should sort when clicking on result table header of the fullname column', function () {
      var successHandler = AjaxCallService.get.calls[0].args[1]; // the second argument when calling the AjaxCallService is the success handler

      successHandler(window.__testdata__.vm_overview_json); // see in testdata folder
      scope.$apply();

      runs(function(){
        var tab_header_fullname = uiHelper.getChildById(view_host_overview,'#tab_header_fullname');
        uiHelper.simulateClickOn(tab_header_fullname);
      });

      waits(50);

      runs(function () {
        expect(angular.element(uiHelper.getChildById(view_host_overview, '#row_0_vm10_uuid')).text()) // just compare the text (so ordering and mapping is approved)
          .toEqualAfterNormalizedWhiteSpace('vm10_full.name vm10_extra_link_text vm10_path mustermann 2014-10-24 vm10_esxHost');
        expect(angular.element(uiHelper.getChildById(view_host_overview, '#row_1_vm11_uuid')).text()) // just compare the text (so ordering and mapping is approved)
          .toEqualAfterNormalizedWhiteSpace('vm11_full.name vm11_extra_link_text vm11_path mustermann 2014-10-24 vm11_esxHost');
        expect(angular.element(uiHelper.getChildById(view_host_overview, '#row_10_vm1_uuid')).text())
          .toEqualAfterNormalizedWhiteSpace('vm1_full.name vm1_extra_link_text vm1_path mustermann 2014-10-24 vm1_esxHost');
      });

      runs(function(){
        var tab_header_fullname = uiHelper.getChildById(view_host_overview,'#tab_header_fullname');
        uiHelper.simulateClickOn(tab_header_fullname);
      });

      waits(50);

      runs(function () {
        expect(angular.element(uiHelper.getChildById(view_host_overview, '#row_0_vm9_uuid')).text()) // just compare the text (so ordering and mapping is approved)
          .toEqualAfterNormalizedWhiteSpace('vm9_full.name vm9_extra_link_text vm9_path mustermann 2014-10-24 vm9_esxHost');
        expect(angular.element(uiHelper.getChildById(view_host_overview, '#row_1_vm8_uuid')).text()) // just compare the text (so ordering and mapping is approved)
          .toEqualAfterNormalizedWhiteSpace('vm8_full.name vm8_extra_link_text vm8_path mustermann 2014-10-24 vm8_esxHost');
        expect(angular.element(uiHelper.getChildById(view_host_overview, '#row_7_vm2_uuid')).text())
          .toEqualAfterNormalizedWhiteSpace('vm2_full.name vm2_extra_link_text vm2_path mustermann 2014-10-24 vm2_esxHost');
        expect(angular.element(uiHelper.getChildById(view_host_overview, '#row_8_vm21_uuid')).text())
          .toEqualAfterNormalizedWhiteSpace('vm21_full.name vm21_extra_link_text vm21_path mustermann 2014-10-24 vm21_esxHost');
        expect(angular.element(uiHelper.getChildById(view_host_overview, '#row_10_vm1_uuid')).text())
          .toEqualAfterNormalizedWhiteSpace('vm1_full.name vm1_extra_link_text vm1_path mustermann 2014-10-24 vm1_esxHost');
      });
    });

    it('should show error msg when clicking on detonate button without selecting a vm', function () {
      var successHandler = AjaxCallService.get.calls[0].args[1]; // the second argument when calling the AjaxCallService is the success handler

      successHandler(window.__testdata__.vm_overview_json); // see in testdata folder
      scope.$apply();

      var detonateButton = uiHelper.getChildById(view_host_overview,'#detonate_button');
      uiHelper.simulateClickOn(detonateButton);


      expect(angular.element(uiHelper.getChildById(view_host_overview,'#vm_action_error')).hasClass('ng-hide')).toBeFalsy();
      expect(angular.element(uiHelper.getChildById(view_host_overview,'#vm_action_error')).text())
        .toEqualAfterNormalizedWhiteSpace('Problems while performing action The following error occured: Number of selected vms must be greater than zero.');
    });

    it('should show error msg when clicking on detonate button and have more than three vms selected', function () {
      var successHandler = AjaxCallService.get.calls[0].args[1]; // the second argument when calling the AjaxCallService is the success handler

      successHandler(window.__testdata__.vm_overview_json); // see in testdata folder
      scope.$apply();

      uiHelper.simulateClickOn(uiHelper.getChildById(view_host_overview,'#select_vm1_uuid'));
      uiHelper.simulateClickOn(uiHelper.getChildById(view_host_overview,'#select_vm3_uuid'));
      uiHelper.simulateClickOn(uiHelper.getChildById(view_host_overview,'#select_vm5_uuid'));
      uiHelper.simulateClickOn(uiHelper.getChildById(view_host_overview,'#select_vm10_uuid'));

      var detonateButton = uiHelper.getChildById(view_host_overview,'#detonate_button');
      uiHelper.simulateClickOn(detonateButton);


      expect(angular.element(uiHelper.getChildById(view_host_overview,'#vm_action_error')).hasClass('ng-hide')).toBeFalsy();
      expect(angular.element(uiHelper.getChildById(view_host_overview,'#vm_action_error')).text())
        .toEqualAfterNormalizedWhiteSpace('Problems while performing action The following error occured: Number of selected vms must be lower than four.');
    });


    it('should show error msg when clicking on delete button without selecting a vm', function () {
      var successHandler = AjaxCallService.get.calls[0].args[1]; // the second argument when calling the AjaxCallService is the success handler

      successHandler(window.__testdata__.vm_overview_json); // see in testdata folder
      scope.$apply();

      var detonateButton = uiHelper.getChildById(view_host_overview,'#destroy_button');
      uiHelper.simulateClickOn(detonateButton);


      expect(angular.element(uiHelper.getChildById(view_host_overview,'#vm_action_error')).hasClass('ng-hide')).toBeFalsy();
      expect(angular.element(uiHelper.getChildById(view_host_overview,'#vm_action_error')).text())
        .toEqualAfterNormalizedWhiteSpace('Problems while performing action The following error occured: Number of selected vms must be greater than zero.');
    });

    it('should show error msg when clicking on delete button and have more than three vms selected', function () {
      var successHandler = AjaxCallService.get.calls[0].args[1]; // the second argument when calling the AjaxCallService is the success handler

      successHandler(window.__testdata__.vm_overview_json); // see in testdata folder
      scope.$apply();

      uiHelper.simulateClickOn(uiHelper.getChildById(view_host_overview,'#select_vm1_uuid'));
      uiHelper.simulateClickOn(uiHelper.getChildById(view_host_overview,'#select_vm3_uuid'));
      uiHelper.simulateClickOn(uiHelper.getChildById(view_host_overview,'#select_vm5_uuid'));
      uiHelper.simulateClickOn(uiHelper.getChildById(view_host_overview,'#select_vm10_uuid'));

      var detonateButton = uiHelper.getChildById(view_host_overview,'#destroy_button');
      uiHelper.simulateClickOn(detonateButton);


      expect(angular.element(uiHelper.getChildById(view_host_overview,'#vm_action_error')).hasClass('ng-hide')).toBeFalsy();
      expect(angular.element(uiHelper.getChildById(view_host_overview,'#vm_action_error')).text())
        .toEqualAfterNormalizedWhiteSpace('Problems while performing action The following error occured: Number of selected vms must be lower than four.');
    });


    it('should deselect all items when filtering search results', function () {
      var successHandler = AjaxCallService.get.calls[0].args[1]; // the second argument when calling the AjaxCallService is the success handler

      successHandler(window.__testdata__.vm_overview_json); // see in testdata folder
      scope.$apply();

      // select valid number of vms
      uiHelper.simulateClickOn(uiHelper.getChildById(view_host_overview,'#select_vm1_uuid'));
      uiHelper.simulateClickOn(uiHelper.getChildById(view_host_overview,'#select_vm3_uuid'));

      runs(function () {
        var searchTermInput = uiHelper.getChildById(view_host_overview,'#search_term_input');
        uiHelper.simulateInput(searchTermInput, 'vm3_full.name');
      });

      runs(function () {
        var searchTermInput = uiHelper.getChildById(view_host_overview,'#search_term_input');
        uiHelper.simulateInput(searchTermInput, ''); // go to old result
      });

      waits(750); // we have to wait until the throttling mechanism fires the filtering

      runs(function () {
        var detonateButton = uiHelper.getChildById(view_host_overview,'#detonate_button');
        uiHelper.simulateClickOn(detonateButton);
        expect(angular.element(uiHelper.getChildById(view_host_overview,'#vm_action_error')).hasClass('ng-hide')).toBeFalsy();
        expect(angular.element(uiHelper.getChildById(view_host_overview,'#vm_action_error')).text())
          .toEqualAfterNormalizedWhiteSpace('Problems while performing action The following error occured: Number of selected vms must be greater than zero.');
      });
    });

    it('should reset all selected vms than going to next page', function () {
      var successHandler = AjaxCallService.get.calls[0].args[1]; // the second argument when calling the AjaxCallService is the success handler

      successHandler(window.__testdata__.vm_overview_json); // see in testdata folder
      scope.$apply();

      // select valid number of vms
      uiHelper.simulateClickOn(uiHelper.getChildById(view_host_overview,'#select_vm1_uuid'));
      uiHelper.simulateClickOn(uiHelper.getChildById(view_host_overview,'#select_vm3_uuid'));

      var paginationElements = uiHelper.getChildById(view_host_overview,'#result_pagination').children[0].children;
      var nextPageElement =paginationElements[paginationElements.length-2]; // pagination elements [0]: first, [1]: previous, ... [n-2]: next, [n-1]: last
      uiHelper.simulateClickOn(nextPageElement.children[0]);

      var detonateButton = uiHelper.getChildById(view_host_overview,'#detonate_button');
      uiHelper.simulateClickOn(detonateButton);
      expect(angular.element(uiHelper.getChildById(view_host_overview,'#vm_action_error')).hasClass('ng-hide')).toBeFalsy();
      expect(angular.element(uiHelper.getChildById(view_host_overview,'#vm_action_error')).text())
        .toEqualAfterNormalizedWhiteSpace('Problems while performing action The following error occured: Number of selected vms must be greater than zero.');
    });


  });


});