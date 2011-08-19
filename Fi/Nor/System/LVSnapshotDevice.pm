# Layer to LVM snapshots
# $Id: LVSnapshotDevice.pm 13 2010-08-30 13:22:45Z jheusala $
package LVSnapshotDevice;

use strict;
use warnings;
use diagnostics;
use Fi::Nor::System;
use Fi::Nor::Assert;

our $VERSION = sprintf "%d", q$Revision: 13 $ =~ /: (\d+)/;

my $LVCREATE_CMD = System::which("lvcreate");
my $LVREMOVE_CMD = System::which("lvremove");

sub parse_lvname {
	my $lvdir;
	my $lvname = "ss-" . System::getdatetime() . "-";
	my $dev = shift;
	if($dev =~ /^(.+)\/([a-zA-Z0-9]+)$/) {
		$lvdir = $1;
		$lvname .= $2;
	} else {
		die "could not parse lvdir/lvname from original device ($dev), stopped";
	}
	my @ret = ($lvdir, $lvname);
	return @ret;
}

sub new {
	Logger::debug("LVSnapshotDevice::new(" . join(", ", @_) . ")");
	my $class = shift;
	my $orig_dev = shift;
	my $size = shift;
	Assert::dev($orig_dev);
	my ($lvdir, $lvname) = parse_lvname($orig_dev);
	Assert::lvname($lvname);
	Assert::dev($lvdir."/".$lvname);
	$size = "2G" unless defined($size);
	
	my $self = {
		"lvdir" => $lvdir,
		"lvname" => $lvname,
		"orig_dev" => $orig_dev,
		"size" => $size,
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
		Logger::debug("LVSnapshotDevice::DESTROY()");
		$self->remove() if $self->{"autoremove"};
		1;
	} or do {
		Logger::error("error in lvm_snapshot DESTROY: ", $@);
	};
	$@ = $tmp; # Restore original exception
}

sub create {
	Logger::debug("LVSnapshotDevice::create(" . join(", ", @_) . ")");
	my( $self ) = @_;
	
	Assert::dev($self->{"orig_dev"});
	Assert::lvname($self->{"lvname"});
	die "no size" unless defined($self->{"size"});
	
	my ($status) = System::run($LVCREATE_CMD, "-s", "-L", $self->{"size"}, "-n", $self->{"lvname"}, $self->{"orig_dev"});
	die "lvcreate failed, stopped" unless $status == 0;
	$self->{"autoremove"} = 1;
	$self->{"active"} = 1;
}

sub remove {
	Logger::debug("LVSnapshotDevice::remove(" . join(", ", @_) . ")");
	my( $self ) = @_;
	my $lvdir = $self->{"lvdir"};
	my $full_lv = $self->getDev();
	Assert::dev($full_lv);
	die "not my snapshot, stopped" unless $full_lv =~ /^\Q$lvdir\E\/ss\-[0-9]+/;
	my ($status) = System::run($LVREMOVE_CMD, "-f", $full_lv);
	die "lvremove failed, stopped" unless $status == 0;
	$self->{"autoremove"} = 0;
	$self->{"active"} = 0;
}

sub active {
	my( $self ) = @_;
	Logger::debug("LVSnapshotDevice::active()");
	return $self->{"active"};
}

# 
sub getDev {
	my( $self ) = @_;
	Logger::debug("LVSnapshotDevice::getDev(" . join(", ", @_) . ")");
	return $self->{"lvdir"} . "/" . $self->{"lvname"};
}

sub sync {
	my( $self ) = @_;
	Logger::debug("LVSnapshotDevice::sync(" . join(", ", @_) . ")");
}

# EOF
1;
__END__
