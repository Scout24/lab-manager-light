/*global
 module,
*/
// Karma file include and exclude configuration
module.exports = {

  files: [
    // 3rd party libs
    'src/lml/js/lib/angular-1.2.16/angular.js',
    'src/lml/js/lib/angular-1.2.16/angular-sanitize.js',
    'src/lml/js/lib/angular-1.2.16/angular-route.js',
    'src/lml/js/lib/angular-1.2.16/angular-mocks.js',
    'src/lml/js/lib/ng-csv.min.js',
    'src/lml/js/lib/ui-bootstrap-tpls-0.9.0.js',

    // sources
    'src/lml/js/lml/LabManagerLight.js', // this is the module definition
    'src/lml/js/lml/**/*.js',

    // test helper
    'test/js/helper/**/*.js',

    // test data
    'test/js/testdata/**/*.js',

    // test sources
    'test/js/specs/**/*Spec.js',

    // templates
    'src/lml/html/*.html',
    'src/lml/index.html'
  ],

// list of files to exclude
  exclude: [
    "*~*",
    "**.*~",
    "**/karma.conf.ci.js",
    "**/karma.conf.dev.js",
    "**/karma.e2e.conf.js",
    "**/karma.files.js"
  ]
};