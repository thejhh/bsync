#!/usr/bin/perl
# Clones full disk partitions
# $Id: lo-format.pl 3 2010-08-30 07:34:33Z jheusala $

eval {
	
	use POSIX;
	use strict;
	use warnings;
	use diagnostics;
	use Fi::Nor::Assert;
	use Fi::Nor::System;
	use Fi::Nor::System::AutoRemover;
	use Fi::Nor::System::LVSnapshotDevice;
	use Fi::Nor::System::LoopDevice;
	use Fi::Nor::System::MappedDevice;
	use Fi::Nor::System::Block;
	use Fi::Nor::System::DummyDevice;
	use Fi::Nor::System::FS::ReiserFS;
	use Fi::Nor::System::FS::Ext3;
	use Fi::Nor::System::FS::Swap;
	
	my $remover = new AutoRemover();
	
	my $device = shift @ARGV;
	Assert::dev($device);
	my $block_dev = new DummyDevice($device);
	Logger::debug("block_dev = '" . $block_dev->getDev() ."'");
	
	my $block_loop_dev = new LoopDevice($block_dev);
	$remover->add($block_loop_dev);
	$block_loop_dev->create();
	
	Logger::debug("block_loop_dev = '". $block_loop_dev->getDev() ."'");
	
	my $dev = new MappedDevice($block_loop_dev);
	$remover->add($dev);
	$dev->create();
	
	my @partitions = $dev->getPartitions();
	die "wrong amount of partitions" unless scalar(@partitions) == 3;
	Ext3::format( new DummyDevice(shift @partitions) );
	Swap::format( new DummyDevice(shift @partitions) );
	ReiserFS::format( new DummyDevice(shift @partitions) );
	
	#System::run(System::which("mkfs.ext3"), System::getPartition($dev, 1));
	#System::run(System::which("mkswap"), System::getPartition($dev, 2));
	#System::run(System::which("mkreiserfs"), System::getPartition($dev, 3));
	
	1;
} or do {
	Logger::error("error: ", $@);
	exit 1;
};

# EOF
