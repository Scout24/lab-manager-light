Please refer to the wiki at http://code.google.com/p/lml/w/list for documentation.

# Building

No compilation required.

1. clone this git repo
2. Run the `git2srpm` script to create a src.rpm
3. Use `rpmbuild --rebuild *.src.rpm` to create a binary package. Do this on a suitable build host that is sufficiently similar to the destination environment.

# Configuration
