/************************************************
 * Block device driver to interface with LittleFS
 ************************************************/

#ifndef LFS_BLOCK_DEVICE_H
#define LFS_BLOCK_DEVICE_H

#include "lfs.h"

// Address of the file system memory
extern uint8_t *lfs_ptr;

int lfs_read(const struct lfs_config *c, lfs_block_t block, lfs_off_t off
        , void *buffer, lfs_size_t size);

int lfs_prog(const struct lfs_config *c, lfs_block_t block, lfs_off_t off
        , const void *buffer, lfs_size_t size);

int lfs_erase(const struct lfs_config *c, lfs_block_t block);

int lfs_sync(const struct lfs_config *c);

#endif
