#!/usr/bin/perl
# Clones full disk partitions
# $Id: bsync.pl 41 2010-08-30 16:02:20Z jheusala $

use strict;
use warnings;
use diagnostics;

my $VERSION = "0.0.20100830";

# Setup script's home directory to @INC
BEGIN {
	my $dir = $0;
	$dir =~ s/\/[^\/]*$//;
	#print STDERR "DEBUG: dir=" . $dir . "\n";
	push(@INC, $dir);
}

# Setup signal handlers
sub warn_sighandler {
	my $signame = shift;
	warn "Received SIG$signame, ignored";
	$SIG{$signame} = \&warn_sighandler;
}

sub die_sighandler {
	my $signame = shift;
	die "Received SIG$signame, stopped";
	$SIG{$signame} = \&die_sighandler;
}

foreach my $k ("ALRM", "HUP", "BUS", "HUP", "ILL", "IO", "PIPE", "PROF", "PWR", "SEGV", "STKFLT", "SYS", "TRAP", "USR1", "USR2", "VTALRM", "XCPU", "XFSZ") {
	$SIG{$k} = \&warn_sighandler;
}

foreach my $k ("INT", "ABRT", "KILL", "TERM") { $SIG{$k} = \&die_sighandler; }



# Copy MBR from left to right
sub do_copy_mbr {
	Logger::debug("main::do_copy_mbr(" . join(", ", @_) . ")");
	my ($from_dev, $dest_dev, %config) = @_;
	
	# Asserts
	Assert::block($from_dev);
	Assert::block($dest_dev);
	
	my $bytes = Block::hasCompatiblePartitionTable($from_dev->getMainDev(), $dest_dev->getMainDev()) ? 446 : 512;
	
	Logger::info("Copying $bytes bytes of MBR from " . $from_dev->getMainDev()->getDev() . " to " . $dest_dev->getMainDev()->getDev() ) if Logger::has_voice(1);
	
	# Action
	System::dd(
		"if" => $from_dev->getMainDev()->getDev(),
		"of" => $dest_dev->getMainDev()->getDev(), 
		"bs" => $bytes,
		"count" => 1,
	);
	
	# Resync partition table mappings
	$dest_dev->sync() if $bytes == 512;
}

# Format partition
sub do_format_partition {
	Logger::debug("main::do_format_partition(" . join(", ", @_) . ")");
	my ($dest_part, %args) = @_;
	
	# Asserts
	Assert::deviceObject($dest_part);
	die "no fstype for ".$dest_part->getDev() unless defined($args{"fstype"});
	Assert::uuid($args{"uuid"});
	
	my $fstype = $args{"fstype"};
	my $uuid = $args{"uuid"};
	
	Logger::info("Formating ". $dest_part->getDev(). " as $fstype with UUID $uuid") if Logger::has_voice(1);
	
	if($fstype eq "ext2") {
		require Fi::Nor::System::FS::Ext2 or die;
		Ext2::format( $dest_part, "uuid"=>$uuid );
	} elsif($fstype eq "ext3") {
		require Fi::Nor::System::FS::Ext3 or die;
		Ext3::format( $dest_part, "uuid"=>$uuid );
	} elsif($fstype eq "ext4") {
		require Fi::Nor::System::FS::Ext4 or die;
		Ext4::format( $dest_part, "uuid"=>$uuid );
	} elsif( $fstype =~ /^(swap|linux-swap.*)/i) {
		require Fi::Nor::System::FS::Swap or die;
		Swap::format( $dest_part, "uuid"=>$uuid );
	} elsif($fstype eq "reiserfs") {
		require Fi::Nor::System::FS::ReiserFS or die;
		ReiserFS::format( $dest_part, "uuid"=>$uuid );
	} else {
		die "$dest_part: unknown filesystem: $fstype, stopped";
	}
}

