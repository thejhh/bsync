#!/usr/bin/perl
# Clones full disk partitions
# $Id: ispartition.pl 3 2010-08-30 07:34:33Z jheusala $

use POSIX;
use strict;
use warnings;
use diagnostics;
use Fi::Nor::System::DummyDevice;
use Fi::Nor::System::Block;
use Fi::Nor::Logger;

eval {
	my $block = new DummyDevice(shift);
	my $ret = Block::isPartition($block);
	Logger::debug( "$0 returns " . (($ret) ? "true" : "false") . "\n" );
	exit $ret;
} or do {
	Logger::error("error: ", $@);
	exit 1;
};


# EOF
