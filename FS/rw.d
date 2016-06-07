#!/usr/sbin/dtrace -s

/*
 * Originally from:
 * 
 * http://dtrace.org/blogs/ahl/2014/08/31/openzfs-tuning/
 * 
 *
 * Copyright (c) 2014, Adam Leventhal
 * All rights reserved.
 * Redistribution and use in source and binary forms, with or without modification, 
 * are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this list of 
 * conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice, this list of 
 * conditions and the following disclaimer in the documentation and/or other materials 
 * provided with the distribution.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. 
 * IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT 
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR 
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER 
 * IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY 
 * WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * 
 * 2015-04-16 Lacey Powers: Updated to work on FreeBSD 10
 *
 * 2015-09-17: Including improvements from baitisj to make it
 * more concise and clear under FreeBSD
 *
 */


#pragma D option quiet
#pragma D option dynvarsize=64m
#pragma D option bufsize=16m
#pragma D option switchrate=10hz

BEGIN
{
        bio_cmd[1]  = "Read";
        bio_cmd[2]  = "Write";
        bio_cmd[4]  = "Delete";
        bio_cmd[8]  = "Getattr";
        bio_cmd[16] = "Flush";
        start       = timestamp;
}

io:::start
/args[0] != NULL && args[1] != NULL/
{
         /* Rather than relying on args[0]->bio_disk->d_geom->name, */
         /*  FreeBSD assigns a unique device_number per device.*/
         /* See man devstat for more information */
         ts[args[1]->device_number, args[0]->bio_pblkno] = timestamp;
}

io:::done
/args[0] != NULL && args[1] != NULL && ts[args[1]->device_number, args[0]->bio_pblkno]/
{
        this->delta = (timestamp - ts[args[1]->device_number, args[0]->bio_pblkno]) / 1000;
        this->name = bio_cmd[args[0]->bio_cmd];

        @q[this->name] = quantize(this->delta);
        @a[this->name] = avg(this->delta);
        @v[this->name] = stddev(this->delta);
        @i[this->name] = count();
        @b[this->name] = sum(args[0]->bio_bcount);

        ts[args[1]->device_number, args[0]->bio_pblkno] = 0;
}

END
{
        printa(@q);

        normalize(@i, (timestamp - start) / 1000000000);
        normalize(@b, (timestamp - start) / 1000000000 * 1024);

        printf("%-30s %11s %11s %11s %11s\n", "", "avg latency", "stddev",
            "iops", "throughput");
        printa("%-30s %@9uus %@9uus %@9u/s %@8uk/s\n", @a, @v, @i, @b);
}
