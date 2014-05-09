/*global angular, IS24, inject */
(function initOfferOverviewModule() {
  'use strict';
  angular
    .module('testing-utils', [])

    .value('version', 0.1)
    .factory('directiveHelperService', ['$rootScope','$templateCache', function ($rootScope, $templateCache) {


      function compileAndDigest(snippet, scope) {
        var compiledDirective = null;
        inject(function ($compile, $rootScope) {

            var elm = angular.element(snippet);
            compiledDirective = $compile(elm)(scope);
            $rootScope.$digest();
          }
        );
        return compiledDirective;
      }
      
      function getElementBySelector(element, selector) {
        return element[0].querySelectorAll(selector)[0];
      }

      function getAllElementsBySelector(element, selector) {
        return element[0].querySelectorAll(selector);
      }

      function simulateClick(el) {
        var evt;
        if (document.createEvent) {
          evt = document.createEvent("MouseEvents");
          evt.initMouseEvent("click", true, true, window, 0, 0, 0, 0, 0, false, false, false, false, 0, null);
        }
        if (evt) {
          el.dispatchEvent(evt);

        } else if (el.click) {
          el.click();
        }
      }

      function simulateInput(el, input) {
        var evt;
        angular.element(el).val(input);

        if (document.createEvent) {
          evt = document.createEvent('Event');
          evt.initEvent('input', true, false);
        }
        if (evt) {
          el.dispatchEvent(evt);
        }
      }

      function initializeTemplate(templateName, templateLocation) {

        if (templateName) {
          $templateCache.put(templateName, window.__html__[ templateLocation]);
        }

        return {
          simulateInput: simulateInput,
          simulateClickOn: simulateClick,
          compile: compileAndDigest,
          getChildById: getElementBySelector,
          getAll: getAllElementsBySelector
        };
      }

      return {
        init: initializeTemplate
      };

    }]);
}());
