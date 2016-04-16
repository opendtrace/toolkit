#!/usr/sbin/dtrace -s
/*
 * zilt10k.d		ZFS Latency Trace.
 *
 * This traces several types of user-level ZFS request, via the ZFS/VFS
 * interface.  The output will be verbose, as it includes ARC hits.
 *
 * This emits basic details for consumption by other tools.  
 * It ideally captures at least 10,000 I/O events.  It has
 * a 15 minute timeout if that is not possible.
 *
 * 25-Jun-2013	Brendan Gregg	Created this.
 * 23-Jan-2015  Lacey Powers    Updated for FreeBSD
 */

#pragma D option quiet
#pragma D option switchrate=5

BEGIN
{
	printf("ENDTIME(us) LATENCY(ns) TYPE SIZE(bytes) PROCESS\n");
	start = timestamp;
	n = 0;
}

fbt::zfs_freebsd_read:entry, fbt::zfs_freebsd_write:entry
/execname != "dtrace"/
{
	self->ts = timestamp;
	self->b = args[0]->a_uio->uio_resid;
}

fbt::zfs_freebsd_open:entry, fbt::zfs_freebsd_close:entry,
fbt::zfs_freebsd_readdir:entry, fbt::zfs_freebsd_getattr:entry
/execname != "dtrace"/
{
	self->ts = timestamp;
	self->b = 0;
}

fbt::zfs_freebsd_read:entry, fbt::zfs_freebsd_write:entry,
fbt::zfs_freebsd_open:entry, fbt::zfs_freebsd_close:entry,
fbt::zfs_freebsd_readdir:entry, fbt::zfs_freebsd_getattr:entry
/n++ > 10100/
{
	exit(0);
}

profile:::tick-15m { exit(0); }

fbt::zfs_freebsd_read:return, fbt::zfs_freebsd_write:return,
fbt::zfs_freebsd_open:return, fbt::zfs_freebsd_close:return,
fbt::zfs_freebsd_readdir:return, fbt::zfs_freebsd_getattr:return
/self->ts/
{
	printf("%d %d %s %d %s \n",
	    (timestamp - start) / 1000, timestamp - self->ts,
	    probefunc + 4, self->b, execname);
	self->ts = 0;
	self->b = 0;
}
