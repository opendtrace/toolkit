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
 * Copyright (c) 2013 Brendan Gregg. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * 25-Jun-2013	Brendan Gregg	Created this.
 * 23-Jan-2015  Lacey Powers    Updated for FreeBSD
 */

#pragma D option quiet
#pragma D option switchrate=5
#pragma D option defaultargs

BEGIN
{
	printf("ENDTIME(us) LATENCY(ns) TYPE SIZE(bytes) PROCESS\n");
	start = timestamp;
	n = 0;
	times = $1 != NULL ? $1 : 10100;
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
/n++ > times/
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
