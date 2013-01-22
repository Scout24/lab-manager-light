Name: lab-manager-light
Version: 3
Release: 3
Summary: Lab Manager Light Self-service Virtualization
Group: Applications/System
License: GPL
URL: https://github.com/ImmobilienScout24/lab-manager-light
Source0: %{name}-%{version}.tar.gz
BuildRoot:  %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
BuildArch: noarch
# don't add our LML Perl modules and included libraries to RPM provides
Autoprov: 0
# autoreq require also all internal libraries, sadly we need to track this manually.
Autoreq: 0
# perl stuff
Requires: /usr/bin/perl
Requires: perl(CGI)
Requires: perl(Config::IniFiles)
Requires: perl(DateTime::Format::Flexible)
Requires: perl(SVN::Client)
Requires: perl(VMware::VIRuntime)

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
mkdir -p $RPM_BUILD_ROOT/etc/lml $RPM_BUILD_ROOT/usr/lib/lml $RPM_BUILD_ROOT/var/lib/lml $RPM_BUILD_ROOT/etc/httpd/conf.d $RPM_BUILD_ROOT/etc/cron.d
cp -r src/lml/* $RPM_BUILD_ROOT/usr/lib/lml/
find $RPM_BUILD_ROOT/usr/lib/ -type f -name \*.pl -print0 | xargs -0 chmod -v +x
cp src/apache/* $RPM_BUILD_ROOT/etc/httpd/conf.d/
cp src/cron/* $RPM_BUILD_ROOT/etc/cron.d/

%clean
rm -rf $RPM_BUILD_ROOT


%files
%defattr(0644,root,root,0755)
%doc LICENSE.TXT doc
/usr/lib/lml
/etc/httpd/conf.d/*
/etc/cron.d/*
/etc/lml
%defattr(-,apache,apache,-)
%dir /var/lib/lml
