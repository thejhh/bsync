# LocalBlock -- Local block device object
# $Id: LocalBlock.pm 67 2010-09-01 10:50:13Z jheusala $
package LocalBlock;

use strict;
use warnings;
use diagnostics;
use Fi::Nor::Logger;
use Fi::Nor::Assert;
use Fi::Nor::System::Block;
use Fi::Nor::System::DummyDevice;
use Fi::Nor::System::AutoRemover;
use Fi::Nor::Capability;

our $VERSION = sprintf "%d", q$Revision: 67 $ =~ /: (\d+)/;

sub new {
	Logger::debug("LocalBlock::new(" . join(", ", @_) . ")");
	my $class = shift;
	my $config = shift;
	my $self = {
		"config" => $config,
		"active" => 0,
		"remover" => undef,
		"dev" => undef,
		"mapped_dev" => undef,
	};
	bless $self, $class;
	$self->{"remover"} = AutoRemover->new();
	Assert::remover($self->{"remover"});
	$self->m_init_main_dev();
	return $self;
}

sub DESTROY {
	my( $self ) = @_;
	my $tmp = $@ ; # Backup exception
	eval {
		Logger::debug("LocalBlock::DESTROY()");
		$self->remove();
		1;
	} or do {
		Logger::debug("error in LocalBlock::DESTROY: ", $@);
	};
	$@ = $tmp; # Restore original exception
}

sub remove {
	my( $self ) = @_;
	die "no remover" unless defined($self->{"remover"});
	Assert::remover($self->{"remover"});
	$self->{"remover"}->remove();
}

sub getMainDev {
	Logger::debug("LocalBlock::getMainDev(" . join(", ", @_) . ")");
	my( $self ) = @_;
	return $self->{"dev"};
}

sub hasPartitionTable {
	Logger::debug("LocalBlock::hasPartitionTable(" . join(", ", @_) . ")");
	my( $self ) = @_;
	return Block::hasPartitionTable($self->{"dev"});
}

sub isPartition {
	Logger::debug("LocalBlock::isPartition(" . join(", ", @_) . ")");
	my( $self ) = @_;
	return Block::isPartition($self->{"dev"});
}

sub getPartitions {
	Logger::debug("LocalBlock::getPartitions(" . join(", ", @_) . ")");
	my( $self ) = @_;
	$self->m_init_mapped_dev();
	Assert::mappedDeviceObject($self->{"mapped_dev"});
	return $self->{"mapped_dev"}->getPartitions();
}

sub getPartitionDevice {
	Logger::debug("LocalBlock::getPartitionDevice(" . join(", ", @_) . ")");
	my( $self, $number ) = @_;
	Assert::integer($number);
	$self->m_init_mapped_dev();
	Assert::mappedDeviceObject($self->{"mapped_dev"});
	return DummyDevice->new(System::getPartition($self->{"mapped_dev"}, $number));
}

sub sync {
	Logger::debug("LocalBlock::sync(" . join(", ", @_) . ")");
	my( $self, $number ) = @_;
	$self->{"mapped_dev"}->sync() if defined($self->{"mapped_dev"});
}

sub m_init_main_dev {
	Logger::debug("LocalBlock::m_init_main_dev(" . join(", ", @_) . ")");
	my( $self ) = @_;
	if(!defined($self->{"dev"})) {
		Assert::remover($self->{"remover"});
		$self->{"dev"} = _get_device($self->{"remover"}, $self->{"config"});
	}
}

sub m_init_mapped_dev {
	Logger::debug("LocalBlock::m_init_mapped_dev(" . join(", ", @_) . ")");
	my( $self ) = @_;
	if(!defined($self->{"mapped_dev"})) {
		
		if(Capability::isMappedDevice($self->{"dev"})) {
			Assert::mappedDeviceObject($self->{"dev"});
			$self->{"mapped_dev"} = $self->{"dev"};
			return;
		}
		
		require Fi::Nor::System::MappedDevice or die;
		Assert::remover($self->{"remover"});
		$self->{"mapped_dev"} = MappedDevice->new($self->{"dev"});
		$self->{"remover"}->add($self->{"mapped_dev"});
		$self->{"mapped_dev"}->create();
	}
}

