#!/usr/bin/perl
# Clones full disk partitions
# $Id: uuid.pl 3 2010-08-30 07:34:33Z jheusala $

use POSIX;
use strict;
use warnings;
use diagnostics;
use Fi::Nor::System::DummyDevice;
use Fi::Nor::System::Block;
use Fi::Nor::Logger;

eval {
	my $block = new DummyDevice(shift);
	my $uuid = Block::getUUID($block);
	print "$uuid\n";
	exit 0;
} or do {
	Logger::error("error: ", $@);
	exit 1;
};


# EOF
