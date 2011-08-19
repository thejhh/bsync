#!/usr/bin/perl
# Clones full disk partitions
# $Id: block-list.pl 3 2010-08-30 07:34:33Z jheusala $

use POSIX;
use strict;
use warnings;
use diagnostics;
use Fi::Nor::System::DummyDevice;
use Fi::Nor::System::Block;

eval {
	my $block = new DummyDevice(shift);
	my @partitions = Block::getPartitions($block);
	for my $ptr (@partitions) {
		my %part = %{$ptr};
		print $part{"dev"} . ";" . $part{"filesystem"} . "\n";
	}
	
	1;
} or do {
	Logger::error("error: ", $@);
	exit 1;
};

# EOF
