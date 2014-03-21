  
window.lml = window.lml || {};


window.lml.NewVmController = function NewVmController($scope, $log, AjaxCallService) {

	$scope.hosts = [];
	$scope.paths = [];
	$scope.globals.activeTab = 'new_vm';

  $scope.vm_creation_in_progress = false;
  $scope.vm_creation_success = false;
  $scope.vm_creation_failure = false;
  $scope.vm_created_uuid = '';
  $scope.vm_creation_failure_message = '';

  $scope.vm_name = '';
	$scope.host = "auto_placement";
  $scope.user_name = '';
	$scope.expiration = '';
  $scope.path = '';


	$scope.setServerRequestRunning(true);
	AjaxCallService.get('api/new_vm.pl', function successCallback(data){
		$log.info("Received hosts data for create new vm: ",data);
		$scope.hosts = data.create_new_vm.hosts;
		$scope.paths = data.create_new_vm.paths;
		$scope.expiration = data.create_new_vm.expiration;
		$scope.setServerRequestRunning(false);
	}, function errorCallback(){
	   $scope.setServerRequestRunning(false);
	});

  $scope.createNewVm = function(event){

    var postData = 'name='+ encodeURIComponent($scope.vm_name)
      + '&esx_host=' + encodeURIComponent($scope.host)
      + '&username='+ encodeURIComponent($scope.user_name)
      + '&expiration=' + encodeURIComponent($scope.expiration)
      + '&folder=' + encodeURIComponent($scope.path);
    console.log(postData);

    $scope.vm_creation_in_progress = true;
    $scope.vm_creation_success = false;
    $scope.vm_creation_failure = false;
    $scope.vm_created_uuid = '';
    $scope.vm_creation_failure_message = '';

    AjaxCallService.post('restricted/vm-create.pl',postData, function successCallback(data){
      $log.info("Received successfully create new VM result: ",data);
      $scope.vm_creation_in_progress = false;
      $scope.vm_creation_success = true;
      $scope.vm_created_uuid = data;

    }, function errorCallback(e){
      $log.error('Received failure for create vm: ', e);
      $scope.vm_creation_in_progress = false;
      $scope.vm_creation_failure = true;
      $scope.vm_creation_failure_message = e;
    });
  };

//	// TODO: do this in angular style
//	$("#create_vm_form").submit(function(event) {
//		/* stop form from submitting normally */
//		event.preventDefault();
//		var formData = $("#create_vm_form").serialize();
//		$.ajax({
//			type: "POST",
//			beforeSend: function() {
//				$('#create_vm_form *').hide();
//				$('#vm_create_error').hide();
//				$('#new_vm_success_title').hide();
//				$("#info_message").text( 'Please wait while the VM will be provisioned. This can take a while ...' );
//				$('#new_vm_progress_title').show();
//				$('#vm_create_info').show();
//			},
//			success: function(data) {
//				$('#vm_create_error').hide();
//				$('#new_vm_progress_title').hide();
//				$('#new_vm_success_title').show();
//				$("#info_message").text( 'The new VM was created with the UUID ' + data );
//				$('#vm_create_info').removeClass("info");
//				$('#vm_create_info').addClass("success");
//				setTimeout(function(){
//					$('#new_vm_screenshot').attr('src', 'vmscreenshot.pl?stream=1;uuid=' + data );
//				}, 13000);
//			},
//			error: function(request, status, error) {
//				$('#vm_create_info').hide();
//				$("#error_message").text(request.responseText);
//				$('#vm_create_error').show();
//			},
//			url: "restricted/vm-create.pl",
//			data: formData
//		});
//  return false;
//});

};


