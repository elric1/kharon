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

#XXX	print STDERR "SQL: $stmt\n";

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
#XXX		print STDERR "Rollback...\n";
		$dbh->rollback();
		die $err;
	}
	return $sth;
}

sub merge_result {
	my ($lists, $ret, $key, $result) = @_;
	my $new;

	my @lists = map { defined($_->[3]) ? $_->[3] : $_->[2] } @$lists;

	$new = ${$ret}->{$key};

	for my $l (@lists) {
		$new->{$l} = [] if !exists($new->{$l});
	}

	for my $k (keys %$result) {
		if (grep { $_ eq $k } @lists) {
			if (defined($result->{$k})) {
				push(@{$new->{$k}}, $result->{$k});
			}
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
	my %fields = map { $table.'.'.$_ => 1 } @{$tabledesc->{fields}};
	my $lists = $tabledesc->{lists};

	my @join;

	for my $l (@$lists) {
		my ($ltable, $kfield, $vfield, $as) = @$l;
		push(@join, "LEFT JOIN $ltable ON " .
		    "$table.$key_field = $ltable.$kfield");

		if (defined($as)) {
			$fields{"$ltable.$vfield AS $as"} = 1;
		} else {
			$fields{"$ltable.$vfield"} = 1;
		}

		if (exists($query{$vfield})) {
			my $v = $query{$vfield};
			if (ref($v) eq 'ARRAY') {
				my @tmpwhere;

				for my $i (@$v) {
					push(@tmpwhere, "$ltable.$vfield = ?");
					push(@bindv, $i);
				}

				if (@$v) {
					push(@where, '(' .
					    join(' OR ', @tmpwhere) .
					    ')');
				}
			} else {
				push(@where, "$ltable.$vfield = ?");
				push(@bindv, $v);
			}

			delete $query{$vfield};
		}
	}

	my @errfields;
	for my $field (keys %query) {
		if (!exists($fields{$table.'.'.$field})) {
			push(@errfields, $field);
			next;
		}

		push(@where, "$table.$field = ?");
		push(@bindv, $query{$field});
	}

	if (@errfields) {
		die [500, "Fields: " . join(',', @errfields) .
		    " do not exist in $table table"];
	}

	# XXXrcd: BROKEN! BROKEN! must deal with $ltable...
	for my $field (@$qfields) {
		delete $fields{$table.'.'.$field};
	}

	my $join = join(' ', @join);

	my $where = join( ' AND ', @where );
	$where = "WHERE $where" if length($where) > 0;

	my $fields;
	if (scalar(keys %fields) > 0) {
		my %tmp_fields = %fields;

		$tmp_fields{$table.'.'.$key_field} = 1;
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
		$fields =~ s/^[^.]*\.//o;
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
