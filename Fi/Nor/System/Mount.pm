# Layer to LVM snapshots
# $Id: Mount.pm 3 2010-08-30 07:34:33Z jheusala $
package Mount;

use strict;
use warnings;
use diagnostics;
use Fi::Nor::System;
use Fi::Nor::Assert;

our $VERSION = sprintf "%d", q$Revision: 3 $ =~ /: (\d+)/;

my $MOUNT_CMD = System::which("mount");
my $UMOUNT_CMD = System::which("umount");

sub new {
	Logger::debug("Mount::new(" . join(", ", @_) . ")");
	my $class = shift;
	my $dev = shift;
	my $path = shift;
	Assert::deviceObject($dev);
	Assert::directory($path);
	
	my $self = {
		"dev" => $dev,
		"path" => $path,
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
		Logger::debug("Mount::DESTROY()");
		$self->remove() if $self->{"autoremove"};
		1;
	} or do {
		Logger::error("error in Mount::DESTROY: ", $@);
	};
	$@ = $tmp; # Restore original exception
}

sub create {
	Logger::debug("Mount::create(" . join(", ", @_) . ")");
	my( $self ) = @_;
	Assert::deviceObject($self->{"dev"});
	Assert::directoryExists($self->{"path"});
	my ($status) = System::run($MOUNT_CMD, $self->{"dev"}->getDev(), $self->{"path"});
	die "mount failed, stopped" unless $status == 0;
	$self->{"autoremove"} = 1;
	$self->{"active"} = 1;
}

sub remove {
	Logger::debug("Mount::remove(" . join(", ", @_) . ")");
	my( $self ) = @_;
	#Assert::dev($self->{"dev"});
	Assert::directoryExists($self->{"path"});
	my ($status) = System::run($UMOUNT_CMD, $self->{"path"});
	die "umount failed, stopped" unless $status == 0;
	$self->{"autoremove"} = 0;
	$self->{"active"} = 0;
}

sub active {
	my( $self ) = @_;
	Logger::debug("Mount::active()");
	return $self->{"active"};
}

# 
sub getDev {
	my( $self ) = @_;
	Logger::debug("Mount::getDev(" . join(", ", @_) . ")");
	Assert::deviceObject($self->{"dev"});
	return $self->{"dev"}->getDev();
}

# 
sub getPath {
	my( $self ) = @_;
	Logger::debug("Mount::getPath(" . join(", ", @_) . ")");
	Assert::directory($self->{"path"});
	return $self->{"path"};
}

# EOF
1;
__END__
