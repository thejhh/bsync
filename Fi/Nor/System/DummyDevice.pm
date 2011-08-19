# $Id: DummyDevice.pm 12 2010-08-30 13:20:56Z jheusala $
package DummyDevice;

use strict;
use warnings;
use diagnostics;
use Fi::Nor::Assert;
use Fi::Nor::System;

our $VERSION = sprintf "%d", q$Revision: 12 $ =~ /: (\d+)/;

sub new {
	Logger::debug("DummyDevice::new(" . join(", ", @_) . ")");
	my $class = shift;
	my $orig_dev = shift;
	Assert::dev($orig_dev);
	
	my $self = {
		"orig_dev" => $orig_dev,
		"active" => 0,
		"autoremove" => 0,
	};
	bless $self, $class;
	return $self;
}

# 
sub getDev {
	Logger::debug("DummyDevice::getDev(" . join(", ", @_) . ")");
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
	Logger::debug("DummyDevice::sync(" . join(", ", @_) . ")");
}

# EOF
1;
__END__
