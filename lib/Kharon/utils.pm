#
# Misc. utility subroutines


package Kharon::utils;

use Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw{
	getclasshash
	getclassvar
	get_next_word
	get_next_var
	encode_var
	encode_var_list
	encode_word
	mk_methods
	mk_scalar_methods
	mk_array_methods
	tokenise};

use IO::Handle;
use Sys::Syslog;

use warnings;
use strict;

#
# First we define a set of simple functions to build the methods that
# client objects require.  This function takes an object and a list of
# methods and returns a string which must be eval'ed in the client object.
# It's a little ``unusual'' but it works relatively well...

sub mk_methods { mk_array_methods(@_); }

sub generate_function {
	my ($parent, $method, $cmd_call) = @_;
	my $ret = '';

	if (defined($parent)) {
		$ret .= "if (ref($parent"."->can('$method')) ne 'CODE') {\n";
		$ret .= "	print STDERR '$method is not a method of";
		$ret .= 	    " $parent in Kharon::utils\n';\n";
		$ret .= "	exit 1;\n";
		$ret .= "}\n\n";
	}

	$ret .= "sub $method {\n";
	$ret .= '	my ($self, @args) = @_;' . "\n\n";

	$ret .= "$cmd_call\n";
	$ret .= "}\n\n";
}

sub mk_array_methods {
	my ($parent, @methods) = @_;
	my $ret = '';

	for my $method (@methods) {
		$ret .= generate_function($parent, $method,
		    '	$self->{pec}->CommandExc("' . $method .
			    '", @args);');
	}

	$ret;
}

sub mk_scalar_methods {
	my ($parent, @methods) = @_;
	my $ret = '';
	my $err = "Function defined as scalar returned a list";

	for my $method (@methods) {
		$ret .= generate_function($parent, $method,
		    '	my @ret = $self->{pec}->CommandExc("' . $method .
			    '", @args);' . "\n" .
		    '	if (scalar(@ret) > 1) {' . "\n" .
		    "		throw Kharon::PermanentError('$err', 500);\n" .
		    "	}\n" .
		    "	return		if !defined(wantarray());\n" .
		    '	return ()	if @ret == 0 && wantarray();' . "\n" .
		    '	return undef	if @ret == 0;' . "\n" .
		    '	return $ret[0];');
	}

	$ret;
}

sub getclassvar {
	my ($obj, $var) = @_;
	my @ret;

	my $class = ref($obj);

	#
	# Find the array variable in $obj's class or one of its superclasses:

	no strict "refs";
	for my $c ($class, @{"$class\::ISA"}) {
		next if !exists(${"$c\::"}{$var});

		@ret = @{"$c\::$var"};
		last;
	}
	use strict "refs";

	return @ret;
}

sub getclasshash {
	my ($obj, $var) = @_;
	my %ret;

	my $class = ref($obj);

	#
	# Find the array variable in $obj's class or one of its superclasses:

	no strict "refs";
	for my $c ($class, @{"$class\::ISA"}) {
		next if !exists(${"$c\::"}{$var});

		%ret = %{"$c\::$var"};
		last;
	}
	use strict "refs";

	return %ret;
}

#
# The map hash is a surjection from the tokens returned by the lexer
# onto the possible characters.  We map special tokens back to their
# original characters as well as each character onto itself.
#
# We define the special characters first, they have length greater than
# one.  We use this to generate a reverse map revmap which we can use
# to turn characters into tokens.  This allows the lexer to be a little
# shorter and more extensible...

our %token_map = (
	SP		=> ' ',
	COMMA		=> ',',
	BANG		=> '!',
	AND		=> '&',
	EQUALS		=> '=',
	LEFTBRACKET	=> '[',
	RIGHTBRACKET	=> ']',
	LEFTBRACE	=> '{',
	RIGHTBRACE	=> '}',
	CRLF		=> "\r\n",
	EMPTY		=> '\z',
	EMPTYLIST	=> '\l',
);
our %map = %token_map;

