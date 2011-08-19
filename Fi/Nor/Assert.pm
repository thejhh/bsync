# Layer to assert data
# $ID: $
package Assert;

use strict;
use warnings;
use diagnostics;
use Fi::Nor::Capability;

our $VERSION = sprintf "%d", q$Revision: 68 $ =~ /: (\d+)/;

sub stack_die {
	Logger::stacktrace();
	die @_;
}

sub iqn {
	$_ = shift;
	stack_die "undefined iqn, stopped" unless defined $_;
	stack_die "illegal iqn: $_, stopped" unless $_ =~ /^iqn\.[0-9]{4}-[0-9]{2}(\.[a-z0-9\-]+)+(:[0-9a-zA-Z:\-]+)?$/;
}

sub ip {
	$_ = shift;
	stack_die "undefined ip, stopped" unless defined $_;
	stack_die "illegal ip: $_, stopped" unless $_ =~ /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
}

sub port {
	$_ = shift;
	stack_die "undefined port, stopped" unless defined $_;
	stack_die "illegal port: $_, stopped" unless $_ > 0 && $_ < 65536;
}

sub portal {
	my($ip, $port) = split(":", shift);
	ip($ip);
	port($port);
}

sub dev {
	$_ = shift;
	stack_die "dev not defined, stopped" unless defined($_);
	stack_die "illegal dev: $_, stopped" unless $_ =~ /^\/dev(\/[a-z0-9\-_]+)+$/;
}

sub lvname {
	$_ = shift;
	stack_die "lvname not defined, stopped" unless defined($_);
	stack_die "illegal lvname: $_, stopped" unless $_ =~ /^[a-z0-9\-_]+$/;
}

sub deviceObject {
	$_ = shift;
	stack_die "not a device object, stopped" unless Capability::isDevice($_);
	#stack_die "device object not defined, stopped" unless defined($_);
	#stack_die "not object ref: $_, stopped" unless ref($_) ne "";
	#stack_die "not a device object, stopped" unless $_->can("getDev");
}

sub removableDeviceObject {
	$_ = shift;
	stack_die "device object not defined, stopped" unless defined($_);
	stack_die "not a device object, stopped" unless $_->can("getDev");
	stack_die "device does not have active(), stopped" unless $_->can("active");
	stack_die "device does not have remove(), stopped" unless $_->can("remove");
}

sub mappedDeviceObject {
	$_ = shift;
	stack_die "not a mapped device object, stopped" unless Capability::isMappedDevice($_);
	#stack_die "device object not defined, stopped" unless defined($_);
	#stack_die "not a device object, stopped" unless $_->can("getDev");
	#stack_die "device does not have active(), stopped" unless $_->can("active");
	#stack_die "device does not have remove(), stopped" unless $_->can("remove");
	#stack_die "not a mapped device object, stopped" unless $_->can("getPartitions");
}

sub block {
	$_ = shift;
	stack_die "not a object, stopped" unless Capability::isObject($_);
	stack_die "not a block object, stopped" unless $_->can("getMainDev");
	stack_die "block does not have remove(), stopped" unless $_->can("hasPartitionTable");
	stack_die "block does not have remove(), stopped" unless $_->can("isPartition");
	stack_die "not a mapped block object, stopped" unless $_->can("getPartitions");
	stack_die "not a mapped block object, stopped" unless $_->can("getPartitionDevice");
	stack_die "block does not have active(), stopped" unless $_->can("sync");
}

sub remover {
	$_ = shift;
	stack_die "remover object not defined, stopped" unless defined($_);
	stack_die "not a remover object (no add method), stopped" unless $_->can("add");
	stack_die "not a remover object (no remove method), stopped" unless $_->can("remove");
}

sub integer {
	$_ = shift;
	stack_die "integer not defined, stopped" unless defined($_);
	stack_die "illegal integer: $_, stopped" unless $_ =~ /^[0-9]+$/;
}

sub directory {
	$_ = shift;
	stack_die "directory not defined, stopped" unless defined($_);
	stack_die "illegal directory value: $_, stopped" unless $_ =~ /^[a-z0-9\-_]*(\/[a-z0-9\-_]+)+$/;
}

sub directoryExists {
	$_ = shift;
	directory($_);
	stack_die "not a directory: $_" unless -d $_;
}

sub file {
	$_ = shift;
	stack_die "file not defined, stopped" unless defined($_);
	stack_die "illegal file value: $_, stopped" unless $_ =~ /^[a-z0-9\.\-_]*(\/[a-z0-9\.\-_]+)+$/;
}

sub fileExists {
	$_ = shift;
	file($_);
	stack_die "file does not exist: $_" unless -e $_;
}

sub uuid {
	$_ = shift;
	stack_die "uuid not defined, stopped" unless defined($_);
	stack_die "illegal uuid value: '$_', stopped" unless $_ =~ /^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$/;
}

sub noException {
	$_ = shift;
	stack_die "exception defined, stopped" if $_ ne "";
}

# EOF
1;
__END__
