#!/usr/sbin/dtrace -Cs

/*
 * Originally from:
 * 
 * https://forums.freebsd.org/threads/sharing-of-dtrace-scripts.32855/
 * 
 */


/* 
 * This script make heavy use of the C preprocessor. Also, since
 * we want to have information on the number of bytes read or
 * write, the entry probes have to be divided into three
 * groups. Otherwise, two groups will suffice. You could add 
 * other similar probes to the list of probes. However, in
 * doing so, you may have to reduce the depth of directory
 * to go up to. Unless you spell everything out instead of
 * macros. 
 */

#pragma D option quiet
#pragma D option defaultargs
#pragma D option switchrate=20hz
#pragma D option bufsize=8m
#pragma D option dynvarsize=32m

/*
 * Refer to man 9 VFS and the files <sys/vnode.h>,
 * </usr/src/sys/kern/vfs_default.c> and various
 * information on vnode in each fs.
 */

/* read and write */

#define ENTRY_PROBES_RW \
vfs::vop_read:entry, vfs::vop_write:entry

/* arg1 has cnp as a member of its struct */

#define ENTRY_PROBES_CNP \
vfs::vop_create:entry, vfs::vop_remove:entry, \
vfs::vop_mkdir:entry, vfs::vop_rmdir:entry

/* others */

#define ENTRY_PROBES_NCNP \
vfs::vop_getattr:entry, vfs::vop_open:entry, \
vfs::vop_close:entry, \
vfs::vop_inactive:entry, vfs::vop_fsync:entry

#define ENTRY_PROBES \
ENTRY_PROBES_RW, ENTRY_PROBES_CNP, ENTRY_PROBES_NCNP

#define GET_DVP(pt) \
this->dvp = pt->nc_dvp != NULL ? \
(&(pt->nc_dvp->v_cache_dst) != NULL ? \
pt->nc_dvp->v_cache_dst.tqh_first : 0) : 0;

#define GET_NCP \
this->ncp = &(args[0]->v_cache_dst) != NULL ? \
args[0]->v_cache_dst.tqh_first : 0;

#define NC_NAME(pt1, pt2) \
pt1 = pt2 != 0 ? (pt2->nc_name != 0 ? \
stringof(pt2->nc_name): "<none>") : "<none>";

#define GET_DIR_NAME(pt) \
ENTRY_PROBES \
/this->dvp && execname != "dtrace" && \
($$1 == NULL || $$1 == execname)/ \
{ \
        GET_DVP(this->dvp); \
        NC_NAME(pt, this->dvp); \
}

/*
 * I have to set the variable to 0. Otherwise, there
 * will be some namespace pollution with erroneous
 * output.
 */

#define PRINT_DIR_NAME(dn) \
ENTRY_PROBES \
/dn != 0 && dn != "<none>" && execname != "dtrace" && \
($$1 == NULL || $$1 == execname) && this->fi_mount != "/dev"/ \
{ \
        printf("%s/", dn); \
	dn = 0; \
}

BEGIN
{
        printf("%-16s %6s %6s %-16.16s %-12s %8s %s\n", "TIMESTAMP", 
	"UID", "PID", "PROCESS", "CALL", "SIZE", "PATH/FILE");
}

/* 
 * All those predicates involving execname != "dtrace" is
 * to prevent erroneous entries of dtrace going into
 * the output file when redirect output to a file. 
 */

ENTRY_PROBES_RW
/execname != "dtrace" && ($$1 == NULL || $$1 == execname)/
{
        this->bytes = args[1]->a_uio->uio_resid;
        this->kbytes = this->bytes / 1024;
        this->mbytes = this->bytes / 1048576;
        this->unit = this->kbytes != 0 ? "K" : 
		(this->mbytes != 0 ? "M" : "B");
        this->number = this->kbytes != 0 ? this->kbytes : 
		(this->mbytes != 0 ? this->mbytes : this->bytes);
}

ENTRY_PROBES_CNP, ENTRY_PROBES_NCNP
/execname != "dtrace" && ($$1 == NULL || $$1 == execname)/
{
        this->unit = "-";
}

