
dist/*.rpm: src doc *.spec
	rm -f dist/*.rpm
	cd dist && ../git2srpm ..
