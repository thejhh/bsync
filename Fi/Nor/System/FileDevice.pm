# $Id: FileDevice.pm 13 2010-08-30 13:22:45Z jheusala $
package FileDevice;

use strict;
use warnings;
use diagnostics;
use Fi::Nor::Assert;
use Fi::Nor::System;

our $VERSION = sprintf "%d", q$Revision: 13 $ =~ /: (\d+)/;

sub new {
	Logger::debug("FileDevice::new(" . join(", ", @_) . ")");
	my $class = shift;
	my $orig_dev = shift;
	Assert::fileExists($orig_dev);
	
	my $self = {
		"orig_dev" => $orig_dev,
		"autoremove" => 0,
	};
	bless $self, $class;
	return $self;
}

# 
sub getDev {
	Logger::debug("FileDevice::getDev(" . join(", ", @_) . ")");
	my( $self ) = @_;
	return $self->{"orig_dev"};
}

sub create {
	my( $self ) = @_;
	Logger::debug("DummyDevice::create(" . join(", ", @_) . ")");
	$self->{"active"} = 1;
}

sub remove {
	my( $self ) = @_;
	Logger::debug("DummyDevice::remove(" . join(", ", @_) . ")");
	$self->{"active"} = 0;
}

sub active {
	my( $self ) = @_;
	Logger::debug("DummyDevice::active()");
	return $self->{"active"};
}

sub sync {
	my( $self ) = @_;
	Logger::debug("DummyDevice::sync(" . join(", ", @_) . ")");
}

# EOF
1;
__END__
