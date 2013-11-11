
window.lml = window.lml || {};


window.lml.VmOverviewController = function VmOverviewController($scope, $log, $location, $filter, AjaxCallService, $http) {
  var queuedSearch;
  $scope.searchTerm = "";
  $scope.detonateDisabled = false;
  $scope.destroyDisabled  = false;
  $scope.vms = [];
  $scope.globals.activeTab = 'vm_overview';
  $scope.setServerRequestRunning(true);
  $scope.errorMsgs;

  $scope.tableHeaders = [
    { name: "fullname",   title: "Hostname"},
    { name: "vm_path",    title: "VM Path"},
    { name: "contact_id", title: "Contact User ID"},
    { name: "expires",    title: "Expires"},
    { name: "esxhost",    title: "ESX Host"}
  ];

  $scope.sort = {
    column: '',
    descending: false
  };

  $scope.changeSorting = function(column) {

    var sort = $scope.sort;

    if (sort.column == column) {
      sort.descending = !sort.descending;
    } else {
      sort.column = column;
      sort.descending = false;
    }
  };


  var filterVms = function(query){
    $scope.vms.forEach(function(vm){ vm.selected = false; });
    $scope.filteredData = $filter("filter")($scope.vms, query);
  };

  var throttledFilterVms = function(query){
    if (queuedSearch){
      clearTimeout(queuedSearch);
      queuedSearch = null;
    }

    queuedSearch = setTimeout(function(){
      filterVms(query);
      $scope.$apply();
    }, 300);
  }

  $scope.$watch("searchTerm", throttledFilterVms);

  $scope.detonate = function(){
    var selectedVms = $filter("filter")($scope.filteredData, { selected : true }),
        uuids = selectedVms.map(function(vm){ return "hosts=" + vm.uuid }).join("&") + "&action=detonate";
    $log.info("detonate: " + uuids);

    if (selectedVms.length === 0 ){
      $scope.errorMsgs = "Anzahl VMs ist 0.";
      return;
    }
    if (selectedVms.length > 3){
      $scope.errorMsgs = "Anzahl VM > 3";
      return;
    }

    $scope.errorMsgs = "";

    $scope.$apply();
    $scope.setServerRequestRunning(true);
    $http.post("restricted/vm-control.pl?action=detonate", uuids, {headers: {"Content-Type" : "application/x-www-form-urlencoded"}})
         .success(function(detonated_uuids){
            detonated_uuids.forEach(function(detonated_uuid){
              selectedVms.forEach(function(selectedVM){
                if (detonated_uuid ===  selectedVM.uuid){
                  selectedVM.selected = false;
                  $log.info("detonation of "+ detonated_uuid +" was successful");
                }
              });
            });
            $scope.setServerRequestRunning(false);
        })
      .error(function(failure){
        $scope.setServerRequestRunning(false);
        $scope.errorMsgs = "Unkannter Fehler";
      });
  };

  AjaxCallService.sendAjaxCall('api/vm_overview.pl',{}, function successCallback(data){
    $scope.errorMsgs = "";
    $log.info("Received vm overview data: ",data);
    $scope.vms = data.vm_overview;
    filterVms('');

    // INITIALIZE JQUERY DATA TABLE
   setTimeout(function(){
      // TODO: do this in angular style
      $('a.tip').cluetip({
              attribute : 'href',
              activation : 'click',
              sticky : true,
              closePosition : 'title',
              arrows : true,
              width : 500,
              cluetipClass : 'rounded',
              ajaxCache : false,
              waitImage : true
          });

    },10);

    $scope.setServerRequestRunning(false);
  }, function errorCallback(){
    $scope.setServerRequestRunning(false);
  });

// TODO: do this in angular style
  $.fn.destroy = function() {
    var selectedVms = $filter("filter")($scope.filteredData, { selected : true }),
      uuids = selectedVms.map(function(vm){ return "hosts=" + vm.uuid }).join("&")+ "&action=detonate";
    $.ajax({
      type: "POST",
      beforeSend: function() {
        /* disable the form */
        $('#vm_action_form *').prop("disabled", "disabled");
        $('#waiting').show();
        /* deactivate previous error messages */
        $('#vm_action_error').hide();
        $('.dataTables_scrollBody').css('height',
          (myWindowHeight() - framework_datatables_height));
      },
      success: function(data) {
        /* remove the destroyed vms from our list */
        var json = $.parseJSON(data);
        $.each(json, function(index, value){
          $('#' + value).remove();
        });
        /* reactivate the form */
        $('#vm_action_form *').removeAttr("disabled");
        $('#waiting').hide();
      },
      error: function(request, status, error) {
        $('#vm_action_error').show();
        $("#vm_action_error_message").text(request.responseText);
        /* resize the result table */
        $('.dataTables_scrollBody').css('height',
          (myWindowHeight() - framework_datatables_height - $('#vm_action_error').outerHeight() - 8));
        /* reactivate the form */
        $('#vm_action_form *').removeAttr("disabled");
        $('#waiting').hide();
      },
      url: "restricted/vm-control.pl?action=destroy",
      data: uuids
    });
  return false;
};



// TODO: do this in angular style
$("a.confirm").click(function(link) {
  link.preventDefault();
  var message = $(this).attr("rel");

  $("#dialog").dialog({
    modal: true,
    bgiframe: true,
    width: 450,
    height: 215,
    autoOpen: false,
    title: 'Really delete?'
  });


  // set windows content
  $('#dialog').html('<p>' + message + '</p>');

  $("#dialog").dialog('option', 'buttons', {
    "Delete" : function() {
      $(this).dialog("close");
      $.fn.destroy();
    },
    "Cancel" : function() {
      $(this).dialog("close");
    }
  });
  $("#dialog").dialog("open");
});

};


