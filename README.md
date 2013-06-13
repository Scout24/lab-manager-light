More documentation, especially a description of what it does, can be found at http://code.google.com/p/lml

Please refer to the new [wiki](https://github.com/ImmobilienScout24/lab-manager-light/wiki/) and the old [wiki](http://code.google.com/p/lml/w/list) for additional documentation.

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
