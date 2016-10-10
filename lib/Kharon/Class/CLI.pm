# Blame: "Roland C. Dowdeswell" <elric@imrryr.org>

package Kharon::Class::CLI;
use base qw(Kharon);

use Kharon::utils qw/encode_var_list/;

use JSON;
use POSIX qw/strftime/;
use Getopt::Std;		# XXXrcd: necessary?
use Term::ReadLine;		# XXXrcd: necessary?

use strict;
use warnings;

sub new {
	my ($proto, %args) = @_;
	my $class = ref($proto) || $proto;

	# XXXrcd: for now we simply bless our arguments...
	#         we are presuming that we're passing the
	#         right thing w/o verification which is
	#         suboptimal.

	$args{out} = \*STDOUT		if !exists($args{out});
	$args{err} = \*STDERR		if !exists($args{err});
	$args{appname} = "unknown"	if !exists($args{appname});
	$args{debug} = 0		if !exists($args{debug});
	$args{print_success} = 0	if !exists($args{print_success});
	$args{json} = 0			if !exists($args{json});

	return bless(\%args, $class);
}

sub set_obj {
	my ($self, $obj) = @_;

	$self->{obj} = $obj;
	return;
}

sub set_out {
	my ($self, $out) = @_;

	$self->{out} = $out;
	return;
}

sub set_err {
	my ($self, $err) = @_;

	$self->{err} = $err;
	return;
}

sub run_cmd {
	my ($self, $cmd, @args) = @_;
	my @ret;
	my $func;

	my $hcmds   = $self->KHARON_HASHIFY_COMMANDS();
	my $aliases = $self->KHARON_COMMAND_ALIASES();

	my $out		= $self->{out};
	my $obj		= $self->{obj};
	my $formats	= $self->{formats};
	my $cmds	= $self->{cmds};

	$cmd  = $aliases->{$cmd}	if  exists($aliases->{$cmd});
	$func = $cmds->{$cmd}		if  exists($cmds->{$cmd});
	$func = $obj->can($cmd)		if !defined($func);

	if (my $override = $self->can("CMD_" . $cmd)) {
		$func = $override;
		$obj  = $self;
	}

	if (!defined($func)) {
		print STDERR "Unrecognised command, $cmd\n";
		return 1;
	}
	eval {
		if (exists($hcmds->{$cmd})) {
			@args = $self->hashify_args(@{$hcmds->{$cmd}}, @args);
		}
		@ret = &$func($obj, @args);
	};

	if ($@) {
		$self->printerr($@);
		return 1;
	}

	if ($self->{json} == 1) {
		return $self->json_format($cmd, \@args, @ret);
	}

	$func = $self->can("FORMAT_" . $cmd);

	if (!defined($func)) {
		return $self->generic_format($cmd, \@args, @ret);
	}

	return &$func($self, $cmd, \@args, @ret);

	#
	# XXXrcd: this stuff is not actually run.

	if ($self->{print_success}) {
		print "Command succeeded.\n";
	}

	return 0;
}

sub run_cmdline {
	my ($self) = @_;

	my $name  = $self->{appname};
	my $debug = $self->{debug};

	my $term = Term::ReadLine->new("$name client");
	$self->set_out($term->OUT || \*STDOUT);
	$term->ornaments(0);

	while (1) {
		my $cmd = $term->readline("$name> ");
		last if !defined($cmd);

		if ($debug) {
			print STDERR "DEBUG: Doing: $cmd";
#XXXrcd			print STDERR ", via kdc \"$kdcs[0]\""
#XXXrcd			    if defined($kdcs[0]);
			print STDERR "\n";
		}

		# Eat the whitespace:
		$cmd =~ s/[ 	][ 	]*/ /og;
		$cmd =~ s/^ *//og;
		$cmd =~ s/ *$//og;

		next				if ($cmd eq '');

		my @l = split(' ', $cmd);

		if ($debug) {
			for my $i (@l) {
				print STDERR "DEBUG: parsed arg: $i\n";
			}
		}

		last				if $l[0] eq 'quit';
		last				if $l[0] eq 'exit';

		$self->run_cmd(@l);
	}

	return 0;
}

