TOPLEVEL = doc src $(wildcard *.spec) LICENSE.TXT
MANIFEST = VERSION $(wildcard $(TOPLEVEL) doc/* src/* src/*/* src/*/*/* src/*/*/*/*)

GITREV := HEAD

VERSION := $(shell cat VERSION)
REVISION := "$(shell git rev-list $(GITREV) -- $(TOPLEVEL) | wc -l)$(EXTRAREV)"
PV = lab-manager-light-$(VERSION)

.PHONY: all test deb rpm info debinfo rpminfo

all: test deb rpm
	ls -l dist/*.deb dist/*.rpm

test: clean
	mkdir -p test/temp
	prove test/t
	
deb:  test clean $(MANIFEST)
	mkdir -p dist build/deb/etc/apache2/conf.d build/deb/etc/cron.d build/deb/usr/lib build/deb/etc/lml build/deb/DEBIAN
# replace RHEL-style users with Debian-style users
	install -m 0644 src/cron/lab-manager-light build/deb/etc/cron.d/lab-manager-light
	sed -e 's/apache/www-data/' -i build/deb/etc/cron.d/lab-manager-light
	install -m 0644 src/apache/lab-manager-light.conf build/deb/etc/apache2/conf.d/lab-manager-light.conf
	cp -r src/lml build/deb/usr/lib/
	install -m 0644 src/DEBIAN/* build/deb/DEBIAN
	sed -i -e s/DEVELOPMENT_LML_VERSION/$(VERSION).$(REVISION)/ build/deb/usr/lib/lml/lib/LML/Common.pm
	sed -i -e s/VERSION/$(VERSION).$(REVISION)/ build/deb/DEBIAN/control
	mkdir -p build/deb/usr/share/doc/ build/deb/usr/share/lintian/overrides
	cp -r doc build/deb/usr/share/doc/lab-manager-light
	rm -f build/deb/usr/lib/lml/LICENSE.TXT
	mv build/deb/DEBIAN/copyright build/deb/usr/share/doc/lab-manager-light/copyright
	mv build/deb/DEBIAN/overrides build/deb/usr/share/lintian/overrides/lab-manager-light
	chmod 0755 build/deb/usr/lib/lml/*.pl build/deb/usr/lib/lml/tools/*.pl build/deb/usr/share/doc/lab-manager-light/contrib/*
	chmod -R go-w build # remove group writeable in case you have it in your umask
	find build/deb -type f -name \*~ | xargs rm -vf
	fakeroot dpkg -b build/deb dist
	lintian --quiet -i dist/*deb

rpm: test clean $(MANIFEST)
	mkdir -p dist build/$(PV) build/BUILD
	cp -r $(TOPLEVEL) build/$(PV)
	mv build/$(PV)/*.spec build/
	sed -i -e s/VERSION/$(VERSION)/ -e /^Release/s/$$/.$(REVISION)/ build/*.spec
	sed -i -e s/DEVELOPMENT_LML_VERSION/$(VERSION).$(REVISION)/ build/$(PV)/src/lml/lib/LML/Common.pm
	tar -czf build/$(PV).tar.gz -C build $(PV)
	rpmbuild --define="_topdir $(CURDIR)/build" --define="_sourcedir $(CURDIR)/build" --define="_srcrpmdir $(CURDIR)/dist" --nodeps -ba build/*.spec
	mv -v build/RPMS/*/* dist/

info: rpminfo debinfo

debinfo: deb
	dpkg-deb -I dist/*.deb

rpminfo: rpm
	rpm -qip dist/*.noarch.rpm

debrepo: deb
	/data/mnt/is24-ubuntu-repo/putinrepo.sh dist/*.deb

rpmrepo: rpm
	repoclient uploadto "$(TARGET_REPO)" dist/*.rpm

clean:
	rm -Rf dist/*.rpm dist/*.deb build test/temp

# todo: create debian/RPM changelog automatically, e.g. with git-dch --full --id-length=10 --ignore-regex '^fixes$' -S -s 68809505c5dea13ba18a8f517e82aa4f74d79acb src doc *.spec

