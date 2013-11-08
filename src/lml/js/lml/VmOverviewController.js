  
window.lml = window.lml || {};


window.lml.VmOverviewController = function VmOverviewController($scope, $log, $location, $filter, AjaxCallService) {

  $scope.vms = [];
  $scope.globals.activeTab = 'vm_overview';
  $scope.setServerRequestRunning(true);

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

  $scope.$watch("table_filter", filterVms);

  function filterVms(query){
    $scope.filteredData = $filter("filter")($scope.vms, query);
  }


  AjaxCallService.sendAjaxCall('api/vm_overview.pl',{}, function successCallback(data){
    $log.info("Received vm overview data: ",data);
    $scope.vms = data.vm_overview;
    filterVms('');

    // INITIALIZE JQUERY DATA TABLE
/*    setTimeout(function(){
      $('#vmlist_table').dataTable({
        "bPaginate" : false,
        "bProcessing" : true,
        "sScrollY" : ($(window).height() - framework_datatables_height),
        "sDom" : 'Tlfrtip', // T places TableTools
        "oTableTools" : {
          "sSwfPath" : "swf/copy_csv_xls_pdf.swf"
        },
        "oLanguage" : {
            // without pagination only the total is interesting 
            "sInfo" : "Showing _TOTAL_ entries"
          }
        });
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
      
    },10);*/
    $scope.setServerRequestRunning(false);
  }, function errorCallback(){
    $scope.setServerRequestRunning(false);
  });


  // TODO: do this in angular style
  $("#detonate_button").on('click', function(){
    var form_data = $("#vm_action_form").serialize() + "&action=detonate";
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
        /* uncheck the checkbox of detonated machines */
        var json = $.parseJSON(data);
        $.each(json, function(index, value){
          $('#' + value + " input[type='checkbox']").attr('checked', false);
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
      url: "restricted/vm-control.pl?action=detonate",
      data: form_data
    });
  return false;
});

// TODO: do this in angular style
  $.fn.destroy = function() {
    var form_data = $("#vm_action_form").serialize() + "&action=destroy";
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
      data: form_data
    });
  return false;
};



// TODO: do this in angular style
/*$("a.confirm").click(function(link) {
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
});  */       

};


