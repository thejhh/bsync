# Object capability tests
# $Id: Capability.pm 67 2010-09-01 10:50:13Z jheusala $
package Capability;

use strict;
use warnings;
use diagnostics;

# Returns true if device is object
sub isObject {
	$_ = shift;
	return  defined($_) && ref($_) ne "";
}

# Returns true if variable is a device object
sub isDevice {
	$_ = shift;
	return isObject($_) && $_->can("getDev");
}

# Returns true if device has mapped partitions capabilities
sub isMappedDevice {
	$_ = shift;
	return isDevice($_) && $_->can("active") && $_->can("remove") && $_->can("getPartitions");
}

# EOF
1;
__END__
