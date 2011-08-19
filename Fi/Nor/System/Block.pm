# $Id: Block.pm 3 2010-08-30 07:34:33Z jheusala $
package Block;

use strict;
use warnings;
use diagnostics;
use Fi::Nor::Assert;
use Fi::Nor::System;

our $VERSION = sprintf "%d", q$Revision: 3 $ =~ /: (\d+)/;

my $PARTED_CMD = System::which("parted");
my $BLKID_CMD = System::which("blkid");

# 
sub getPartitions {
	Logger::debug("Block::getPartitions(" . join(", ", @_) . ")");
	my( $dev ) = @_;
	Assert::deviceObject($dev);
	my($status, $output_ptr, $error_ptr) = System::getrun2($PARTED_CMD, "-sm", $dev->getDev(), "unit", "B", "print");
	my @output = @{$output_ptr};
	my @errors = @{$error_ptr};
	Logger::debug("parted stdout: '", join("", @output), "'") unless scalar(@output) == 0;
	Logger::error("parted stderr: '", join("", @errors), "'") unless scalar(@errors) == 0;
	die "parted failed, stopped" unless $status == 0;
	my @data = split(/;\n+/, join("", @output));
	die "no data" if scalar(@data) == 0;
	my $header = shift @data;
	die "unknown header $header" unless $header eq "BYT";
	die "no more data" if scalar(@data) == 0;
	shift @data;
	my %partitions;
	for my $row (@data) {
		Logger::debug("row = '$row')");
		my @parts = split(/:/, $row);
		next if scalar(@parts) == 0;
		my %h;
		$h{"number"} = shift(@parts) unless scalar(@parts) == 0;
		$h{"dev"} = System::getPartition($dev, $h{"number"}) if defined($h{"number"});
		$h{"start"} = shift(@parts) unless scalar(@parts) == 0;
		$h{"end"} = shift(@parts) unless scalar(@parts) == 0;
		$h{"size"} = shift(@parts) unless scalar(@parts) == 0;
		$h{"filesystem"} = shift(@parts) unless scalar(@parts) == 0;
		$h{"unknown1"} = shift(@parts) unless scalar(@parts) == 0;
		$h{"flags"} = shift(@parts) unless scalar(@parts) == 0;
		$h{"start"} =~ s/B$//;
		$h{"end"} =~ s/B$//;
		$h{"size"} =~ s/B$//;
		Assert::integer($h{"start"});
		Assert::integer($h{"end"});
		Assert::integer($h{"size"});
		$partitions{int($h{"number"})} = \%h;
	}
	return %partitions;
}

# 
sub blkid {
	Logger::debug("Block::blkid(" . join(", ", @_) . ")");
	my( $dev ) = @_;
	Assert::deviceObject($dev);
	my($status, $output_ptr, $error_ptr) = System::getrun2($BLKID_CMD, "-p", "-o", "full", $dev->getDev() );
	my @output = @{$output_ptr};
	my @errors = @{$error_ptr};
	Logger::debug("blkid stdout: '", join("", @output), "'") unless scalar(@output) == 0;
	Logger::error("blkid stderr: '", join("", @errors), "'") unless scalar(@errors) == 0;
	die "blkid failed, stopped" unless $status == 0;
	my @data = split(/\n/, join("", @output));
	die "no data" if scalar(@data) == 0;
	my $buffer = shift @data;
	my $devname = $dev->getDev();
	$buffer =~ s/^ +//;
	$buffer =~ s/ +$//;
	die "unknown buffer '$buffer'" unless $buffer =~ /^\Q$devname\E:(\s+\w+="[^"]*")+$/;
	$buffer =~ s/^\Q$devname\E://;
	my %ret;
	while($buffer =~ m/\s+(\w+)="([^"]+)"/g) {
		my $key = lc $1;
		my $value = $2;
		$ret{$key} = $value;
		Logger::debug("buffer has '$key' = '$value'");
	}
	Assert::uuid($ret{"uuid"}) if exists $ret{"uuid"};
	return %ret;
}

sub isPartition {
	Logger::debug("Block::isPartition(" . join(", ", @_) . ")");
	my( $dev ) = @_;
	my %ret;
	eval {
		%ret = blkid($dev);
		1;
	} or do {
		Logger::debug("Assuming there's no partition because blkid failed: $@");
		return 0;
	};
	foreach my $k (keys %ret) {
		Logger::debug("blkid." . $k . " = '" . $ret{$k} . "'");
	}
	return 0 if exists($ret{"pttype"});
	return 0 unless exists($ret{"type"}) && exists($ret{"usage"});
	return 1 if $ret{"usage"} eq "filesystem";
	return 1 if $ret{"usage"} eq "other" && $ret{"type"} eq "swap";
	return 0;
}

sub hasPartitionTable {
	Logger::debug("Block::hasPartitionTable(" . join(", ", @_) . ")");
	my( $dev ) = @_;
	my %ret;
	eval {
		%ret = blkid($dev);
		1;
	} or do {
		Logger::debug("Assuming there's no partition table because blkid failed: $@");
		return 0;
	};
	foreach my $k (keys %ret) {
		Logger::debug("blkid." . $k . " = '" . $ret{$k} . "'");
	}
	return exists($ret{"pttype"});
}

sub getUUID {
	Logger::debug("Block::getUUID(" . join(", ", @_) . ")");
	my( $dev ) = @_;
	my %ret;
	eval {
		%ret = blkid($dev);
		1;
	} or do {
		Logger::debug("Assuming there's no UUID because blkid failed: $@");
		return undef;
	};
	return undef unless exists($ret{"uuid"});
	return $ret{"uuid"};
}

sub getFilesystem {
	Logger::debug("Block::getFilesystem(" . join(", ", @_) . ")");
	my( $dev ) = @_;
	my %ret;
	eval {
		%ret = blkid($dev);
		1;
	} or do {
		Logger::debug("Assuming there's no filesystem because blkid failed: $@");
		return undef;
	};
	return undef unless exists($ret{"usage"}) && exists($ret{"type"});
	return "swap" if ($ret{"usage"} eq "other") && $ret{"type"} eq "swap";
	return $ret{"type"} if $ret{"usage"} eq "filesystem";
	return undef;
}

sub getPartitionNumber {
	Logger::debug("Block::getPartitionNumber(" . join(", ", @_) . ")");
	my( $dev ) = @_;
	Assert::deviceObject($dev);
	my $raw = $dev->getDev();
	return $1 if $raw =~ /[a-z]([0-9]+)$/;
	return undef;
}

# hasCompatiblePartitionTable <FROM> <DEST> -- Returns true if DEST has compatible partition table with FROM
sub hasCompatiblePartitionTable {
	my( $from, $dest ) = @_;
	Assert::deviceObject($from);
	Assert::deviceObject($dest);
	return 0 unless hasPartitionTable($from);
	return 0 unless hasPartitionTable($dest);
	my %from_partitions = getPartitions($from);
	my %dest_partitions = getPartitions($dest);
	return 0 unless scalar(keys(%from_partitions)) == scalar(keys(%dest_partitions));
	for my $k (keys %from_partitions) {
		return 0 unless exists($dest_partitions{$k});
		my %from_part = %{$from_partitions{$k}};
		my %dest_part = %{$dest_partitions{$k}};
		return 0 unless exists($from_part{"size"}) && exists($dest_part{"size"});
		my $from_size = $from_part{"size"};
		my $dest_size = $dest_part{"size"};
		return 0 unless $dest_size >= $from_size;
	}
	return 1;
}

# EOF
1;
__END__
