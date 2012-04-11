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

	my %h;
	for my $i (@args) {
		$h{$i} = 1;
	}

	keys %h;
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

1;
