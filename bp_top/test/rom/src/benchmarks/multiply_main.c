// See LICENSE for license details.

// *************************************************************************
// multiply filter bencmark
// -------------------------------------------------------------------------
//
// This benchmark tests the software multiply implemenation. The
// input data (and reference data) should be generated using the
// multiply_gendata.pl perl script and dumped to a file named
// dataset1.h

#include "util.h"

#include "multiply.h"

//--------------------------------------------------------------------------
// Input/Reference Data

#include "multiply_dataset.h"

#define PREALLOCATE 0

//--------------------------------------------------------------------------
// Main

int main( int argc, char* argv[] )
{
  int i;
  int results_data[DATA_SIZE];

#if PREALLOCATE
  for (i = 0; i < DATA_SIZE; i++)
  {
    results_data[i] = multiply( input_data1[i], input_data2[i] );
  }
#endif

  for (i = 0; i < DATA_SIZE; i++)
  {
    results_data[i] = multiply( input_data1[i], input_data2[i] );
  }

  // Check the results
  return verify( DATA_SIZE, results_data, verify_data );
}
