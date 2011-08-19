# $Id: Ext2.pm 55 2010-08-31 06:52:19Z jheusala $
package Ext2;

use strict;
use warnings;
use diagnostics;
use Fi::Nor::Assert;
use Fi::Nor::System;
use Fi::Nor::Logger;

our $VERSION = sprintf "%d", q$Revision: 55 $ =~ /: (\d+)/;

my $MKFS_EXT2_CMD = System::which("mkfs.ext2");

# Format filesystem
sub format {
	Logger::debug("Ext2::format(" . join(", ", @_) . ")");
	my( $part, %args ) = @_;
	
	# Asserts
	Assert::deviceObject($part);
	Assert::uuid($args{"uuid"}) if exists $args{"uuid"};
	
	my @args = ("-q");
	push(@args, "-U", delete $args{"uuid"}) if exists($args{"uuid"});
	die "unknown options: " . join(", ", keys(%args)) . ", stopped" unless scalar(keys(%args)) == 0;
	push(@args, $part->getDev());
	
	System::run($MKFS_EXT2_CMD, @args);
}

# EOF
1;
__END__
