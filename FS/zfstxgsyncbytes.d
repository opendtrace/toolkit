#!/usr/sbin/dtrace -s 

/* 
 * Originally from the very useful blog post here:
 *   
 * http://dtrace.org/blogs/ahl/2014/08/31/openzfs-tuning/
 *
 * 2015-01-24 Lacey Powers: Tested on FreeBSD 10
 * 
 */


zfs::txg-syncing
{
	this->dp = (dsl_pool_t *)arg0;
}

zfs::txg-syncing
/this->dp->dp_spa->spa_name == $$1/
{
	printf("%4dMB of %4dMB used", this->dp->dp_dirty_total / 1024 / 1024,
					              `zfs_dirty_data_max / 1024 / 1024);
}
