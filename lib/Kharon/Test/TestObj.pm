package Kharon::Test::TestObj;

use strict;
use warnings;

sub new {
	my $self;

	$self->{num} = 1;

	bless($self);
}

sub inc {
	my ($self) = @_;

	$self->{num}++;
	undef;
}

sub query {
	my ($self) = @_;

	return $self->{num};
}

sub complicated {

	return ("foo", ["bar", "baz", {a=>'b', c=>'d', wow=>undef} ]);
}

sub uniq {
	my ($self, @args) = @_;
	my @ret;
	my %h;

	for my $i (@args) {
		if (!exists($h{$i})) {
			push(@ret, $i);
			$h{$i} = 1;
		}
	}

	return @ret;
}

sub encapsulate {
	my ($self, @args) = @_;

	map { [[[[[$_]]]]] } @args;
}

sub exception {

	die "alkjsnckjsanclkjac";
}

sub retnothing {

	return;
}

sub KHARON_IV_takes_one_hashref {
	my ($self, $cmd, @args) = @_;

	die "Too few args\n"	if @args < 1;
	die "Too many args\n"	if @args > 1;
	die "Not a hashref\n"	if ref($args[0]) ne 'HASH';

	return undef;
}

sub takes_one_hashref {
	my ($self, @args) = @_;

	die "Something went wrong #1!"	if @args != 1;
	die "Something went wrong #2!"	if ref($args[0]) ne 'HASH';

	return @args;
}

1;
