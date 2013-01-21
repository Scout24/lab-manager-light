Name: lab-manager-light
Version: 2
Release: 1
Summary: Lab Manager Light Self-service Virtualization
Group: Applications/System
License: GPL
URL: https://github.com/ImmobilienScout24/lab-manager-light
Source0: %{name}-%{version}.tar.gz
BuildRoot:  %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
BuildArch: noarch
# RHEL6 specific so far
Requires: httpd, cronie

%description
Lab Manager Light extends existing virtualization farms like VMware vSphere
and potentially others with advanced network and system management to build
a private cloud without the complexity of running cloud solutions.

Users can provision and manage their own virtual machines, LML will:

* enforce VM name compliance with corporate standards
* set the host-name to the VM name
* assign VMs to users
* manage end-of-life dates for VMs
* integrate with corporate user accounts
* manage IP addresses through a DHCP server
* manage DNS names through a DNS server
* control PXE boot environment for automated installation of VMs
* manage host-based entries in a SVN repository for automated systems
  integration
* LML communicates with the end-user through the existing GUIs of the
  virtualization farm and the virtual machines.



%prep
%setup -q


%install
umask 0002
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/etc/lml.conf.d $RPM_BUILD_ROOT/usr/lib/lml $RPM_BUILD_ROOT/var/lib/lml $RPM_BUILD_ROOT/etc/httpd/conf.d $RPM_BUILD_ROOT/etc/cron.d
cp -r web/www/boot/lml $RPM_BUILD_ROOT/usr/lib/
find $RPM_BUILD_ROOT/usr/lib/ -type f -name \*.pl -print0 | xargs -0 chmod -v +x
cp -r web/conf.d $RPM_BUILD_ROOT/etc/httpd/
cp -r etc/cron.d $RPM_BUILD_ROOT/etc/
cp etc/lml.conf $RPM_BUILD_ROOT/etc/lml.conf.d/00_default.conf

%clean
rm -rf $RPM_BUILD_ROOT


%files
%defattr(-,root,root,-)
%doc LICENSE.TXT dhcp3
/usr/lib/lml
/etc/httpd/conf.d/*
/etc/cron.d/*
/etc/lml.conf.d
%defattr(-,apache,apache,-)
%dir /var/lib/lml