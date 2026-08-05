Name:           libkharon-perl
Version:        0.8.4
Release:        1%{?dist}
Summary:        Perl Kharon support library
License:        MIT
URL:            https://github.com/elric1/kharon
Source0:        kharon-%{version}.tar.gz

BuildRequires:  gcc
BuildRequires:  make
BuildRequires:  perl
BuildRequires:  perl-ExtUtils-MakeMaker
BuildRequires:  perl-JSON
BuildRequires:  perl-devel
BuildRequires:  perl-generators

Requires:       perl-Error
Requires:       perl-JSON

%description
libkharon-perl contains the Perl Kharon modules and XS support library.

%prep
%autosetup -n kharon-%{version}
sed -i 's/Kharon::Engine::Client::Net/Kharon::Engine::Client::UNIX/' lib/Kharon/Entitlement/Client.pm

%build
perl Makefile.PL INSTALLDIRS=vendor
%make_build

%install
make install DESTDIR=%{buildroot} INSTALLDIRS=vendor
find %{buildroot} -type f \( -name .packlist -o -name perllocal.pod \) -delete
find %{buildroot} -depth -type d -empty -delete
find %{buildroot} \( -type f -o -type l \) \
    ! -path "%{buildroot}%{_mandir}/*" \
    | sed 's#^%{buildroot}##' > libkharon-perl.files

%files -f libkharon-perl.files
%license debian/copyright
%doc Changes README
%{_mandir}/man3/*

%changelog
* Wed Aug 05 2026 ChapelTech <packages@chapel.tech> - 0.8.4-1
- Add Rocky/RHEL packaging.
