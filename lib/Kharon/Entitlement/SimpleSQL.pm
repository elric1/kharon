#
# Implement a ACL file with format:
#
#	entitlement_string: <list of entitlements>
#
# Where the list of entitlements are strings that will be passed to an
# Kharon::Entitlement object's check() method.
#

package Kharon::Entitlement::SimpleSQL;
use base qw(Kharon::Entitlement);

use Kharon::dbutils qw/sql_command/;

use Data::Dumper;

use warnings;
use strict;

sub new {
	my ($proto, %args) = @_;
	my $class = ref($proto) || $proto;

	my $self = $class->SUPER::new(%args);

	$self->{dbh}   = $args{dbh};

	return $self;
}

sub set_dbh {
	my ($self, $dbh) = @_;

	$self->{dbh} = $dbh;
}

sub init_db {
	my ($self) = @_;
	my $dbh = $self->{dbh};

	$dbh->{AutoCommit} = 1;

	$dbh->do(qq{
		CREATE TABLE simple_acl (
			subject		VARCHAR,
			verb		VARCHAR,

			PRIMARY KEY (subject, verb)
		)
	});

	$dbh->{AutoCommit} = 0;
}

sub check1 {
	my ($self, $verb) = @_;
	my $dbh = $self->{dbh};

	if (@{$self->{credlist}} != 1) {
		die [502, "can't deal with multiple creds"];
	}

	my $subject = $self->{credlist}->[0];

	my $stmt = q{	SELECT COUNT(verb) FROM simple_acl
		 	WHERE subject = ? AND verb = ?  };

	my $sth = sql_command($dbh, $stmt, $subject, $verb);

	my $ret = $sth->fetch()->[0];
	return $ret ? 1 : undef;
}

1;
