bsync -- Block device file-copying tool
=======================================

Exported to GitHub from [old SVN 
repository](https://svn.sendanor.fi/svn/bsync/trunk/).

SYNOPSIS
--------

	bsync SRC DEST

DESCRIPTION
-----------

where `SRC` or `DEST` is one of:

* iscsi://`PORTAL`[:`PORT`]/`IQN` -- Opens remote iSCSI device
* lvm+snapshot://`VOLUMEGROUP`/`LOGICALNAME` -- Opens LVM snapshot
* loop://`FILE`|`DEVICE` -- Opens local file or device as a loop device
* `DEVICE` -- Use local device directly

GENERAL
-------

Bsync duplicates full disks or single partitions at the filesystem level using rsync (and dd) and takes the responsibility of resource acquisition and automatic deallocation.

When source and destination partition(s) have the same UUID it will only transfer changed files, otherwise new partition(s) are formated with the same UUIDs and all files are copied there.

When source device has an MBR and destination has compatible partition layouts (either the same size or greater), only 446 bytes are copied and destination partition layout will be unchanged, otherwise full MBR (512 bytes) will be copied including the new partition layout from source.

When source has no MBR/partition table but has a filesystem, only that filesystem is duplicated to the destination.

SUPPORTED PARTITION LAYOUTS
---------------------------

* DOS

SUPPORTED FILESYSTEMS
---------------------

Full copy support:
* Ext2
* Ext3
* Ext4
* ReiserFS v3

Also partial support:
* Linux swap -- no contents are copied! Do not use bsync to copy partitions containing hibernated memory images.

USAGE
-----

Clone local LVM logical device to remote iSCSI disk:

 bsync lvm+snapshot://vg0/testsys1 iscsi://10.0.0.10/iqn.1986-03.com.sun:02:f9390d7d-d25c-6b5f-9c50-fa8255c6173a 

Clone remote iSCSI disk to local file image. The file has to be created first with correct size:

 dd if=/dev/zero of=/tmp/system.img bs=1048576 count=1024
 bsync iscsi://10.0.0.10/iqn.1986-03.com.sun:02:f9390d7d-d25c-6b5f-9c50-fa8255c6173a loop:///tmp/system.img

Duplicate two iSCSI disks:

 bsync iscsi://10.0.0.10/iqn.1986-03.com.sun:02:f9390d7d-d25c-6b5f-9c50-fa8255c6173a iscsi://10.0.0.10/iqn.1986-03.com.sun:02:19423a5c-7bc6-4597-8e33-db31eade44d2

VERSION
-------

Beta testing; '''no stable release!'''.

LICENSE
-------

GPL v2. See COPYING from source code.
