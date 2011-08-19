#!/usr/bin/perl
# Clones full disk partitions
# $Id: list-partitions.pl 3 2010-08-30 07:34:33Z jheusala $

use POSIX;
use strict;
use warnings;
use diagnostics;
use Fi::Nor::Assert;
use Fi::Nor::System;
use Fi::Nor::System::LVSnapshotDevice;
use Fi::Nor::System::LoopDevice;
use Fi::Nor::System::MappedDevice;
use Fi::Nor::System::Block;

eval {
	
	my $device = shift @ARGV;
	Assert::dev($device);
	
	my $snapshot = new LVSnapshotDevice($device);
	my $snapshot_dev = $snapshot->getDev();
	$snapshot->create();
	
	Logger::debug("snapshot_dev = '$snapshot_dev'");
	
	my $snapshot_loop = new LoopDevice($snapshot);
	$snapshot_loop->create();
	my $snapshot_loop_dev = $snapshot_loop->getDev();
	
	Logger::debug("snapshot_loop_dev = '$snapshot_loop_dev'");
	
	my $mapped_snapshot = new MappedDevice($snapshot_loop);
	$mapped_snapshot->create();
	
	my @partitions = Block::getPartitions($mapped_snapshot);
	
	for my $ptr (@partitions) {
		my %part = %{$ptr};
		print $part{"dev"} . ";" . $part{"filesystem"});
	}
	
	1;
} or do {
	Logger::error("error: ", $@);
	exit 1;
};

# EOF
