
*.rpm: clean src doc *.spec
	cd dist && ../git2srpm ..
	git add -A dist
	git commit dist -m "autobuild"

info:
	rpm -qip dist/*.rpm

clean:
	rm -f dist/*.rpm