our %revmap = map { $map{$_} => $_ } (keys %map);
delete $revmap{EMPTY};
delete $revmap{EMPTYLIST};
our $revmapre = "[" . join('', map { if ($_ eq ']') { "\]" } else { $_; } } (keys %revmap)) . "]";

for my $i (0..255)		{ $map{chr($i)} = chr($i); }
for my $i (0..255)		{ $map{"\\" . sprintf("%02x", $i)} = chr($i); }
for my $i ("\\", keys %revmap)	{ $map{"\\" . $i} = $i; }

# XXXrcd: should we rewrite ecode_word into encode_scalar($_[0], '[ ]')?

# Kharon encode supplied string
sub encode_word {
	my $str = shift;

	# We escape space and backslash simply.
	$str =~ s/([\\ ])/\\$1/g;

	# The rest of the control characters we expand into hex:
	$str =~ s/([^[:print:]]|\r|\n)/sprintf('\%02x', ord($1))/ge;
	return $str;
}

# Kharon encode supplied scalar...
sub encode_scalar {
	my ($str, $ctx) = @_;

	if (defined($ctx)) {
		$str =~ s/($ctx|[\\])/\\$1/g;
	} else {
		$str =~ s/([\\])/\\$1/g;
	}

### XXXrcd: don't use [:print:]: locale issues...?  <sigh>
	# The rest of the control characters we expand into hex:
	$str =~ s/([^[:print:]]|\r|\n)/sprintf('\%02x', ord($1))/ge;
	return $str;
}

sub encode_var {
	my ($var, $ctx, $ctx2) = @_;

	return $map{BANG}		if !defined($var);
	return encode_hash($var)	if ref($var) eq 'HASH';
	return encode_array($var)	if ref($var) eq 'ARRAY';
#	return '&' . "$var"		if ref($var) eq 'CODE';
#	return '&' . "$var"		if UNIVERSAL::isa($var, 'UNIVERSAL');

	return '\z' if $var eq '' && defined($ctx2) && $ctx2 eq 'OUTER';

	if (defined($ctx)) {
		$ctx .= '|';
	} else {
		$ctx = '';
	}
	encode_scalar($var, $ctx . '^[&!{\[]');
}

sub encode_array {
	my ($ar) = @_;

	return '\l' if @$ar == 0;

	$map{LEFTBRACKET} .
	    join($map{COMMA}, map { encode_var($_, '[\],]') } @$ar) .
	    $map{RIGHTBRACKET};
}

sub encode_hash {
	my ($hr) = @_;
	my @tmp;

	for my $i (keys %$hr) {
		push(@tmp, encode_scalar($i, '[,}=]') . $map{EQUALS} .
		    encode_var($hr->{$i}, '[,}]'));
	}
	$map{LEFTBRACE} . join($map{COMMA}, @tmp) . $map{RIGHTBRACE};
}

# Kharon encode the supplied list as a complete protocol line
sub encode_var_list {
	join(" ", map { encode_var($_, '[ ]') } @_).chr(13).chr(10);
}

# XXXrcd: is emit still necessary??

# emit an Kharon message, <SP>-separating and encoding list elements
# terminating with a <CRLF>
sub emit {
	my $fh = shift;

	print $fh encode_list(@_);
	$fh->flush();
}

