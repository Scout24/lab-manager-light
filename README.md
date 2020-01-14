# This project is DEPRECATED and not any longer supported

More documentation, especially a description of what it does, can be found at http://code.google.com/p/lml

Please refer to the new [wiki](https://github.com/ImmobilienScout24/lab-manager-light/wiki/) and the old [wiki](http://code.google.com/p/lml/w/list) for additional documentation.

See [default.conf](https://github.com/ImmobilienScout24/lab-manager-light/blob/master/src/lml/default.conf) for a full and commented list of configuration options. Override them in `/etc/lml/*.conf` files.

# Building

No compilation required.

1. clone this git repo
2. Use `make` to build RPM and DEB packages in `dist/`

# Configuration
## Preparation
To make use of Lab Manager Light one needs the following ingredients:

* One or more VMware ESX servers managed through a vCenter
* A dedicated network for Virtual Machines that will be managed by LML
* A dedicated DNS domain for this network
* A (virtual) server to host DHCP, TFTP, DNS and HTTP servers preferably on the dedicated network. Other setups are possible but beyond the scope of this guide.

## Installation
LML requires the following Packages:

* libsvn-perl
* libconfig-inifiles-perl
* vSphere SDK for Perl 

The following services need to be configured for LML to work properly:

* DHCP server
* TFTP server
* DNS server
* HTTP server
* VMware vCenter server 
