describe("LML homepage", function() {
  
  var lml_url = 'http://localhost/lml';

  it("should be reachable on localhost", function() {
    browser().navigateTo(lml_url);
    expect(browser().location().url()).toBe('/vm-overview');
  });

});


