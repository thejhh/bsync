# Layer to assert data
# $ID: $
package Logger;

use strict;
use warnings;
use diagnostics;

our $VERSION = sprintf "%d", q$Revision: 59 $ =~ /: (\d+)/;

my $has_syslog = 0;
eval "use Sys::Syslog qw( :DEFAULT setlogsock); \$has_syslog = 1; 1;";

my $has_stacktrace = 0;
eval "use Devel::StackTrace; \$has_stacktrace = 1; 1;";

my $writemsg = sub {
	print STDERR "[" . (shift) . "]" . join("", @_) . "\n";
};

if($has_syslog) {
	$writemsg = sub {
		setlogsock('unix');
		openlog($0, 'pid,cons,perror', 'user');
		syslog(shift, join("", @_));
		closelog();
	};
}

my $printstack = sub {};

if($has_stacktrace) {
	$printstack = sub {
		my $trace = Devel::StackTrace->new;
		my $trace_str = $trace->as_string;
		chomp($trace_str);
		my @lines = split("\n+", "-- start of stack trace --\n".$trace_str."\n-- end of stack trace --");
		foreach my $line (@lines) { &$writemsg("debug", $line); }
	}
}

my $use_debug = 0;
sub set_debug {
	$use_debug = int(shift);
}

my $verbose_level = 0;
sub set_verbose_level {
	$verbose_level = int(shift);
}

sub has_voice {
	return $verbose_level >= int(shift);
}

sub debug {
	&$writemsg("debug", "[debug] ", @_) if $use_debug;
}

sub info {
	&$writemsg("info",  "[info ] ", @_);
}

sub error {
	&$writemsg("err",   "[error] ", @_);
}

sub stacktrace {
	&$printstack();
}

# EOF
1;
__END__
