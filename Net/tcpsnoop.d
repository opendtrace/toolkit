#!/usr/sbin/dtrace -s
/*
 * tcpsnoop - snoop TCP network packets by process.
 *	Written using DTrace tcp Provider.
 *
 * This analyses TCP network packets and prints the responsible PID plus
 * standard details such as IP address and port. This captures traffic
 * from existing and newly created TCP connections. It can help identify
 * which processes are causing TCP traffic.
 *
 * SEE ALSO: snoop -rS
 *
 * CDDL HEADER START
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License (the "License").
 * You may not use this file except in compliance with the License.
 *
 * You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
 * or http://www.opensolaris.org/os/licensing.
 * See the License for the specific language governing permissions
 * and limitations under the License.
 *
 * When distributing Covered Code, include this CDDL HEADER in each
 * file and include the License file at usr/src/OPENSOLARIS.LICENSE.
 * If applicable, add the following below this CDDL HEADER, with the
 * fields enclosed by brackets "[]" replaced with your own identifying
 * information: Portions Copyright [yyyy] [name of copyright owner]
 *
 * CDDL HEADER END
 */
/*
 * Copyright (c) 2010, Oracle and/or its affiliates. All rights reserved.
 *
 * Portions Copyright 2010 Brendan Gregg
 */

#pragma D option quiet
#pragma D option switchrate=10hz

dtrace:::BEGIN
{
	printf("%6s %6s %15s:%-5s      %15s:%-5s %6s %s\n",
	    "TIME", "PID", "LADDR", "PORT", "RADDR", "PORT", "BYTES", "FLAGS");
}

tcp:::send
{
	this->length = args[2]->ip_plength - args[4]->tcp_offset;
	printf("%6d %6d %15s:%-5d  ->  %15s:%-5d %6d (",
	    timestamp/1000, args[1]->cs_pid, args[2]->ip_saddr,
	    args[4]->tcp_sport, args[2]->ip_daddr, args[4]->tcp_dport,
	    this->length);
}

tcp:::receive
{
	this->length = args[2]->ip_plength - args[4]->tcp_offset;
	printf("%6d %6d %15s:%-5d  <-  %15s:%-5d %6d (",
	    timestamp/1000, args[1]->cs_pid, args[2]->ip_daddr,
	    args[4]->tcp_dport, args[2]->ip_saddr, args[4]->tcp_sport,
	    this->length);
}

tcp:::send,
tcp:::receive
{
	printf("%s", args[4]->tcp_flags & TH_FIN ? "FIN|" : "");
	printf("%s", args[4]->tcp_flags & TH_SYN ? "SYN|" : "");
	printf("%s", args[4]->tcp_flags & TH_RST ? "RST|" : "");
	printf("%s", args[4]->tcp_flags & TH_PUSH ? "PUSH|" : "");
	printf("%s", args[4]->tcp_flags & TH_ACK ? "ACK|" : "");
	printf("%s", args[4]->tcp_flags & TH_URG ? "URG|" : "");
	printf("%s", args[4]->tcp_flags & TH_ECE ? "ECE|" : "");
	printf("%s", args[4]->tcp_flags & TH_CWR ? "CWR|" : "");
	printf("%s", args[4]->tcp_flags == 0 ? "null " : "");
	printf("\b)\n");
}
