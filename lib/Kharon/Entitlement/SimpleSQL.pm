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

use Kharon::dbutils qw/sql_command generic_query/;

use Data::Dumper;

use warnings;
use strict;

sub new {
	my ($proto, %args) = @_;
	my $class = ref($proto) || $proto;

	my $self = $class->SUPER::new(%args);

	$self->{dbh}	= $args{dbh};
	$self->{table}	= $args{table};

	return $self;
}

sub set_dbh {
	my ($self, $dbh) = @_;

	$self->{dbh} = $dbh;
}

sub set_del_check {
	my ($self, $check) = @_;

	$self->{del_check} = $check;
}

sub set_verbs {
	my ($self, @verbs) = @_;

	$self->{verbs} = \@verbs;
}

sub init_db {
	my ($self, $fkeys) = @_;
	my $dbh = $self->{dbh};
	my $table = $self->{table};

	$dbh->{AutoCommit} = 1;

	my @fks;
	@fks = @$fkeys	if defined($fkeys);

	my $keys = join("\n\t\t\t", map
	    { "FOREIGN KEY ($_->[0]) REFERENCES $_->[1]($_->[2])\n" .
	      "\t\t\t\tON DELETE CASCADE" }
	    @fks);

	$dbh->do(qq{
		CREATE TABLE $table (
			subject		VARCHAR,
			verb		VARCHAR,

			PRIMARY KEY (subject, verb)
			$keys
		)
	});

	$dbh->{AutoCommit} = 0;
}

sub drop_db {
	my ($self) = @_;
	my $dbh = $self->{dbh};
	my $table = $self->{table};

	$dbh->{AutoCommit} = 1;

	$dbh->do(qq{ DROP TABLE IF EXISTS $table });

	$dbh->{AutoCommit} = 0;
}

sub check1 {
	my ($self, $verb) = @_;
	my $dbh = $self->{dbh};
	my $table = $self->{table};

	return undef if @{$self->{credlist}} == 0;

	if (@{$self->{credlist}} != 1) {
		return "can't deal with multiple creds";
	}

	die (ref($self) . " table not defined") if !defined($table);

	my $subject = $self->{credlist}->[0];

	my $stmt = qq{	SELECT COUNT(verb) FROM $table
		 	WHERE subject = ? AND verb = ?  };

	my $sth = sql_command($dbh, $stmt, $subject, $verb);

	my $ret = $sth->fetch()->[0];
	return $ret ? 1 : undef;
}

sub require_scalar {
	my ($usage, $argnum, $arg) = @_;

	die [503, "Syntax error: arg $argnum undefined\nusage: $usage"]
	    if !defined($arg);
	die [503, "Syntax error: arg $argnum not a scalar\nusage: $usage"]
	    if ref($arg) ne ''; 
}

#
# Below are the functions to muck with the entitlements.

our %table_desc = (
	pkey		=> undef,
	uniq		=> [],
	fields		=> [qw/verb subject/],
	wontgrow	=> 1,
);

sub query {
	my ($self, %query) = @_;
	my $dbh = $self->{dbh};
	my $table = $self->{table};

	return generic_query($dbh, {$table=>\%table_desc}, $table,
	    [keys %query], %query);
}

sub add {
	my ($self, $verb, $actor) = @_;
	my $dbh = $self->{dbh};
	my $table = $self->{table};
	my $verbs = $self->{verbs};

	require_scalar("<sacls>_add <verb> <actor>", 1, $verb);
	require_scalar("<sacls>_add <verb> <actor>", 2, $actor);

	if (defined($verbs) && !grep {$_ eq $verb} @$verbs) {
		die "Verb ``$verb'' not valid.";
	}

	my $stmt = "INSERT INTO $table(subject, verb) VALUES (?, ?)";

	sql_command($dbh, $stmt, $actor, $verb);

	$dbh->commit();
	return;
}

sub del {
	my ($self, $verb, $actor) = @_;
	my $dbh = $self->{dbh};
	my $table = $self->{table};
	my $del_check = $self->{del_check};

	require_scalar("<sacls>_del <verb> <actor>", 1, $verb);
	require_scalar("<sacls>_del <verb> <actor>", 2, $actor);

	my $stmt = "DELETE FROM $table WHERE subject = ? AND verb = ?";

	sql_command($dbh, $stmt, $actor, $verb);

	if (defined($del_check)) {
		my $ret;
		eval { $ret = &$del_check($verb); };

		if (!defined($ret) || $ret ne '1') {
			$dbh->rollback();
			die [503, "Cannot relinquish permissions."];
		}
	}

	$dbh->commit();
	return;
}

1;