sub _parse_duration {
	my ($str) = @_;

	my @l = ($str =~ /(\d+w)?(\d+d)?(\d+h)?(\d+m)?(\d+s?)?/o);

	@l = map { $_ //= 0; $_ =~ s/[a-z]$//o; $_; } @l;

	my $ret	 = 0;
	my @units = (0, 7, 24, 60, 60);
	for my $val (@l) {
		$ret *= shift(@units);
		$ret += $val if defined($val);
	}

	return $ret;
}

sub hashify_args {
	my ($self, $start, $hmap, @input) = @_;
	my %hash;
	my @plain;
	my @end;

	if ($start > 0) {
		@plain = @input[0..$start - 1];
		@end = @input[$start..$#input];
	} else {
		@plain = ();
		@end = @input;
	}

	for my $arg (@end) {
		my ($key, $op, $val) = split(/([-+]?=)/, $arg, 3);

		if (!defined($op)) {
			$op = '=';
		}

		if (!exists($hmap->{$key})) {
			die [503, "Unrecognised key $key"];
		}

		if (ref($hmap->{$key}) ne 'ARRAY' && length($op) != 1) {
			die [503, "$op can only be used with list fields."];
		}

		if (defined($hmap->{$key}) && ref($hmap->{$key}) ne 'ARRAY' &&
		    $hmap->{$key} eq 'duration') {
			$val = _parse_duration($val);
		}

		if (ref($hmap->{$key}) eq 'ARRAY') {
			$val = [split(',', $val)]	if  defined($val);
			$val = []			if !defined($val);

			$key = "add_$key"		if $op eq '+=';
			$key = "del_$key"		if $op eq '-=';
		}

		$hash{$key} = $val;
	}

	return (@plain, %hash);
}

sub json_format {
	my ($self, $cmd, $args, @ret) = @_;
	my $out = $self->{out};

	my $json = JSON->new->allow_nonref;

	print $json->pretty->encode($ret[0]) . "\n"	if @ret == 1;
	print $json->pretty->encode(\@ret) . "\n"	if @ret >= 2;

	return 0;
}

#
# The generic format routines will attempt to do some very basic
# analysis of the data structure returned and output something more
# or less reasonable.  For anything more complex, one has to define
# one's own FORMAT_<cmd> method.

sub generic_format {
	my ($self, $cmd, $args, @ret) = @_;
	my $out = $self->{out};

	for my $r (@ret) {
		if (ref($r) eq 'HASH') {
			for my $k (sort (keys %$r)) {
				if (ref($r->{$k}) eq 'ARRAY') {
					$self->qout($k . ":", join(',',
					    sort @{$r->{$k}}));
				} else {
					$self->qout($k . ":", $r->{$k})
					    if defined($r->{$k});
				}
			}
			next;
		}
		if (ref($r) eq 'ARRAY') {
			$self->generic_format($cmd, $args, sort @$r);
			next;
		}
		if (defined($r)) {
			print $out "$r\n";
		}
	}

	return 0;
}

our $QUERY_FMT = "%- 25.25s ";
sub qout {
	my ($self, @args) = @_;

	$self->printf("$QUERY_FMT %s\n", @args);
}

sub fmtdate { strftime("%a %b %e %H:%M:%S %Z %Y", localtime($_[1])) }
sub fmtintv {
	my ($self, $in) = @_;

	return 0 if $in < 1;

	my $secs  = $in % 60;
	   $in   -= $secs;
	   $in   /= 60;
	my $mins  = $in % 60;
	   $in   -= $mins;
	   $in   /= 60;
	my $hours = $in % 24;
	   $in   -= $hours;
	   $in   /= 24;

	my @ret;
	push(@ret, "$in days")		if $in > 0;
	push(@ret, "$hours hours")	if $hours > 0;
	push(@ret, "$mins minutes")	if $hours > 0;
	push(@ret, "$secs seconds")	if $secs > 0;

	join(' ', @ret);
}

sub fmtexpi {
	my ($self, $in) = @_;

	return "NEVER"		if $in == 0;
	$in -= time();

	return "EXPIRED"	if $in < 1;
	return $self->fmtintv($in);
}

sub formaterr {
	my ($self, $err) = @_;

	if (ref($err) eq 'ARRAY') {
		return sprintf("ERROR (%d): %s\n", $err->[0], $err->[1]);
	}

	if (ref($err) eq '') {
		$err =~ s#at .* line \d+\.$##;
		return sprintf("ERROR: %s\n", $err);
	}

	if (UNIVERSAL::isa($err, 'Error')) {
		return $err->stringify();
	}

	return "ERROR: " . encode_var_list($err);
}

sub printerr {
	my ($self, @vars) = @_;
	my $err = $self->{err};

	for my $var (@vars) {
		print $err ($self->formaterr($var) . "\n");
	}
}

sub printvar {
	my ($self, $type, @vars) = @_;

	for my $var (@vars) {
		$self->print("$type: ")			if defined($type);
		$self->print(encode_var_list($var));
	}
}

sub printf {
	my ($self, @args) = @_;
	my $out = $self->{out};

	printf $out (@args);
}

sub print {
	my ($self, @args) = @_;
	my $out = $self->{out};

	print $out @args;
}

#
# provide empty methods:

sub KHARON_HASHIFY_COMMANDS { return {}; }
sub KHARON_COMMAND_ALIASES { return {}; }

1;