# Copy single partition from left to right, with only changes
sub do_copy_partition_changes {
	Logger::debug("main::do_copy_partition_changes(" . join(", ", @_) . ")");
	my ($from_dev, $dest_dev, %config) = @_;
	
	my $parent_mount_path = "/mnt/bsync";
	my $from_mount_path = "$parent_mount_path/src";
	my $dest_mount_path = "$parent_mount_path/dest";
	
	# Asserts
	Assert::deviceObject($from_dev);
	Assert::deviceObject($dest_dev);
	mkdir($parent_mount_path) unless -e $parent_mount_path;
	mkdir($from_mount_path) unless -e $from_mount_path;
	mkdir($dest_mount_path) unless -e $dest_mount_path;
	Assert::directoryExists($from_mount_path);
	Assert::directoryExists($dest_mount_path);
	
	# Mount partitions
	my $remover = new AutoRemover();
	eval {
		my $from = new Mount( $from_dev, $from_mount_path );
		$remover->add($from);
		$from->create();
		Logger::info("Mounted " . $from_dev->getDev() . " to " . $from->getPath() ) if Logger::has_voice(1);
		
		my $dest = new Mount( $dest_dev, $dest_mount_path );
		$remover->add($dest);
		$dest->create();
		Logger::info("Mounted " . $dest_dev->getDev() . " to " . $dest->getPath() ) if Logger::has_voice(1);
		
		# Copy changes
		Logger::info("Copying changes from ". $from->getPath(). " to " . $dest->getPath() ) if Logger::has_voice(1);
		System::rsyncDirs($from->getPath(), $dest->getPath());
		
		1;
	} or do {
		$remover->remove();
		die;
	};
	$remover->remove();
}

sub do_copy_partition {
	Logger::debug("main::do_copy_partition(" . join(", ", @_) . ")");
	my ($from, $dest, %config) = @_;
	
	Assert::deviceObject($from);
	Assert::deviceObject($dest);
	
	my $from_uuid = Block::getUUID($from);
	my $dest_uuid = Block::getUUID($dest);
	$dest_uuid = "" unless defined($dest_uuid);
	
	Assert::uuid($from_uuid);
	Assert::uuid($dest_uuid) unless $dest_uuid eq "";
	
	my $from_fstype = Block::getFilesystem($from);
	die "no from.fstype for ".$from->getDev().", stopped" unless defined($from_fstype);
	
	do_format_partition( $dest, "uuid"=>$from_uuid, "fstype"=>$from_fstype) unless $from_uuid eq $dest_uuid;
	
	return if $from_fstype eq "swap";
	die "unknown filesystem type: $from_fstype, stopped" unless $from_fstype =~ /^(ext[234]|reiserfs)$/;
	do_copy_partition_changes( $from, $dest, %config );
}

sub do_copy_fulldisk {
	Logger::debug("main::do_copy_fulldisk(" . join(", ", @_) . ")");
	my ($from, $dest, %config) = @_;
	
	Assert::block($from);
	Assert::block($dest);
	
	# Copy MBR
	if(defined($config{"use_copy_mbr"}) && $config{"use_copy_mbr"}) {
		Logger::debug("Copying MBR...");
		do_copy_mbr($from, $dest, %config);
	}
	
	# Format and copy partitions on the new block device
	Logger::debug("Copying partitions...");
	my @partitions = $from->getPartitions();
	foreach my $from_part_dev (@partitions) {
		my $from_part = new DummyDevice($from_part_dev);
		Assert::deviceObject($from_part);
		my $number = Block::getPartitionNumber($from_part);
		die "could not find partition number for ".$from->getDev().", stopped" unless defined($number);
		do_copy_partition($from_part, $dest->getPartitionDevice($number), %config );
	}
}

