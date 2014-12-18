Name: lab-manager-light
Version: VERSION
Release: 17
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
Requires: perl(File::Slurp) perl(Array::Compare)
Requires: perl(Config::IniFiles) >= 2.72
Requires: perl(DateTime::Format::Flexible) perl(DateTime)
Requires: perl(VMware::VIRuntime)
Requires: perl(JSON) perl(Clone) perl(Time::HiRes)
Requires: perl(GD) perl(GD::Barcode)
BuildRequires: perl(Test::More) perl(Test::Warn) perl(Test::Exception) perl(Test::MockModule)
BuildRequires: perl(File::Slurp) perl(Text::Diff) perl(DateTime::Format::Flexible) perl(DateTime) perl(JSON) perl(Clone)
BuildRequires: perl(CGI) perl(Config::IniFiles) perl(VMware::VIRuntime) perl(GD) perl(GD::Barcode) perl(Array::Compare)
BuildRequires: zbar perl(Time::HiRes)

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
* LML communicates with the end-user through the existing GUIs of the
  virtualization farm and the virtual machines.
* LML has a simple GUI for VM/Host overview and new VM creation.
* LML can automatically place a VM on a suitable host.

%check
make test

%prep
%setup -q

%install
umask 0002
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/etc/lml $RPM_BUILD_ROOT/usr/lib/lml $RPM_BUILD_ROOT/var/lib/lml $RPM_BUILD_ROOT/etc/httpd/conf.d $RPM_BUILD_ROOT/etc/cron.d $RPM_BUILD_ROOT/usr/share/lab-manager-light/schema
cp -r src/lml/* $RPM_BUILD_ROOT/usr/lib/lml/
find $RPM_BUILD_ROOT/usr/lib/ -type f -name \*.pl -print0 | xargs -0 chmod -c +x
cp src/apache/* $RPM_BUILD_ROOT/etc/httpd/conf.d/
cp src/schema/* $RPM_BUILD_ROOT/usr/share/lab-manager-light/schema/
cp src/cron/* $RPM_BUILD_ROOT/etc/cron.d/
chmod -R g-w $RPM_BUILD_ROOT

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
%doc LICENSE.TXT doc
/usr/lib/lml
/etc/httpd/conf.d/*
/etc/cron.d/*
/etc/lml
/usr/share/lab-manager-light/schema/*
%defattr(-,apache,apache,-)
%dir /var/lib/lml

%post
# restart httpd if it was running because we added/changed configuration
if service httpd status ; then
    service httpd restart
fi
