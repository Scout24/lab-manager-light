// Karma configuration
// Generated on Fri Apr 26 2013 11:20:17 GMT+0200 (CEST)
var karmaFiles = require("./karma.files.js");
module.exports = function (config) {
  config.set({

// base path, that will be used to resolve files and exclude
    basePath: '../..',

    frameworks: ["jasmine"],

    preprocessors: {
      '**/*.html': ['html2js']
    },

    files: karmaFiles.files,
    exclude: karmaFiles.exclude,

// test results reporter to use
// possible values: 'dots', 'progress', 'junit'
    reporters: ['dots','junit'],

// cli runner port
    runnerPort: 9100,


// enable / disable colors in the output (reporters and logs)
    colors: false,

// level of logging
// possible values: LOG_DISABLE || LOG_ERROR || LOG_WARN || LOG_INFO || LOG_DEBUG
    logLevel: config.LOG_INFO,

// enable / disable watching file and executing tests whenever any file changes
    autoWatch: false,


// Start these browsers, currently available:
// - Chrome
// - ChromeCanary
// - Firefox
// - Opera
// - Safari (only Mac)
// - PhantomJS
// - IE (only Windows)
    browsers: ['PhantomJS'],


// If browser does not capture in given timeout [ms], kill it
    captureTimeout: 60000,


// Continuous Integration mode
// if true, it capture browsers, run tests and exit
    singleRun: true,

    junitReporter: {
      outputFile: 'out/target/karma/test-results.xml',
      suite: ''
    },

    plugins: [
      'karma-jasmine',
      'karma-coverage',
      'karma-junit-reporter',
      'karma-html2js-preprocessor',
      'karma-phantomjs-launcher'
    ]});
};