# Create device based on current config
sub _get_device {
	Logger::debug("LocalBlock::get_device(" . join(", ", @_) . ")");
	my ($r, $config) = @_;
	die "remover undefined, stopped" unless defined($r);
	die "config undefined, stopped" unless defined($config);
	return _get_iscsi_device($r, $config) if $config =~ /^iscsi:\/\//;
	return _get_lvm_snapshot_device($r, $config) if $config =~ /^lvm\+snapshot:\/\//;
	return _get_loop_device($r, $config) if $config =~ /^loop:\/\//;
	return _get_bulk_device($r, $config) if $config =~ /^bulk:\/\/\/dev\//;
	return _get_loop_device($r, "loop://".$config);
	#die "unknown config type: $config, stopped";
}

sub _get_bulk_device {
	Logger::debug("LocalBlock::get_bulk_device(" . join(", ", @_) . ")");
	my ($dest_remover, $config) = @_;
	my $dev = $config;
	$dev =~ s/^bulk:\/\///;
	return DummyDevice->new($dev);
}

sub _get_loop_device {
	Logger::debug("LocalBlock::get_loop_device(" . join(", ", @_) . ")");
	my ($from_remover, $config) = @_;
	if($config =~ /^loop:\/\/(.+)$/) {
		my $file = $1;
		Assert::fileExists($file);
		require Fi::Nor::System::FileDevice or die "failed to load FileDevice module: $!, stopped";
		require Fi::Nor::System::LoopDevice or die "failed to load LoopDevice module: $!, stopped";
		my $dev = FileDevice->new($file);
		my $from = LoopDevice->new($dev);
		$from_remover->add($from);
		$from->create();
		Logger::debug("from.dev = '".$from->getDev()."'");
		Logger::info("Loop device opened for $file to " . $from->getDev() ) if Logger::has_voice(1);
		return $from;
	}
	die "unknown config: $config, stopped";
}

sub _get_iscsi_device {
	Logger::debug("LocalBlock::get_iscsi_device(" . join(", ", @_) . ")");
	my ($dest_remover, $config) = @_;
	
	my $dest_iqn;
	my $dest_portal_ip;
	my $dest_portal_port;
	
	if($config =~ /^iscsi:\/\/([\w\.]+):(\d+)\/(iqn\.[0-9]{4}-[0-9]{2}\.\w+\.\w+(:.*)?)$/) {
		$dest_portal_ip = $1;
		$dest_portal_port = $2;
		$dest_iqn = $3;
	} elsif($config =~ /^iscsi:\/\/([\w\.]+)\/(iqn\.[0-9]{4}-[0-9]{2}\.\w+\.\w+(:.*)?)$/) {
		$dest_portal_ip = $1;
		$dest_portal_port = 3260;
		$dest_iqn = $2;
	} else {
		die "unknown config: $config, stopped";
	}
	
	Assert::iqn($dest_iqn);
	Assert::ip($dest_portal_ip);
	Assert::port($dest_portal_port);
	require Fi::Nor::System::iSCSIDiskDevice or die;
	my $dest = iSCSIDiskDevice->new($dest_iqn, $dest_portal_ip, $dest_portal_port);
	$dest_remover->add($dest);
	$dest->login();
	Logger::debug("dest.iscsi.sid = " . $dest->getSID() );
	Logger::debug("dest.dev = '" . $dest->getDev() . "'");
	Logger::info("iSCSI device opened for $dest_iqn (portal $dest_portal_ip:$dest_portal_port) to " . $dest->getDev() ) if Logger::has_voice(1);
	return $dest;
}

sub _get_lvm_snapshot_device {
	Logger::debug("LocalBlock::get_lvm_snapshot_device(" . join(", ", @_) . ")");
	my ($from_remover, $config) = @_;
	if($config =~ /^lvm\+snapshot:\/\/(\w+)\/(\w+)$/) {
		my $from_lv = "/dev/$1/$2";
		Assert::dev($from_lv);
		require Fi::Nor::System::LVSnapshotDevice or die;
		my $from_snapshot = LVSnapshotDevice->new($from_lv);
		$from_remover->add($from_snapshot);
		$from_snapshot->create();
		Logger::debug("from_snapshot.dev = '", $from_snapshot->getDev(), "'");
		require Fi::Nor::System::LoopDevice or die;
		my $from = LoopDevice->new($from_snapshot);
		$from_remover->add($from);
		$from->create();
		Logger::debug("from.dev = '".$from->getDev()."'");
		Logger::info("LVM snapshot opened from $from_lv to " . $from->getDev() ) if Logger::has_voice(1);
		return $from;
	}
	die "unknown config: $config, stopped";
}

# EOF
1;
__END__
