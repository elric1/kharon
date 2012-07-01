#
# Misc. DB utility subroutines


package Kharon::dbutils;

use Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw{
		sql_command
		generic_query
	};

use DBI;

use warnings;
use strict;

sub sql_command {
	my ($dbh, $stmt, @values) = @_;

#XXX	print STDERR "SQL: $stmt\n"	if $self->{debug};

	my $sth;
	eval {
		$sth = $dbh->prepare($stmt);

		if (!$sth) {
			die [510, "SQL ERROR: ".$dbh->errstr.", ".$dbh->err];
		}

		$sth->execute(@values);
	};

	my $err = $@;
	if ($err) {
#XXX		print STDERR "Rollback...\n"	if $self->{debug};
		$dbh->rollback();
		die $err;
	}
	return $sth;
}

sub merge_result {
	my ($lists, $ret, $key, $result) = @_;
	my $new;

	my @lists = map { $_->[2] } @$lists;

	$new = ${$ret}->{$key};
	for my $k (keys %$result) {
		next if !defined($result->{$k});

		if (grep { $_ eq $k } @lists) {
			push(@{$new->{$k}}, $result->{$k});
			next;
		}
		$new->{$k} = $result->{$k};
	}

	$new = {} if !defined($new);

	${$ret}->{$key} = $new;
}

sub generic_query {
	my ($dbh, $schema, $table, $qfields, %query) = @_;

	#
	# XXXrcd: validation should be done.

	my @where;
	my @bindv;

	my $tabledesc = $schema->{$table};

	my $key_field = $tabledesc->{fields}->[0];
	my %fields = map { $_ => 1 } @{$tabledesc->{fields}};
	my $lists = $tabledesc->{lists};

	my $join = '';

	for my $l (@$lists) {
		my ($ltable, $kfield, $vfield) = @$l;
		$join = "LEFT JOIN $ltable ON " .
		    "$table.$key_field = $ltable.$kfield";
		$fields{"$ltable.$vfield"} = 1;
	}

	my %tmpquery = %query;
	for my $field (keys %fields) {
		next if !exists($query{$field});

		push(@where, "$field = ?");
		push(@bindv, $query{$field});
		delete $tmpquery{$field};
	}

	if (scalar(keys %tmpquery) > 0) {
		die [500, "Fields: " . join(',', keys %tmpquery) .
		    " do not exit in $table table"];
	}

	for my $field (@$qfields) {
		delete $fields{$field};
	}

	my $where = join( ' AND ', @where );
	$where = "WHERE $where" if length($where) > 0;

	my $fields;
	if (scalar(keys %fields) > 0) {
		my %tmp_fields = %fields;

		$tmp_fields{$key_field} = 1;
		$fields = join(',', keys %tmp_fields);
	} else {
		$fields = "COUNT($key_field)";
	}

	my $stmt = "SELECT $fields FROM $table $join $where";

	my $sth = sql_command($dbh, $stmt, @bindv);

	#
	# We now reformat the result to be comprised of the simplest
	# data structure we can imagine that represents the query
	# results:

	if (scalar(keys %fields) == 0) {
		return $sth->fetch()->[0];
	}

	my $results = $sth->fetchall_arrayref({});

	my $ret;
	if (scalar(keys %fields) == 1 && $tabledesc->{wontgrow}) {
		$fields = join('', keys %fields);
		for my $result (@$results) {
			push(@$ret, $result->{$fields});
		}

		return $ret;
	}

	my $is_uniq = grep {$key_field eq $_} @{$tabledesc->{uniq}};

	my $single_result = 0;
	if (scalar(keys %fields) == 2 && $tabledesc->{wontgrow}) {
		$single_result = 1;
	}

	for my $result (@$results) {
		my $key = $result->{$key_field};

		delete $result->{$key_field};

		if ($single_result) {
			my $result_key = join('', keys %$result);
			$result = $result->{$result_key};
		}

		if ($is_uniq) {
			merge_result($lists, \$ret, $key, $result);
		} else {
			push(@{$ret->{$key}}, $result);
		}
	}

	if ($is_uniq && grep {$key_field eq $_} (@$qfields)) {
		#
		# this should mean that we get only a single
		# element in our resultant hashref.

		return $ret->{$query{$key_field}};
	}

	return $ret;
}

1;
