#!/usr/bin/perl
# Clones full disk partitions
# $Id: iscsiadm-login.pl 3 2010-08-30 07:34:33Z jheusala $

use POSIX;
use strict;
use warnings;
use diagnostics;
use Fi::Nor::Assert;
use Fi::Nor::System;
use Fi::Nor::System::iSCSIDiskDevice;

eval {
	
	my ($iqn, $ip) = @ARGV;
	Assert::iqn($iqn);
	Assert::ip($ip);
	
	my $iscsi = new iSCSIDiskDevice($iqn, $ip);
	$iscsi->login();
	$iscsi->setAutoLogout(0);
	
	1;
} or do {
	Logger::error("error: ", $@);
	exit 1;
};

# EOF
