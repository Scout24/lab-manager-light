angular.module('lml-app')
  .directive('remotePictureTooltip', function TooltipPictureDirective($compile, $position, AjaxCallService) {
    'use strict';
    return {
      restrict: "A",
      template: '<a href="javascript:" title="Screenshot" class=""><img src="images/console_icon.png"/></a>',
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

        function reloadWhilePictureIsDisplayed() {
          setTimeout(function reload() {
            if (scope.popup.currentVM === scope.vm_name && scope.popup.display) {
              scope.popup.src = 'vmscreenshot.pl?stream=0;uuid=' + scope.vm_uuid + '&counter=' + Math.random();
              reloadWhilePictureIsDisplayed();
              scope.$apply();
            }
          }, 10000);
        }

        // Register the event listeners.
        element.bind('click', function (e) {
          e.preventDefault();
          if (scope.popup.currentVM === scope.vm_name) {
            scope.popup.display = !scope.popup.display;
          } else {
            updatePosition(angular.element(e.target));
            scope.popup.currentVM = scope.vm_name;
            scope.popup.display = true;
            scope.popup.src = 'vmscreenshot.pl?stream=0;uuid=' + scope.vm_uuid + '&counter=' + Math.random();
            reloadWhilePictureIsDisplayed();
          }
          scope.$apply();
        });
      }
    };
  });
