/*global namespace:false*/
  window.lml = window.lml || {};

  window.lml.AjaxCallService = function AjaxCallService($http) {
  "use strict";

  function sendAjaxCall(path, userQuery, successHandler, failureHandler) {

    function failure( data, status, headers, config){
      $log.error("an error occured while sending ajax request - response status: " + status);
      if (failureHandler){
        failureHandler();
      };
    }

    return $http.post(path, JSON.stringify(userQuery))
      .success(successHandler)
      .error(failure);
  }

  return {
    sendAjaxCall: sendAjaxCall
  };
};