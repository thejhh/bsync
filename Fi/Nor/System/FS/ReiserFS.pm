# $Id: ReiserFS.pm 55 2010-08-31 06:52:19Z jheusala $
package ReiserFS;

use strict;
use warnings;
use diagnostics;
use Fi::Nor::Assert;
use Fi::Nor::System;

our $VERSION = sprintf "%d", q$Revision: 55 $ =~ /: (\d+)/;

my $MKFS_REISERFS_CMD = System::which("mkreiserfs");

# Format filesystem
sub format {
	Logger::debug("ReiserFS::format(" . join(", ", @_) . ")");
	my( $part, %args ) = @_;
	Assert::deviceObject($part);
	Assert::uuid($args{"uuid"}) if exists $args{"uuid"};
	
	my @args = ("-q");
	push(@args, "-u", delete $args{"uuid"}) if exists($args{"uuid"});
	die "unknown options: " . join(", ", keys(%args)) . ", stopped" unless scalar(keys(%args)) == 0;
	push(@args, $part->getDev());
	System::run($MKFS_REISERFS_CMD, @args);
}

# EOF
1;
__END__
