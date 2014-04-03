angular.module('lml-app')
  .directive('remoteTooltip', function TooltipDirective($compile, $position, AjaxCallService) {
    'use strict';
    return {
      restrict: "A",
      template: '<a href="javascript:" title="Details" class="vmhostname">{{vm_name}}</a>',
      replace: true,
      scope: {
        popup: '=remoteTooltipData',
        vm_name: '=vmName',
        vm_uuid: '=vmUuid'
      },
      link: function (scope, element, attr) {
        function updatePosition(element) {
          var linkElementPosition,
            popupElementPosition;

          // get current position
          linkElementPosition = $position.position(element);
          popupElementPosition = {
            top: linkElementPosition.top + 'px', // better positioning with (position.top - popup.prop('offsetHeight') * 0.4 ) + 'px',
            left: (linkElementPosition.left + linkElementPosition.width) + 'px'
          };
          scope.popup.style.left = popupElementPosition.left;
          scope.popup.style.top = popupElementPosition.top;
        }

        function loadVmData() {
          scope.popup.content = 'Retrieving vm data...';
          AjaxCallService.get('vmdata.pl/' + scope.vm_uuid,
            function onSuccess(a, b, c, d) {
              scope.popup.content = angular.toJson(a, true);
            },
            function onError() {
              console.log('error received');
              scope.popup.content = 'An error occured while retrieving vm data.';
            });
        }

        // Register the event listeners.
        element.bind('click', function (e) {
          e.preventDefault();
          if (scope.popup.currentVM === scope.vm_name) {
            scope.popup.display = !scope.popup.display;
            if (scope.popup.display) {
              loadVmData();
            }
          } else {
            updatePosition(angular.element(e.target));
            scope.popup.currentVM = scope.vm_name;
            scope.popup.display = true;
            loadVmData();
          }

          scope.$apply();
        });
      }
    };
  });
