/*global namespace:false*/
  window.lml = window.lml || {};

  window.lml.AjaxCallService = function AjaxCallService($http,$log) {
  "use strict";

  function get(path, success, error){
    return $http.get(path,{headers: {Accept: 'application/json' }})
      .success(success)
      .error(error);
  }

  function post(path, userQuery, successHandler, failureHandler) {

    function failure( data, status, headers, config){
      $log.error("an error occured while sending ajax request - response status: " + status);
      if (failureHandler){
        failureHandler();
      }
    }

    return $http.post(path, userQuery)
      .success(successHandler)
      .error(failure);
  }

  return {
    post: post,
    get: get
  };
};