window.lml = window.lml || {};


window.lml.TooltipDirective = function TooltipDirective($compile, $timeout, $position) {
  var popup = '<div data-ng-show="isOpen" class="remoteTooltip"><button data-ng-click="closePopup()">Schliessen</button>' +
      '<pre>{fooo : sdkfjk' +
      '{fooo : \n' +
      '{fooo : sdkfjk\n' +
      '{fooo : sdkfjk\n' +
      '{fooo : sdkfjk\n' +
      '{fooo : sdkfjk\n' +
      '{fooo : sdkfj   lasst}</pre>' +
      '</div>',
    isFirstTime = true
    ;

  return {
    restrict: "A",
    template: '<a href="javascript:" title="Details" class="vmhostname">{{vm_name}}</a>',
    replace: true,
    scope: {
      vm_name: '=vmName',
      openPopup: '=openPopup'
    },
    link: function (scope, element, attr) {

      console.log('initializing directive for: ', scope.openPopup);

      scope.closePopup = function closePopup(){
        scope.isOpen = false;
      };

      // Show the tooltip popup element.
      function showPopup() {
        var tooltip,
          position,
          ttPosition;

        console.log('appending tooltip to element');
        tooltip = tooltip || $compile(popup)(scope);
        // Set the initial positioning.
        tooltip.css({ top: 0, left: 0, display: 'block', position: 'absolute', border: 'solid 1px' });
        scope.isOpen = true;
        // get current position
        position = $position.position(element);
        element.after(tooltip);
        // calculate new position
        ttPosition = {
          top: (position.top - tooltip.prop('offsetHeight') * 0.2 ) + 'px',
          left: (position.left + position.width) + 'px'
        };
        // apply new position to element
        tooltip.css(ttPosition);
        console.log('tooltip show: ', scope.isOpen);
      }

      scope.$watch("openPopup", function(data){
        if (data===scope.vm_name && !scope.isOpen){
          console.log('show popup for ', data);
          showPopup();
        } else {
          scope.closePopup();
        }
      });



      // Register the event listeners.
      element.bind('click', function (e) {
        e.preventDefault();
        scope.$emit('OPEN_POPUP',scope.vm_name);
      });

    }
  };
};
