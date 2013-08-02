  
window.lml = window.lml || {};


window.lml.VmOverviewController = function VmOverviewController($q, $scope, $log, AjaxCallService) {

  $scope.vms = [];


  var result_promise = AjaxCallService.sendAjaxCall('/lml/web/vm_overview.pl',{}, function successCallback(data){
    $log.info("Received vm overview data: ",data);
    $scope.vms = data.vm_overview;

    // INITIALIZE JQUERY DATA TABLE
    setTimeout(function(){
      $('#vmlist_table').dataTable({
        "bPaginate" : false,
        "bProcessing" : true,
        "sScrollY" : ($(window).height() - framework_datatables_height),
        "sDom" : 'Tlfrtip', // T places TableTools
        "oTableTools" : {
          "sSwfPath" : "lib/swf/copy_csv_xls_pdf.swf"
        },
        "oLanguage" : {
            // without pagination only the total is interesting 
            "sInfo" : "Showing _TOTAL_ entries"
          }
        });
    },10);
  });

};


