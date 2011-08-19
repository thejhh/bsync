# $Id: LoopDevice.pm 55 2010-08-31 06:52:19Z jheusala $
package LoopDevice;

use strict;
use warnings;
use diagnostics;
use Fi::Nor::Assert;
use Fi::Nor::System;

our $VERSION = sprintf "%d", q$Revision: 55 $ =~ /: (\d+)/;

my $LOSETUP_CMD = System::which("losetup");

sub get_next_dev() {
	my ($status, @data) = System::getrun("losetup", "-f");
	die "losetup -f failed, stopped" unless $status == 0;
	die "no data" if scalar(@data) == 0;
	my $dev = shift @data;
	chomp($dev);
	return $dev;
}

sub new {
	Logger::debug("LoopDevice::new(" . join(", ", @_) . ")");
	my $class = shift;
	my $orig_dev = shift;
	Assert::deviceObject($orig_dev);
	
	my $self = {
		"orig_dev" => $orig_dev,
		"loop_dev" => undef,
		"autoremove" => 0,
		"active" => 0,
	};
	bless $self, $class;
	return $self;
}

sub DESTROY {
	my( $self ) = @_;
	my $tmp = $@ ; # Backup exception
	eval {
		Logger::debug("LoopDevice::DESTROY()");
		$self->remove() if $self->{"autoremove"};
		1;
	} or do {
		Logger::debug("error in LoopDevice DESTROY: ", $@);
	};
	$@ = $tmp; # Restore original exception
}

sub create {
	Logger::debug("LoopDevice::create(" . join(", ", @_) . ")");
	my( $self ) = @_;
	
	Assert::deviceObject($self->{"orig_dev"});
	
	my $loop_dev = get_next_dev();
	$self->{"loop_dev"} = $loop_dev;
	Assert::dev($self->{"loop_dev"});
	
	my ($status) = System::run($LOSETUP_CMD, $self->{"loop_dev"}, $self->{"orig_dev"}->getDev());
	die "losetup failed, stopped" unless $status == 0;
	$self->{"autoremove"} = 1;
	$self->{"active"} = 1;
}

sub remove {
	Logger::debug("LoopDevice::remove(" . join(", ", @_) . ")");
	my( $self ) = @_;
	Assert::dev($self->{"loop_dev"});
	my ($status) = System::run($LOSETUP_CMD, "-d", $self->{"loop_dev"});
	die "losetup -d failed, stopped" unless $status == 0;
	$self->{"autoremove"} = 0;
	$self->{"active"} = 0;
}

sub active {
	my( $self ) = @_;
	Logger::debug("LoopDevice::active()");
	return $self->{"active"};
}

# 
sub getDev {
	Logger::debug("LoopDevice::getDev(" . join(", ", @_) . ")");
	my( $self ) = @_;
	return $self->{"loop_dev"};
}

sub sync {
	my( $self ) = @_;
	Logger::debug("LoopDevice::sync(" . join(", ", @_) . ")");
}

# EOF
1;
__END__
