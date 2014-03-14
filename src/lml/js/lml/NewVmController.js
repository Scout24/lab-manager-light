  
window.lml = window.lml || {};


window.lml.NewVmController = function NewVmController($scope, $log, AjaxCallService) {

	$scope.hosts = [];
	$scope.paths = [];
	$scope.expiration = "";
	$scope.host = "auto_placement";
	$scope.globals.activeTab = 'new_vm';


	$scope.setServerRequestRunning(true);
	AjaxCallService.post('api/new_vm.pl',{}, function successCallback(data){
		$log.info("Received hosts data for create new vm: ",data);
		$scope.hosts = data.create_new_vm.hosts;
		$scope.paths = data.create_new_vm.paths;
		$scope.expiration = data.create_new_vm.expiration;
		$scope.setServerRequestRunning(false);
	}, function errorCallback(){
	   $scope.setServerRequestRunning(false);
	});


	// TODO: do this in angular style
	$("#create_vm_form").submit(function(event) {
		/* stop form from submitting normally */
		event.preventDefault();
		var formData = $("#create_vm_form").serialize();
		$.ajax({
			type: "POST",
			beforeSend: function() {
				$('#create_vm_form *').hide();
				$('#vm_create_error').hide();
				$('#new_vm_success_title').hide();
				$("#info_message").text( 'Please wait while the VM will be provisioned. This can take a while ...' );
				$('#new_vm_progress_title').show();
				$('#vm_create_info').show();
			},
			success: function(data) {
				$('#vm_create_error').hide();
				$('#new_vm_progress_title').hide();
				$('#new_vm_success_title').show();
				$("#info_message").text( 'The new VM was created with the UUID ' + data );
				$('#vm_create_info').removeClass("info");
				$('#vm_create_info').addClass("success");
				setTimeout(function(){
					$('#new_vm_screenshot').attr('src', 'vmscreenshot.pl?stream=1;uuid=' + data );
				}, 13000);
			},
			error: function(request, status, error) {
				$('#vm_create_info').hide();
				$("#error_message").text(request.responseText);
				$('#vm_create_error').show();
			},
			url: "restricted/vm-create.pl",
			data: formData
		});
  return false;
});

};


