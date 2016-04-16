#!/usr/sbin/dtrace -s

/*
 * From:
 *
 * http://dtrace.org/blogs/ahl/2014/08/31/openzfs-tuning/
 *
 * Only works on FreeBSD 10.3 and later.
 */

#pragma D option aggpack
#pragma D option quiet

fbt::vdev_queue_max_async_writes:entry
{
    self->spa = args[0];
}
fbt::vdev_queue_max_async_writes:return
/self->spa && self->spa->spa_name == $$1/
{
    @ = lquantize(args[1], 0, 30, 1);
}

tick-1s
{
    printa(@);
    clear(@);
}

fbt::vdev_queue_max_async_writes:return
/self->spa/
{
    self->spa = 0;
}
