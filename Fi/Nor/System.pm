# Layer to system commands etc
# $Id: System.pm 71 2010-09-01 12:22:43Z jheusala $
package System;

use POSIX;
use strict;
use warnings;
use diagnostics;
use Fi::Nor::Logger;

our $VERSION = sprintf "%d", q$Revision: 71 $ =~ /: (\d+)/;

my $DD_CMD = System::which("dd");
my $RSYNC_CMD = System::which("rsync");

# Returns true if device has mapped partitions capabilities
sub isMappedDevice {
	return 
}

# Get partition from device and number
sub getPartition {
	my($block, $number) = @_;
	Assert::deviceObject($block);
	Assert::integer($number);
	my $dev = $block->getDev();
	return $dev . "p" . $number if defined($number) && $dev =~ /[0-9]$/;
	return $dev . $number if defined($number) && $dev =~ /[a-z]$/;
	die "number not defined" unless defined($number);
	die "partition unknown $dev and $number";
}

# Get path to CNF
sub get_command_not_found {
	for my $dir ("/usr/lib", "/usr/share") {
		return "$dir/command-not-found" if -x "$dir/command-not-found";
	}
	return undef;
}

# Display info about command if not found
sub command_not_found {
	my $cnf = get_command_not_found();
	run($cnf, "--", shift) if defined($cnf);
}

# Search command from system and return path to it
sub which {
	my $cmd = shift;
	for my $dir ("/sbin", "/usr/sbin", "/bin", "/usr/bin") {
		return "$dir/$cmd" if -x "$dir/$cmd";
	}
	command_not_found($cmd);
	die "Could not find $cmd!";
}

# Get current date+time as string
sub getdatetime {
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$mon++;
	$year += 1900;
	return sprintf("%04d%02d%02d-%02d%02d%02d", $year, $mon, $mday, $hour, $min, $sec);
}

# Execute system command and return output as array
sub try_run {
	Logger::debug("System::try_run('" . join("', '", @_) . "')");
	my @ret = (0);
	return @ret;
}

# Execute system command and return output as array
sub getrun2 {
	Logger::debug("System::getrun2('" . join("', '", @_) . "')");
	Logger::info("+ " . join(" ", @_)) if Logger::has_voice(2);
	
	pipe(my $parent_read, my $child_write) or die "cannot pipe: $!, stopped";
	pipe(my $parent_error_read, my $child_error_write) or die "cannot pipe: $!, stopped";
	
	# Error
	my $pid = fork();
	die "cannot fork: $!, stopped" unless defined($pid);
	
	# Child
	if ($pid == 0) {
		eval {
			close $parent_read;
			close $parent_error_read;
			open(STDIN, "/dev/null");
			open(STDOUT, "<&=", fileno($child_write));
			open(STDERR, "<&=", fileno($child_error_write));
			exec(@_);
		};
		POSIX::_exit(1);
	}
	
	# Parent
	close $child_write;
	close $child_error_write;
	waitpid($pid, 0) or die;
	my $status = $?;
	
	open(CHILD_OUT, "<&=", fileno($parent_read)) or die;
	my @data = <CHILD_OUT>;
	close(CHILD_OUT) or die;
	
	open(CHILD_ERROR_OUT, "<&=", fileno($parent_error_read)) or die;
	my @errors = <CHILD_ERROR_OUT>;
	close(CHILD_ERROR_OUT) or die;
	
	Logger::debug("stdout: '", join("", @data), "'") unless scalar(@data) == 0;
	Logger::debug("stderr: '", join("", @errors), "'") if (scalar(@errors) != 0) && ($status==0);
	
	my @ret = ($status, \@data, \@errors);
	return @ret;

}

# Execute system command and return output as array
sub getrun {
	Logger::debug("System::getrun('" . join("', '", @_) . "')");
	my($status, $output_ptr, $error_ptr) = getrun2(@_);
	my @output = @{$output_ptr};
	my @errors = @{$error_ptr};
	Logger::debug("stdout: '", join("", @output), "'") unless scalar(@output) == 0;
	Logger::debug("stderr: '", join("", @errors), "'") if (scalar(@errors) != 0) && ($status==0);
	Logger::error("stderr: '", join("", @errors), "'") if (scalar(@errors) != 0) && ($status!=0);
	my @ret = ($status, @output);
	return @ret;
}

# Execute system command without returning output
sub run {
	Logger::debug("System::run('" . join("', '", @_) . "')");
	my($status, $output_ptr, $error_ptr) = getrun2(@_);
	my @output = @{$output_ptr};
	my @errors = @{$error_ptr};
	Logger::debug("stdout: '", join("", @output), "'") unless scalar(@output) == 0;
	Logger::debug("stderr: '", join("", @errors), "'") if (scalar(@errors) != 0) && ($status==0);
	Logger::error("stderr: '", join("", @errors), "'") if (scalar(@errors) != 0) && ($status!=0);
	my @ret = ($status);
	return @ret;
}

# Execute dd command to copy partition
sub dd {
	Logger::debug("System::dd('" . join("', '", @_) . "')");
	my %args = @_;
	my @args;
	
	if($args{"if"}) {
		Assert::dev($args{"if"});
		push(@args, "if=" . $args{"if"});
		delete $args{"if"};
	}
	
	if($args{"of"}) {
		Assert::dev($args{"of"});
		push(@args, "of=" . $args{"of"});
		delete $args{"of"};
	}
	
	if($args{"bs"}) {
		Assert::integer($args{"bs"});
		push(@args, "bs=" . $args{"bs"});
		delete $args{"bs"};
	}
	
	if($args{"count"}) {
		Assert::integer($args{"count"});
		push(@args, "count=" . $args{"count"});
		delete $args{"count"};
	}
	
	if($args{"skip"}) {
		Assert::integer($args{"skip"});
		push(@args, "skip=" . $args{"skip"});
		delete $args{"skip"};
	}
	
	if($args{"seek"}) {
		Assert::integer($args{"seek"});
		push(@args, "seek=" . $args{"seek"});
		delete $args{"seek"};
	}
	
	die "unknown arguments, stopped" unless scalar(keys(%args)) == 0;
	
	my ($status) = run($DD_CMD, @args);
	die "dd failed, stopped" unless $status == 0;
}

# Execute rsync command to copy two paths
sub rsyncDirs {
	Logger::debug("System::rsync('" . join("', '", @_) . "')");
	my($from, $dest) = @_;
	Assert::directoryExists($from);
	Assert::directoryExists($dest);
	
	my ($status) = run($RSYNC_CMD, "--quiet", "--delete", "-x", "--inplace", "-avzHAX", "$from/", "$dest/");
	die "rsync failed, stopped" unless $status == 0;
}

# EOF
1;
__END__
