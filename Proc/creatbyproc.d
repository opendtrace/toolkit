#!/usr/sbin/dtrace -s
/*
 * creatbyproc.d - file creat()s by process name. DTrace OneLiner.
 *
 * This is a DTrace (not exactly) OneLiner from the DTraceToolkit.
 *
 * $Id: creatbyproc.d 3 2007-08-01 10:50:08Z brendan $
 */

/*
 * In libc, the creat() function has become:
 *
 *	creat(const char *path, mode_t mode)
 *	{
 *		return (openat(AT_FDCWD, path, O_WRONLY|O_CREAT|O_TRUNC, mode));
 *	}
 */

inline uint_t AT_FDCWD = 0xffd19553;
inline int CREAT_FLAGS = 0x301;		/* O_WRONLY|O_CREAT|O_TRUNC */

syscall::openat*:entry
/(uint_t)arg0 == AT_FDCWD && arg2 == CREAT_FLAGS/
{ printf("%s %s", execname, copyinstr(arg1)); }
