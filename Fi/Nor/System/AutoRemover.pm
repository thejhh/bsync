# $Id: AutoRemover.pm 54 2010-08-31 06:49:35Z jheusala $
package AutoRemover;

use strict;
use warnings;
use diagnostics;
use Fi::Nor::Assert;
use Fi::Nor::System;
use Fi::Nor::Logger;

our $VERSION = sprintf "%d", q$Revision: 54 $ =~ /: (\d+)/;

sub new {
	Logger::debug("AutoRemover::new(" . join(", ", @_) . ")");
	my $class = shift;
	my @devices;
	my $self = \@devices;
	bless $self, $class;
	return $self;
}

sub DESTROY {
	my( $self ) = @_;
	my $tmp = $@ ; # Backup exception
	eval {
		Logger::debug("AutoRemover::DESTROY()");
		$self->remove();
		1;
	} or do {
		Logger::error("error in AutoRemover DESTROY: ", $@);
	};
	$@ = $tmp; # Restore original exception
}

# Push device at the end of the list
sub add {
	my( $self, $dev ) = @_;
	Logger::debug("AutoRemover::add(" . join(", ", @_) . ")");
	Assert::removableDeviceObject($dev);
	push( @{$self}, $dev);
}

# Remove all registered devices in reverse order
sub remove {
	my( $self ) = @_;
	my $tmp = $@ ; # Backup exception
	while( scalar(@{$self}) > 0) {
		my $dev = undef;
		eval {
			$dev = pop(@{$self});
			Logger::debug("Skipping device (already inactive): $dev (". $dev->getDev() .")" ) unless $dev->active();
			return 1 unless $dev->active();
			Logger::debug("Removing device: $dev (". $dev->getDev() . ")" );
			$dev->remove();
			1;
		} or do {
			Logger::error("Failed to remove device: ", $@);
			push(@{$self}, $dev) if defined($dev);
			Logger::info("Sleeping 5 seconds before trying again...");
			sleep 5;
		};
	}
	$@ = $tmp; # Restore original exception
}

# EOF
1;
__END__
