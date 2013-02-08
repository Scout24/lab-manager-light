TOPLEVEL = doc src $(wildcard *.spec) LICENSE.TXT
MANIFEST = VERSION $(wildcard $(TOPLEVEL) doc/* src/* src/*/* src/*/*/* src/*/*/*/*)

GITREV := HEAD

VERSION := $(shell cat VERSION)
REVISION := "$(shell git rev-list $(GITREV) -- $(TOPLEVEL) | wc -l)$(EXTRAREV)"
PV = lab-manager-light-$(VERSION)

.PHONY: all deb rpm info debinfo rpminfo

all: deb rpm
	ls -l dist/*.deb dist/*.rpm

deb:  clean $(MANIFEST)
	echo M $(MANIFEST) V $(VERSION) R $(REVISION)
	mkdir -p dist build/deb/etc/apache2/conf.d build/deb/etc/cron.d build/deb/usr/lib build/deb/etc/lml
	touch build/deb/etc/lml/.placeholder
	sed -e 's/apache/www-data/' <src/cron/lab-manager-light >build/deb/etc/cron.d/lab-manager-light
	cp src/apache/lab-manager-light.conf build/deb/etc/apache2/conf.d/lab-manager-light.conf
	cp -r src/lml build/deb/usr/lib/
	chmod 0755 build/deb/usr/lib/lml/*.pl build/deb/usr/lib/lml/tools/*.pl
	cp -r src/DEBIAN build/deb/
	sed -i -e s/DEVELOPMENT_LML_VERSION/$(VERSION).$(REVISION)/ build/deb/usr/lib/lml/lib/LML/Common.pm
	sed -i -e s/VERSION/$(VERSION).$(REVISION)/ build/deb/DEBIAN/control
	mkdir -p build/deb/usr/share/doc/ build/usr/share/lintian/overrides
	cp -r doc build/deb/usr/share/doc/lab-manager-light
	rm -f build/deb/usr/lib/lml/LICENSE.TXT
	mv build/deb/DEBIAN/copyright build/deb/usr/share/doc/lab-manager-light/copyright
	mv build/deb/DEBIAN/overrides build/usr/share/lintian/overrides/lab-manager-light
	find build/deb -type f -name \*~ | xargs rm -vf
	fakeroot dpkg -b build/deb dist
	lintian --quiet --suppress-tags no-copyright-file,file-in-etc-not-marked-as-conffile,changelog-file-missing-in-native-package -i dist/*deb

rpm: clean $(MANIFEST)
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
	rpm -qip dist/*.rpm

debrepo: deb
	/data/mnt/is24-ubuntu-repo/putinrepo.sh dist/*.deb

rpmrepo: rpm
	repoclient uploadto "$(TARGET_REPO)" dist/*.rpm

clean:
	rm -Rf dist/*.rpm dist/*.deb build

# todo: create debian/RPM changelog automatically, e.g. with git-dch --full --id-length=10 --ignore-regex '^fixes$' -S -s 68809505c5dea13ba18a8f517e82aa4f74d79acb src doc *.spec

