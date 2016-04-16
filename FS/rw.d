#!/usr/sbin/dtrace -s

/*
 * From:
 *
 * http://dtrace.org/blogs/ahl/2014/08/31/openzfs-tuning/
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
