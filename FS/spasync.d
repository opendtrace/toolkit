#!/usr/sbin/dtrace -s
/*
 * spasync.d	Trace ZFS spa_sync() with details.
 *
 * From Chap 5 in the DTrace book, and based on spasync.d from Ben, Roch, Matt.
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
 * 2015-02-12 Lacey Powers: Modified to work on FreeBSD
 */

#pragma D option quiet

inline int MIN_MS = 1;

dtrace:::BEGIN
{
	printf("Tracing ZFS spa_sync() slower than %d ms...\n", MIN_MS);
	@bytes = sum(0);
}

fbt::spa_sync:entry
/!self->start/
{
	in_spa_sync = 1;
	self->start = timestamp;
	self->spa = args[0];
}

io:::start
/arg0 && in_spa_sync/
{ 
	/* Check arg0 in the predicate, because if it isn't defined, it causes all kinds of issues. */
	@io = count();
	@bytes = sum(args[0]->bio_bcount);
}

fbt::spa_sync:return
/self->start && (this->ms = (timestamp - self->start) / 1000000) > MIN_MS/
{
	normalize(@bytes, 1048576);
	printf("%-20Y %-10s %6d ms, ", walltimestamp,
	    stringof(self->spa->spa_name), this->ms);
	printa("%@d MB %@d I/O\n", @bytes, @io);
}

fbt::spa_sync:return
{
	self->start = 0; self->spa = 0; in_spa_sync = 0;
	clear(@bytes); clear(@io);
}