# Args:
#	string
#
# Retrieve next lexical element from supplied string, returning the
# lexical element identifier for the next lexical element.
#
# Returns (lexical_element, remainder_of_string)
#	where lexical_element is one of:
#	undef		- no further elements available
#	"BAD"		- malformed input
#	"SP"		- a hard space
#	"COMMA"		- a hard comma
#	"EQUALS"	- a hard equals
#	"CRLF"		- line terminator
#	etc...
#	single character- the character itself
#
# Removes the characters which compose the lexical element from the front of
# the supplied string.
sub get_next_lex {
	my ($strings) = @_;
	my $str = shift(@$strings);
	my $water = 4;

	# Empty?
	return (undef, []) if !defined($str);

	while (length($str) < $water && scalar(@$strings)) {
		$water = 64;
		$str .= shift(@$strings);
	}

	return (undef, []) if $str eq '';

	# For speed, first we short-circuit the processing for common chars:
	if ($str =~ m,^([-a-zA-Z0-9|_+/@.]).,o) {
		unshift(@$strings, substr($str, 1));
		return ($1, $strings);
	}

	my $c1 = substr($str, 0, 1);
	my $c2;

	# Escaped character?
	if ($str =~ s#^\\([lz!&\\ ,=\[{}\]]|[0-9A-Fa-f][0-9A-Fa-f])##o) {
		unshift(@$strings, $str);
		return ("EMPTY", $strings) if $1 eq 'z';
		return ("EMPTYLIST", $strings) if $1 eq 'l';
		return ("\\$1", $strings);
	}

	if ($c1 eq "\\") {
		die "Lexer: bad quoting, len(\$str)=".length($str).
		    ", \$str=$str";
	}

	#
	# Next we check our special character map:

	if (defined($revmap{$c1})) {
#	if ($c1 =~ m/$revmapre/o) {
		unshift(@$strings, substr($str, 1));
		return (($revmap{$c1}, $strings));
	}

	# Bare line feeds count as CRLFs.
	# To send encoded linefeeds, be sure to escape them as \0a
	if ($c1 eq chr(10)) {
		unshift(@$strings, substr($str, 1));
		return ("CRLF", $strings);
	}

	# CRLF?
	if ($c1 eq chr(13)) {
		if ((length($str) == 1) || (substr($str, 1, 1) ne chr(10))) {
			die "CR not followed by LF"; # XXXrcd: lame exception.
		} else {
			unshift(@$strings, substr($str, 2));
			return ("CRLF", $strings);
		}
	}

	if (ord($c1) < 32) {
		die "Lexer error";	# XXXrcd: lame exception...
	}

	# If we get here, it must represent itself.
	unshift(@$strings, substr($str, 1));
	return ($c1, $strings);
}

# Args:
#	string
#
# Retrieve the next word from the supplied string.
#
# Returns:
#
#	(word, remainder_of_string)
#
sub get_next_word {
	my ($str) = @_;
	my $string = [$str];

	(my $word, $string) = get_next_scalar($string, 'SP|CRLF');
	$str = join('', @$string);
	$str =~ s/^( |\r\n|\n)*// if defined($str);

	($word, $str);
}

sub get_next_scalar {
	my ($str, $delim) = @_;
	my $word = "";

	return (undef, ['']) if !defined($str) || scalar(@$str) == 0;
	return (undef, ['']) if !defined($str->[0]) || length($str->[0]) < 1;

	$delim = 'SP|CRLF' if !defined($delim);

	while (1) {
		# For speed we have this little hack...
		if ($str->[0] =~ s,^([-a-zA-Z0-9./@|_+]+),,o) {
			$word .= $1;
		}

		my ($char, $tmp) = get_next_lex($str);

		last if !defined($char);
		if ($char =~ m/$delim/) {
			unshift(@$str, $map{$char});
			last;
		}
		$word .= $map{$char};
		$str = $tmp;
	}

	($word, $str);
}

sub get_next_var {
	my ($str, $delim) = @_;

	# Another ugly performance hack...
	if (defined($str->[0]) && $str->[0] =~ m,^([-a-zA-Z0-9./@|_+]),o) {
		return get_next_scalar($str, $delim);
	}
	(my $char, $str) = get_next_lex($str);

	return (undef, undef)			if !defined($char);
	return (undef, $str)			if $char eq 'BANG';
	return ('', $str)			if $char eq 'EMPTY';
	return ([], $str)			if $char eq 'EMPTYLIST';
	return get_next_array($str)		if $char eq 'LEFTBRACKET';
	return get_next_hash($str)		if $char eq 'LEFTBRACE';
#	return get_next_func($str, $delim)	if $char eq 'AND';

	$char = $token_map{$char} if exists($token_map{$char});
	unshift(@$str, $char);
	get_next_scalar($str, $delim);
}

