#!/usr/sbin/dtrace -s
/*
 * zfsslower.d	show ZFS I/O taking longer than given ms.
 *
 * USAGE: zfsslower.d min_ms
 *    eg,
 *        zfsslower.d 100	# show I/O at least 100 ms
 *
 * This is from the DTrace book, chapter 5.  It has been enhanced to include
 * zfs_readdir() as well, which is shown in the "D" (direction) field as "D".
 *
 * CDDL HEADER START
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License, Version 1.0 only
 * (the "License").  You may not use this file except in compliance
 * with the License.
 *
 * You can obtain a copy of the license at http://smartos.org/CDDL
 *
 * See the License for the specific language governing permissions
 * and limitations under the License.
 *
 * When distributing Covered Code, include this CDDL HEADER in each
 * file.
 *
 * If applicable, add the following below this CDDL HEADER, with the
 * fields enclosed by brackets "[]" replaced with your own identifying
 * information: Portions Copyright [yyyy] [name of copyright owner]
 *
 * CDDL HEADER END
 *
 * Copyright (c) 2012 Joyent Inc., All rights reserved.
 * Copyright (c) 2012 Brendan Gregg, All rights reserved.
 *
 * TESTED: this fbt provider based script may only work on some OS versions.
 *      121: ok
 * 
 * 2015-01-22 Lacey Powers Updated for FreeBSD 10.1. 
 */

#pragma D option quiet
#pragma D option defaultargs
#pragma D option dynvarsize=64m
#pragma D option bufsize=16m
#pragma D option switchrate=10hz

dtrace:::BEGIN
{
        printf("%-20s %-16s %1s %4s %6s %s\n", "TIME", "PROCESS",
            "D", "KB", "ms", "FILE");
        min_ns = $1 * 1000000;
}

/* see sys/cddl/contrib/opensolaris/uts/common/fs/zfs/zfs_vnops.c */

fbt::zfs_freebsd_read:entry, fbt::zfs_freebsd_write:entry
{
	this->ncp = &(args[0]->a_vp->v_cache_dst) != NULL ? args[0]->a_vp->v_cache_dst.tqh_first : 0;
	this->ncp =! NULL ? this->ncp : 0;
	this->ncp->nc_name != NULL ? this->ncp->nc_name : 0;
	self->path = this->ncp != 0 ? (this->ncp->nc_name != 0 ? stringof(this->ncp->nc_name) : "<unknown>") : "-";

	self->kb = args[0]->a_uio->uio_resid / 1024;
	self->start = timestamp;
}

fbt::zfs_freebsd_readdir:entry
{
	this->ncp = &(args[0]->a_vp->v_cache_dst) != NULL ? args[0]->a_vp->v_cache_dst.tqh_first : 0;
	this->ncp =! NULL ? this->ncp : 0;
	this->ncp->nc_name != NULL ? this->ncp->nc_name : 0;
	self->path = this->ncp != 0 ? (this->ncp->nc_name != 0 ? stringof(this->ncp->nc_name) : "<unknown>") : "-";

	self->kb = 0;
	self->start = timestamp;
}

fbt::zfs_freebsd_read:return, fbt::zfs_freebsd_write:return, fbt::zfs_freebsd_readdir:return
/self->start && (timestamp - self->start) >= min_ns/
{
	this->iotime = (timestamp - self->start) / 1000000;
	this->dir = ( probefunc == "zfs_freebsd_read" ? "R" : ( probefunc == "zfs_freebsd_write" ? "W" : "D") );
	printf("%-20Y %-16s %1s %4d %6d %s\n", walltimestamp,
		execname, this->dir, self->kb, this->iotime,
		self->path != NULL ? stringof(self->path) : "<null>");
}

fbt::zfs_freebsd_read:return, fbt::zfs_freebsd_write:return, fbt::zfs_freebsd_readdir:return
{
	self->path = 0; self->kb = 0; self->start = 0;
}
