
*.rpm: clean src doc *.spec
	cd dist && ../git2srpm ..
	git add -A dist

info:
	rpm -qip dist/*.rpm

clean:
	rm -f dist/*.rpm
