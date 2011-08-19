# Layer to iscsi devices (login & logout)
package iSCSIDiskDevice;

use strict;
use warnings;
use diagnostics;
use Fi::Nor::Assert;
use Fi::Nor::System;

our $VERSION = sprintf "%d", q$Revision: 74 $ =~ /: (\d+)/;

my $ISCSIADM_CMD = System::which("iscsiadm");

sub new {
	Logger::debug("iSCSIDiskDevice::new(" . join(", ", @_) . ")");
	my $class = shift;
	my $iqn = shift;
	my $portal_addr = shift;
	my $portal_port = shift;
	$portal_port = 3260 unless defined($portal_port);
	Assert::iqn($iqn);
	Assert::ip($portal_addr);
	Assert::port($portal_port);
	my $self = {
		iqn => $iqn,
		portal => $portal_addr.":".$portal_port,
		sid => undef,
		dev => undef,
		is_logged => 0,
		autologout => 0,
	};
	bless $self, $class;
	return $self;
}

sub DESTROY {
	my( $self ) = @_;
	my $tmp = $@ ; # Backup exception
	eval {
		Logger::debug("iSCSIDiskDevice::DESTROY()");
		$self->logout() if $self->{"autologout"};
		1;
	} or do {
		Logger::error("error in iSCSIDisk DESTROY: ", $@);
	};
	$@ = $tmp; # Restore original exception
}

sub active {
	my( $self ) = @_;
	Logger::debug("iSCSIDiskDevice::active()");
	return $self->{"is_logged"};
}

sub login {
	Logger::debug("iSCSIDiskDevice::login(" . join(", ", @_) . ")");
	my( $self ) = @_;
	
	Assert::iqn($self->{"iqn"});
	Assert::portal($self->{"portal"});
	
	#if(!$self->{"is_logged"}) {
	#	eval {
	#		$self->resetSID();
	#		$self->resetDev();
	#		$self->{"is_logged"} = 1;
	#		1;
	#	} or do {
	#		Logger::debug($@);
	#	};
	#}
	my $sid = $self->_getSID($self->{"iqn"});
	die "iSCSI session already exists for ".$self->{"iqn"}.", stopped" if defined($sid);
	die "logged in already" if $self->{"is_logged"} || defined($self->{"sid"}) || defined($self->{"dev"});
	
	my ($status) = System::run($ISCSIADM_CMD, "-m", "node", "-T", $self->{"iqn"}, "-p", $self->{"portal"}, "-l");
	die "login failed, stopped" unless $status == 0;
	$self->{"is_logged"} = 1;
	$self->{"autologout"} = 1;
	$self->resetSID();
	$self->resetDev();
}

sub create {
	login(@_);
}

sub remove {
	logout(@_);
}

sub logout {
	Logger::debug("iSCSIDiskDevice::logout(" . join(", ", @_) . ")");
	my( $self ) = @_;
	my ($status) = System::run($ISCSIADM_CMD, "-m", "node", "-T", $self->{"iqn"}, "-p", $self->{"portal"}, "-u");
	#die "logout failed: $!" unless $status == 0;
	$self->{"is_logged"} = 0;
	$self->{"autologout"} = 0;
	$self->{"sid"} = undef;
	$self->{"dev"} = undef;
}

# Returns SID if session for IQN exists in the system, otherwise undef
sub _getSID {
	Logger::debug("iSCSIDiskDevice::_getSID(" . join(", ", @_) . ")");
	my( $self ) = @_;
	my $iqn = $self->{"iqn"};
	Assert::iqn($iqn);
	my ($status, @buffer) = System::getrun($ISCSIADM_CMD, "-m", "session");
	die "could not check SID: $!" unless $status == 0;
	for my $line (@buffer) {
		if($line =~ /^tcp: \[([0-9]+)\] [^ ]+ \Q$iqn\E$/) { return $1; }
	}
	return undef;
}

# Reset SID from system
sub resetSID {
	Logger::debug("iSCSIDiskDevice::resetSID(" . join(", ", @_) . ")");
	my( $self ) = @_;
	#my $iqn = $self->{"iqn"};
	#Assert::iqn($iqn);
	#my ($status, @buffer) = System::getrun($ISCSIADM_CMD, "-m", "session");
	#die "could not check SID: $!" unless $status == 0;
	#for my $line (@buffer) {
	#	if($line =~ /^tcp: \[([0-9]+)\] [^ ]+ \Q$iqn\E$/) { $self->{"sid"} = $1; return $self->{"sid"}; }
	#}
	my $sid = $self->_getSID($self->{"iqn"});
	die "Could not find SID for ".$self->{"iqn"}.", stopped" unless defined($sid);
	$self->{"sid"} = $sid;
}

# 
sub getSID {
	Logger::debug("iSCSIDiskDevice::getSID(" . join(", ", @_) . ")");
	my( $self ) = @_;
	$self->resetSID() unless defined($self->{"sid"});
	#$self->{"sid"} = $self->_getSID($self->{"iqn"}) unless defined($self->{"sid"});
	return $self->{"sid"};
}

# Reset device from system
sub resetDev {
	Logger::debug("iSCSIDiskDevice::resetDev(" . join(", ", @_) . ")");
	my( $self ) = @_;
	my $sid = $self->getSID();
	my ($status, @buffer) = System::getrun($ISCSIADM_CMD, "-m", "session", "-r", $sid, "-P3");
	die "could not check device: $!" unless $status == 0;
	for my $line (@buffer) {
		#Logger::debug("line = '$line'");
		if($line =~ /Attached scsi disk (sd[a-z]+)[ \t]/) { $self->{"dev"} = "/dev/".$1; return $self->{"dev"}; }
	}
	die "Could not find device for ".$self->{"iqn"}." (#$sid), stopped";
}

# 
sub getDev {
	Logger::debug("iSCSIDiskDevice::getDev(" . join(", ", @_) . ")");
	my( $self ) = @_;
	$self->resetDev() unless defined($self->{"dev"});
	return $self->{"dev"};
}

# 
sub setAutoLogout {
	Logger::debug("iSCSIDiskDevice::setAutoLogout(" . join(", ", @_) . ")");
	my( $self, $value ) = @_;
	$self->{"autologout"} = ($value) ? 1 : 0;
}

sub sync {
	my( $self ) = @_;
	Logger::debug("iSCSIDiskDevice::sync(" . join(", ", @_) . ")");
	$self->remove();
	$self->create();
}

# Get list of partitions. It can be listed before or after the mapping.
sub getPartitions {
	my( $self ) = @_;
	Logger::debug("iSCSIDiskDevice::getPartitions(" . join(", ", @_) . ")");
	#Assert::deviceObject($self);
	my %partitions = Block::getPartitions($self);
	my @devs;
	for my $k (keys %partitions) { push(@devs, $partitions{$k}->{"dev"}); }
	return @devs;
}

# EOF
1;
__END__
