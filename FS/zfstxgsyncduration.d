#!/usr/sbin/dtrace -s

/* 
 * Originally from the very useful blog post here:
 *   
 * http://dtrace.org/blogs/ahl/2014/08/31/openzfs-tuning/
 *
 * 2015-01-24 Lacey Powers: Tested and works without modification on FreeBSD 10
 * 
 */


txg-syncing
/((dsl_pool_t *)arg0)->dp_spa->spa_name == $$1/
{
        start = timestamp;
}

txg-synced
/start && ((dsl_pool_t *)arg0)->dp_spa->spa_name == $$1/
{
        this->d = timestamp - start;
        printf("sync took %d.%02d seconds", this->d / 1000000000,
            this->d / 10000000 % 100);
}