sub get_next_func {
	my ($str, $delim) = @_;
	my $f;

	(my $var, $str) = get_next_scalar($str, $delim);

	if ($var !~ /^CODE/) {
		$f = sub {
			my ($pec) = @_;
			return Kharon::StdClient->new(REF=>$var, pec=>$pec);
		}
	} else {
		$f = sub {
			my ($pec) = @_;

			return sub { $pec->CommandExc($var, @_); }
		}
	}
	return ($f, $str);
}

sub get_next_array {
	my ($str) = @_;
	my $ret;
	my $char;

	do {
		(my $val, $str) = get_next_var($str, 'COMMA|RIGHTBRACKET');
		($char, $str) = get_next_lex($str);

		if (!defined($char)) {
			die "Parser error: unfinished array";
		}

		push(@$ret, $val);
	} while ($char eq 'COMMA');

	($ret, $str);
}

sub get_next_hash {
	my ($str) = @_;
	my $char;
	my $key;
	my @val;
	my $ret;
	my $state = 1;

	while (1) {
		($key, $str) = get_next_scalar($str, 'EQUALS|COMMA|RIGHTBRACE');
		($char, $str) = get_next_lex($str);

		if (!defined($key) || !defined($char)) {
			die "Parser error: unfinished hash";
		}

		$ret->{$key} = undef	if $char ne 'EQUALS';
		next			if $char eq 'COMMA';
		last			if $char eq 'RIGHTBRACE';

		($ret->{$key}, $str) = get_next_var($str, 'COMMA|RIGHTBRACE');
		($char, $str) = get_next_lex($str);

		if (!defined($char)) {
			die "Parser error: unfinished hash";
		}

		last if $char eq 'RIGHTBRACE';
	}

	($ret, $str);
}

#
# Calls get_next_var a maximum of 25 times returning a list of
# tokens.

sub tokenise {
	my ($string, $max) = @_;
	my @ret;
	my $word;
	my $i = 0;

	$max = 64 * 1024 * 1024 if !defined($max);

	$string = [ map { split(/(.{1,64})/, $_) } @$string ];

	while ($i++ < $max) {
		($word, $string) = get_next_var($string);

		last if !defined($string);

		push(@ret, $word);

		my $tmp;
		my $char;
		do {
			($char, $string) = get_next_lex($string);
		} while (defined($char) && $char =~ /SP/);

		last if !defined($char) || $char eq 'CRLF';

		if ($char ne 'SP') {
			$char = $token_map{$char} if exists($token_map{$char});
			unshift(@$string, $char);
		}
	}
	return \@ret;
}

my $logger_SessionID = 0;

sub set_logger_SessionID {
	($logger_SessionID) = @_;
}

my $logger_MsgNum = 0;

#
# log(LIST)
#
sub logger {
	# Our logmsg format:
	# time|gmtime|pid|session id|msg num|cont?|msg...
	#
	# Where
	#	session id is a unique session id chosen by the app
	#	msg num is a strictly increasing integer, starting at 0
	#	cont is a continuation indicator, "C" indicates this
	#		line is a continuation of the last, " " otherwise.

	my $preamble = time . "|" . gmtime() . "|$$|" .
	  $logger_SessionID;

	my $msg = join(" ", @_);

	my $offset = 0;

	while ($offset < length($msg)) {
		syslog('info', $preamble . "|" . $logger_MsgNum++ . "|" .
		       (($offset != 0) ? "C" : " ") . "|" .
		       substr($msg, $offset, 500));

		$offset += 500;
	}
}

1;
