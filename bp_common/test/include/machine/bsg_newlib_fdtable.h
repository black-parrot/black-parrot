#ifndef BSG_NEWLIB_FDTABLE_H
#define BSG_NEWLIB_FDTABLE_H

#include <errno.h>
#include "lfs.h"

#ifndef BSG_NEWLIB_MAX_FDS
#define BSG_NEWLIB_MAX_FDS 20
#endif

void bsg_newlib_init_fdtable(void);

int bsg_newlib_check_fd(int fd);

int bsg_newlib_reserve_fd(void);

int bsg_newlib_free_fd(int fd);

lfs_file_t *bsg_newlib_get_file(int fd);

#endif // BSG_NEWLIB_FDTABLE_H
