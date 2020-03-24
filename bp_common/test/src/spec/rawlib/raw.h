#ifndef _RAW_H
#define _RAW_H

#define raw_test_pass_reg(val) \
  bsg_remote_ptr_io_store(IO_X_INDEX, 0, val)
  
#define __MINNESTART__ ()
  
#define __MINNEEND__ ()
   
void timebegin();
void timeend();

#endif // _RAW_H
