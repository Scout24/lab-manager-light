window.lml = window.lml || {};


window.lml.TooltipDirective = function TooltipDirective($compile, $position, AjaxCallService) {

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
      // Show the tooltip popup element.
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

      // Register the event listeners.
      element.bind('click', function (e) {
        e.preventDefault();
        if (scope.popup.currentVM === scope.vm_name) {
          scope.popup.display = !scope.popup.display;
        } else {
          updatePosition(angular.element(e.target));
          scope.popup.currentVM = scope.vm_name;
          scope.popup.display = true;
          scope.popup.content = 'Retrieving vm data...';
          console.log('sending ajax call to vmdata.pl/' + scope.vm_uuid);
          AjaxCallService.get('vmdata.pl/' + scope.vm_uuid,
            function onSuccess(a, b, c, d) {
              scope.popup.content = angular.toJson(a,true);
            },
            function onError(a, b, c, d) {
              console.log('error received');
              scope.popup.content = 'An error occured while retrieving vm data.';
            });

        }
        scope.$apply();
      });
    }
  };
};