sub do_copy {
	Logger::debug("main::do_copy(" . join(", ", @_) . ")");
	my ($from, $dest, %config) = @_;
	
	Assert::block($from);
	Assert::block($dest);
	
	return do_copy_fulldisk($from, $dest, %config) if $from->hasPartitionTable();
	return do_copy_partition($from->getMainDev(), $dest->getMainDev(), %config) if $from->isPartition();
	die "unknown device type, stopped";
}

# Main block
eval {
	use Fi::Nor::Assert;
	use Fi::Nor::Logger;
	use Fi::Nor::System;
	use Fi::Nor::System::AutoRemover;
	use Fi::Nor::System::Block;
	use Fi::Nor::System::Mount;
	use Fi::Nor::System::DummyDevice;
	use Fi::Nor::LocalBlock;
	
	# Parsing arguments
	my %config;
	$config{"use_copy_mbr"} = 1;
	$config{"use_debug"} = 0;
	$config{"verbose_level"} = 1;
	my @args = @ARGV;
	my @free_args;
	eval {
		for my $arg (@args) {
			if($arg =~ /^-/) {
				if($arg eq "--debug") {
					$config{"use_debug"} = 1;
					next;
				}
				if( ($arg eq "--verbose") || ($arg eq "-v") ) {
					$config{"verbose_level"}++;
					next;
				}
				if( ($arg eq "--quiet") || ($arg eq "-q") ) {
					$config{"verbose_level"} = 0;
					next;
				}
				if($arg eq "--disable-mbr-copy") {
					$config{"use_copy_mbr"} = 0;
					next;
				}
				if($arg eq "--version") {
					my $version = sprintf "%d", q$Revision: 41 $ =~ /: (\d+)/;
					my $date = sprintf "%s", q$Date: 2010-08-30 19:02:20 +0300 (Mon, 30 Aug 2010) $ =~ /: ([^\$]+)/;
					print STDOUT "bsync v$VERSION\n";
					print STDOUT "svn.revision: $version\n";
					print STDOUT "svn.date: $date\n";
					exit 0;
				}
				if(($arg eq "--help") || ($arg eq "-h")) {
					print STDOUT "USAGE: $0 [OPTION(S)] SRC DEST\n";
					print STDOUT "\n";
					print STDOUT "where OPTIONS is one of:\n";
					print STDOUT "     --debug    Extra debug information\n";
					print STDOUT "  -h --help     Print this info\n";
					print STDOUT "     --version  Print version information\n";
					print STDOUT "  -v --verbose  Increase verbose level\n";
					print STDOUT "  -q --quiet    Supress verbose level to 0\n";
					print STDOUT "\n";
					print STDOUT "where SRC or DEST is one of:\n";
					print STDOUT "  iscsi://<PORTAL>[:<PORT>]/<IQN>\n";
					print STDOUT "  lvm+snapshot://<VOLUMEGROUP>/<LOGICALNAME>\n";
					print STDOUT "  loop://<FILE|DEVICE>\n";
					print STDOUT "  <DEVICE>\n";
					print STDOUT "\n";
					exit 0;
				}
				die "unknown option: $arg\n";
			}
			push(@free_args, $arg);
		}
		die "too many arguments\n" if scalar(@free_args) > 2;
		die "too few arguments\n" unless scalar(@free_args) == 2;
		1;
	} or do {
		print STDERR "USAGE: $0 [OPTIONS] SRC DEST\n";
		print STDERR "Error: " . $@ . "\n";
		exit 1;
	};
	Logger::set_debug($config{"use_debug"});
	Logger::set_verbose_level($config{"verbose_level"});
	my ($from_config, $dest_config) = @free_args;
	
	# Preparing from device (LVM snapshot)
	my $from = new LocalBlock($from_config);
	
	# Preparing dest device (iSCSI)
	my $dest = new LocalBlock($dest_config);
	
	# Action
	do_copy($from, $dest, %config);
	
	1;
} or do {
	Logger::error("error: ", $@, "");
	exit 1;
};

Logger::info("All OK.");
# EOF