/* 
 * Notice that we get file names differently in the following two
 * cases.
 */

ENTRY_PROBES_CNP
/execname != "dtrace" && ($$1 == NULL || $$1 == execname)/
{
	GET_NCP;
        this->fi_mount = args[0]->v_mount ? 
		stringof(args[0]->v_mount->mnt_stat.f_mntonname) : 
			"<none>";
        NC_NAME(this->fi_dirname, this->ncp);
	/* 
	 * From the book DTrace Dynamic Tracing In Oracle 
	 * Solaris, Mac OS X & FreeBSD
	 */
        this->fi_name = args[1]->a_cnp->cn_nameptr != NULL ? 
		stringof(args[1]->a_cnp->cn_nameptr) : "<unknown>";
}

/* 
 * It is good practice to check pointer != NULL before 
 * referring to its members.
 */

ENTRY_PROBES_CNP
/this->ncp && execname != "dtrace" && ($$1 == NULL || $$1 == execname)/
{
        GET_DVP(this->ncp);
        NC_NAME(this->dn1, this->dvp);
}

ENTRY_PROBES_RW, ENTRY_PROBES_NCNP
/execname != "dtrace" && ($$1 == NULL || $$1 == execname)/
{
	/*
	 * Get file name from vnode pointer by Sergey Slobodyanyuk in
	 * freebsd questions mailing list.
 	 * http://docs.freebsd.org/cgi/getmsg.cgi?fetch=58213+0+
	 * archive/2012/freebsd-hackers/20120610.freebsd-hackers
	 */
        GET_NCP;
        this->fi_mount = args[0]->v_mount ? 
		stringof(args[0]->v_mount->mnt_stat.f_mntonname) : 
			"<none>";
        this->fi_name = this->ncp ? (this->ncp->nc_name != 0 ? 
		stringof(this->ncp->nc_name) : "<unknown>") : "<unknown>";
	this->fi_dirname = "<none>";
}

ENTRY_PROBES_RW, ENTRY_PROBES_NCNP
/this->ncp && execname != "dtrace" && ($$1 == NULL || $$1 == execname)/
{
        GET_DVP(this->ncp);
        NC_NAME(this->fi_dirname, this->dvp);
}

ENTRY_PROBES_RW, ENTRY_PROBES_NCNP
/this->dvp && execname != "dtrace" && ($$1 == NULL || $$1 == execname)/
{
        GET_DVP(this->dvp);
        NC_NAME(this->dn1, this->dvp);
}

/*
 * I have to avoid strjoin since dtrace would complain of
 * running out of scratch space pretty fast.
 */

GET_DIR_NAME(this->dn2)
GET_DIR_NAME(this->dn3)
GET_DIR_NAME(this->dn4)
GET_DIR_NAME(this->dn5)

ENTRY_PROBES_RW
/execname != "dtrace" && ($$1 == NULL || $$1 == execname)/
{
	this->mountnm = this->fi_mount != "/" ? this->fi_mount : "\0";
	printf("%-16d %6d %6d %-16.16s %-12s %7d%s %s/", timestamp, uid, 
		pid, execname, probefunc, this->number, this->unit,
                	this->mountnm);
}

ENTRY_PROBES_CNP, ENTRY_PROBES_NCNP
/execname != "dtrace" && ($$1 == NULL || $$1 == execname)/
{
	this->mountnm = this->fi_mount != "/" ? this->fi_mount : "\0";
	printf("%-16d %6d %6d %-16.16s %-12s %8s %s/", timestamp, uid, 
		pid, execname, probefunc, this->unit, this->mountnm);
}

PRINT_DIR_NAME(this->dn5)
PRINT_DIR_NAME(this->dn4)
PRINT_DIR_NAME(this->dn3)
PRINT_DIR_NAME(this->dn2)
PRINT_DIR_NAME(this->dn1)
PRINT_DIR_NAME(this->fi_dirname)

ENTRY_PROBES
/execname != "dtrace" && ($$1 == NULL || $$1 == execname)/
{
	printf("%s\n", this->fi_name);
}
