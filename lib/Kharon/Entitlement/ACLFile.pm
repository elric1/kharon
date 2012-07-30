#
# Implement a ACL file with format:
#
#	entitlement_string: <list of entitlements>
#
# Where the list of entitlements are strings that will be passed to an
# Kharon::Entitlement object's check() method.
#

package Kharon::Entitlement::ACLFile;
use base qw(Kharon::Entitlement);

use Kharon::utils;

use IO::File;

use warnings;
use strict;

sub new {
	my ($proto, %args) = @_;
	my $class = ref($proto) || $proto;

	my $self = $class->SUPER::new(%args);

	$self->{aclfile}   = $args{filename};
	$self->{subobject} = $args{subobject};

	bless($self, $class);
	return $self;
}

sub get_acl_file_entry {
	my ($self, $ent) = @_;
	my @ret;

	my $fh = IO::File->new($self->{aclfile}, "r");

	if (!defined($fh)) {
		Kharon::utils::logger "Failed to open ACL file ".
		    "$self->{aclfile}: $!";

		return ();
	}

	while (<$fh>) {
		s/\s*$//o;
		s/^\s*//o;

		next if /^#/ || /^$/;

		my ($fent, $groups) = split(/: */, $_, 2);

		push(@ret, split(/, */, $groups)) if $fent eq $ent;
	}

	return @ret;
}

sub set_subobject {
	my ($self, $subobject) = @_;

	$self->{subobject} = $subobject;
	$self->{subobject}->set_creds(@{$self->{credlist}});
}

sub set_creds {
	my ($self, @creds) = @_;
	my $subobject = $self->{subobject};

	$subobject->set_creds(@creds);
	return $self->SUPER::set_creds(@creds);
}

sub check1 {
	my ($self, $ent) = @_;
	my $subobject = $self->{subobject};
	my @groups;

	# We may be checking multiple entitlements in a single call.
	# We "or" together the result of these checks -- thus, the first
	# success is a total success.

	# Retrieve the list of groups for the specified entitlement
	@groups = $self->get_acl_file_entry($ent);

	# If there are no groups, no one has access.
	# This includes the case where the entitlement doesn't exist
	# in the file at all.
	if (!@groups) {
		return undef;
	}

	# Check to see if the wildcard special group "ALL" is one of
	# the groups.
	if (grep($_ eq "ALL", @groups)) {
		return 1;
	}

	# Otherwise, we see if our subobject considers it a match.

	if ($subobject->check(@groups)) {
		return 1;
	}

	# None of our creds matched any of the entitlements
	return undef;
}

1;
