# $Id: MappedDevice.pm 72 2010-09-02 15:01:50Z jheusala $
package MappedDevice;

use strict;
use warnings;
use diagnostics;
use Fi::Nor::Assert;
use Fi::Nor::System;

our $VERSION = sprintf "%d", q$Revision: 72 $ =~ /: (\d+)/;

our $KPARTX_CMD = System::which("kpartx");

sub new {
	Logger::debug("MappedDevice::new(" . join(", ", @_) . ")");
	my $class = shift;
	my $orig_dev = shift;
	Assert::deviceObject($orig_dev);
	my $self = {
		"orig_dev" => $orig_dev,
		"autoremove" => 0,
		"active" => 0,
	};
	bless $self, $class;
	Logger::debug("MappedDevice::new: active = " . $self->{"active"});
	return $self;
}

sub DESTROY {
	my( $self ) = @_;
	my $tmp = $@ ; # Backup exception
	eval {
		Logger::debug("MappedDevice::DESTROY()");
		Logger::debug("MappedDevice::DESTROY: active = " . $self->{"active"});
		$self->remove() if $self->{"autoremove"};
		1;
	} or do {
		Logger::debug("error in MappedDevice DESTROY: ", $@);
	};
	$@ = $tmp; # Restore original exception
}

sub create {
	Logger::debug("MappedDevice::create(" . join(", ", @_) . ")");
	my( $self ) = @_;
	Assert::deviceObject($self->{"orig_dev"});
	my ($status, $output, $error) = System::getrun2($KPARTX_CMD, "-a", $self->{"orig_dev"}->getDev());
	my $output_msgs = join("", @{$output});
	Logger::debug("kpartx stdout was: '$output_msgs'") unless length($output_msgs) == 0;
	my $error_msgs = join("", @{$error});
	$self->{"autoremove"} = 1;
	$self->{"active"} = 1;
	
	$self->remove() unless ($status == 0) && length($error_msgs) == 0;
	die "kpartx failed with errors: '$error_msgs', stopped" unless length($error_msgs) == 0;
	die "kpartx -a failed, stopped" unless $status == 0;
	
	Logger::debug("MappedDevice::create: active = " . $self->{"active"});
}

sub remove {
	Logger::debug("MappedDevice::remove(" . join(", ", @_) . ")");
	my( $self ) = @_;
	Assert::deviceObject($self->{"orig_dev"});
	my ($status, $output, $error) = System::getrun2($KPARTX_CMD, "-d", $self->{"orig_dev"}->getDev());
	my $output_msgs = join("", @{$output});
	Logger::debug("kpartx stdout was: '$output_msgs'") unless length($output_msgs) == 0;
	my $error_msgs = join("", @{$error});
	die "kpartx failed with errors: '$error_msgs', stopped" unless length($error_msgs) == 0;
	die "kpartx -d failed, stopped" unless $status == 0;
	$self->{"autoremove"} = 0;
	$self->{"active"} = 0;
	Logger::debug("MappedDevice::remove: active = " . $self->{"active"});
}


sub active {
	my( $self ) = @_;
	Logger::debug("MappedDevice::active()");
	Logger::debug("MappedDevice::active: active = " . $self->{"active"});
	return $self->{"active"};
}

# 
sub getDev {
	Logger::debug("MappedDevice::getDev(" . join(", ", @_) . ")");
	my( $self ) = @_;
	Assert::deviceObject($self->{"orig_dev"});
	return $self->{"orig_dev"}->getDev();
}

# Get list of partitions. It can be listed before or after the mapping.
sub getMappings {
	my( $self ) = @_;
	Logger::debug("MappedDevice::getMappings(" . join(", ", @_) . ")");
	Assert::deviceObject($self->{"orig_dev"});
	my ($status, $output, $error) = System::getrun2($KPARTX_CMD, "-l", $self->{"orig_dev"}->getDev());
	my @output_msgs = @{$output};
	Logger::debug("kpartx stdout was: '" . join("", @output_msgs) . "'") unless scalar(@output_msgs) == 0;
	my $error_msgs = join("", @{$error});
	die "kpartx failed with errors: '$error_msgs', stopped" unless length($error_msgs) == 0;
	die "kpartx failed, stopped" unless $status == 0;
	my @ret;
	for my $row (@output_msgs) {
		chomp($row);
		my @items = split(" ", $row);
		die "illegal amount of items: '$row'" unless scalar(@items) == 6;
		my %r;
		$r{"name"} = shift @items;
		$r{"path"} = "/dev/mapper/" . $r{"name"};
		shift @items;
		$r{"unknown"} = shift @items;
		$r{"size"} = shift @items;
		$r{"device"} = shift @items;
		$r{"start"} = shift @items;
		push(@ret, \%r);
	}
	return @ret;
}

# Get list of partitions. It can be listed before or after the mapping.
sub getPartitions {
	my( $self ) = @_;
	Logger::debug("MappedDevice::getPartitions(" . join(", ", @_) . ")");
	my @mappings = $self->getMappings();
	my @devs;
	for my $map (@mappings) { push(@devs, $map->{"path"}); }
	return @devs;
}

sub sync {
	my( $self ) = @_;
	Logger::debug("MappedDevice::sync(" . join(", ", @_) . ")");
	$self->remove();
	$self->create();
}

# EOF
1;
__END__
