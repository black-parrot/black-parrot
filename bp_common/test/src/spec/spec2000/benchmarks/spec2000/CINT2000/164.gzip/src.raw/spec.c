#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <fcntl.h>
#ifdef TIMING_OUTPUT
#include <time.h>
#include <sys/time.h>
#endif
#include <raw.h>

#include "bp_utils.h"
#include "vdp.h"
#define SPEC_CPU2000
#define SPEC_GZIP

#define  IM_SPEC_ALREADY

#define TO_HEX(i) (i <= 9 ? '0' + i : 'A' - 10 + i)

#ifdef SPEC_GZIP
#include "gzip.h"
int  get_method   (int in);
#endif

void spec_initbufs();
void spec_compress(int in, int out, int level);
void spec_uncompress(int in, int out, int level);

#define DEBUG

#ifdef DEBUG
int dbglvl=4;
#define debug(level,str)           { if (level<dbglvl) printf(str); }
#define debug1(level,str, a)       { if (level<dbglvl) printf(str, a); }
#define debug2(level,str, a, b)    { if (level<dbglvl) printf(str, a,b); }
#define debug3(level,str, a, b, c) { if (level<dbglvl) printf(str,a,b,c); }
#else
#define debug(level,str)           
#define debug1(level,str, a)       
#define debug2(level,str, a, b)    
#define debug3(level,str, a, b, c) 
#endif

#define FUDGE_BUF (100*1024)
#define VALIDATE_SKIP 1027
#define MAX_SPEC_FD 3
struct spec_fd_t {
    int limit;
    int len;
    int pos;
    unsigned char *buf;
} spec_fd[MAX_SPEC_FD];

long int seedi;
double ran()
/* See "Random Number Generators: Good Ones Are Hard To Find", */
/*     Park & Miller, CACM 31#10 October 1988 pages 1192-1201. */
/***********************************************************/
/* THIS IMPLEMENTATION REQUIRES AT LEAST 32 BIT INTEGERS ! */
/***********************************************************/
#define _A_MULTIPLIER  16807L
#define _M_MODULUS     2147483647L /* (2**31)-1 */
#define _Q_QUOTIENT    127773L     /* 2147483647 / 16807 */
#define _R_REMAINDER   2836L       /* 2147483647 % 16807 */
{
	long lo;
	long hi;
	long test;

	hi = seedi / _Q_QUOTIENT;
	lo = seedi % _Q_QUOTIENT;
	test = _A_MULTIPLIER * lo - _R_REMAINDER * hi;
	if (test > 0) {
		seedi = test;
	} else {
		seedi = test + _M_MODULUS;
	}
	return ( (float) seedi / _M_MODULUS);
}


int spec_init () {
    int i, j;
    //    debug(3,"spec_init\n");

    /* Clear the spec_fd structure */

    /* Allocate some large chunks of memory, we can tune this later */
    for (i = 0; i < MAX_SPEC_FD; i++) {
	int limit = spec_fd[i].limit;
	memset(&spec_fd[i], 0, sizeof(*spec_fd));
	spec_fd[i].limit = limit;
	spec_fd[i].buf = (unsigned char *)malloc(limit+FUDGE_BUF);
	if (spec_fd[i].buf == NULL) {
	    printf ("spec_init: Error mallocing memory!\n");
	    exit(1);
	}
	for (j = 0; j < limit; j+=1024) {
	    spec_fd[i].buf[j] = 0;
	}
    }
    return 0;
}

int spec_random_load (int fd) {
    /* Now fill up the first chunk with random data, if this data is truly
       random then we will not get much of a boost out of it */
#define RANDOM_CHUNK_SIZE (128*1024)
#define RANDOM_CHUNKS     (32)
    /* First get some "chunks" of random data, because the gzip
	algorithms do not look past 32K */
    int i, j;
    char random_text[RANDOM_CHUNKS][RANDOM_CHUNK_SIZE];

    debug(4,"Creating Chunks\n");
    for (i = 0; i < RANDOM_CHUNKS; i++) {
	debug1(5,"Creating Chunk %d\n", i);
	for (j = 0; j < RANDOM_CHUNK_SIZE; j++) {
	    random_text[i][j] = (int)(ran()*256);
	}
    }

    debug(4,"Filling input file\n");
    /* Now populate the input "file" with random chunks */
    for (i = 0 ; i < spec_fd[fd].limit; i+= RANDOM_CHUNK_SIZE) {
	memcpy(spec_fd[fd].buf + i, random_text[(int)(ran()*RANDOM_CHUNKS)],
		RANDOM_CHUNK_SIZE);
    }
    /* TODO-REMOVE: Pretend we only did 1M */
    spec_fd[fd].len = 1024*1024;
    return 0;
}

int spec_load (int num, char *filename, int size) {
  //#define FILE_CHUNK (128*1024)
  int FILE_CHUNK = (size < (128*1024)) ? size : (128*1024);
    int fd, rc, i;
#ifndef O_BINARY
#define O_BINARY 0
#endif
    fd = open(filename, O_RDONLY|O_BINARY);
    if (fd < 0) {
	fprintf(stderr, "Can't open file %s: %s\n", filename, strerror(errno));
	exit (1);
    }
    spec_fd[num].pos = spec_fd[num].len = 0;
    for (i = 0 ; i < size; i+= rc) {
	rc = read(fd, spec_fd[num].buf+i, FILE_CHUNK);
	if (rc == 0) break;
	if (rc < 0) {
	    fprintf(stderr, "Error reading from %s: %s\n", filename, strerror(errno));
	    exit (1);
	}
	spec_fd[num].len += rc;
    }
    close(fd);
    //debug1(2,"spec_fd[num].len  %d bytes\n", spec_fd[num].len);
    //debug1(2,"size %d bytes\n", size);
    while (spec_fd[num].len < size) {
	int tmp = size - spec_fd[num].len;
	if (tmp > spec_fd[num].len) tmp = spec_fd[num].len;
  //	debug1(3,"Duplicating %d bytes\n", tmp);
	memcpy(spec_fd[num].buf+spec_fd[num].len, spec_fd[num].buf, tmp);
	spec_fd[num].len += tmp;
    }
    return 0;
}

int spec_read (int fd, unsigned char *buf, int size) {
    int rc = 0;
    debug3(4,"spec_read: %d, %x, %d = ", fd, buf, size);
    if (fd > MAX_SPEC_FD) {
	fprintf(stderr, "spec_read: fd=%d, > MAX_SPEC_FD!\n", fd);
	exit (1);
    }
    if (spec_fd[fd].pos >= spec_fd[fd].len) {
	debug(4,"EOF\n");
	return EOF;
    }
    if (spec_fd[fd].pos + size >= spec_fd[fd].len) {
	rc = spec_fd[fd].len - spec_fd[fd].pos;
    } else {
	rc = size;
    }
    memcpy(buf, &(spec_fd[fd].buf[spec_fd[fd].pos]), rc);
    spec_fd[fd].pos += rc;
    debug1(4,"%d\n", rc);
    return rc;
}
int spec_getc (int fd) {
    int rc = 0;
    debug1(4,"spec_getc: %d = ", fd);
    if (fd > MAX_SPEC_FD) {
	fprintf(stderr, "spec_read: fd=%d, > MAX_SPEC_FD!\n", fd);
	exit (1);
    }
    if (spec_fd[fd].pos >= spec_fd[fd].len) {
	debug(4,"EOF\n");
	return EOF;
    }
    rc = spec_fd[fd].buf[spec_fd[fd].pos++];
    debug1(4,"%d\n", rc);
    return rc;
}
int spec_ungetc (unsigned char ch, int fd) {
    int rc = 0;
    debug1(4,"spec_ungetc: %d = ", fd);
    if (fd > MAX_SPEC_FD) {
	fprintf(stderr, "spec_read: fd=%d, > MAX_SPEC_FD!\n", fd);
	exit (1);
    }
    if (spec_fd[fd].pos <= 0) {
	fprintf(stderr, "spec_ungetc: pos %d <= 0\n", spec_fd[fd].pos);
	exit (1);
    }
    if (spec_fd[fd].buf[--spec_fd[fd].pos] != ch) {
	fprintf(stderr, "spec_ungetc: can't unget something that wasn't what was in the buffer!\n");
	exit (1);
    }
    debug1(4,"%d\n", rc);
    return ch;
}
int spec_rewind(int fd) {
    spec_fd[fd].pos = 0;
    return 0;
}
int spec_reset(int fd) {
    memset(spec_fd[fd].buf, 0, spec_fd[fd].len);
    spec_fd[fd].pos = spec_fd[fd].len = 0;
    return 0;
}

int spec_write(int fd, unsigned char *buf, int size) {
    debug3(4,"spec_write: %d, %x, %d = ", fd, buf, size);
    if (fd > MAX_SPEC_FD) {
	fprintf(stderr, "spec_write: fd=%d, > MAX_SPEC_FD!\n", fd);
	exit (1);
    }
    memcpy(&(spec_fd[fd].buf[spec_fd[fd].pos]), buf, size); 
    spec_fd[fd].len += size;
    spec_fd[fd].pos += size;
    debug1(4,"%d\n", size);
    return size;
}
int spec_putc(unsigned char ch, int fd) {
    debug2(4,"spec_putc: %d, %d = ", ch, fd);
    if (fd > MAX_SPEC_FD) {
	fprintf(stderr, "spec_write: fd=%d, > MAX_SPEC_FD!\n", fd);
	exit (1);
    }
    spec_fd[fd].buf[spec_fd[fd].pos++] = ch;
    spec_fd[fd].len ++;
    return ch;
}

#define MB (1024*1024)
#ifdef SPEC_CPU2000
int main (int argc, char *argv[]) {
    int i,j, fd, level;
    int input_size=64, compressed_size;
    char *input_name="input.combined";
    unsigned char *validate_array;

    timebegin();

    seedi = 10;

    if (argc > 1) input_name=argv[1];
    if (argc > 2) input_size=atoi(argv[2]);
    if (argc > 3) 
      compressed_size=atoi(argv[3]);
    else
      compressed_size=input_size;

    spec_fd[0].limit=input_size*MB;
    spec_fd[1].limit=compressed_size*MB;
    spec_fd[2].limit=input_size*MB;
    spec_init();


    spec_load(0, input_name, input_size*MB);

    spec_initbufs();
    //for (level=1; level <= 9; level += 2) {
    level = 1;

    spec_compress(0,1, level);

  //zipline- cceip code-hardware gzip
  /*
  uint64_t mstatus_val = 0x0000000000000008;
  uint64_t mie_val = 0x0000000000000800;
  __asm__ volatile("csrw mstatus, %0":: "rK"(mstatus_val));
  __asm__ volatile("csrw mie, %0":: "rK"(mie_val));
   
  struct Zipline_CSR zipline_csr;

  struct dma_cfg dma_tlv_header [5];
  uint64_t tlv_headers [14];

  //rqe
  tlv_headers[0] = 0x400000000a000400;
  tlv_headers[1] = 0x0000000000000000;
  dma_tlv_header[0].data_ptr = tlv_headers;
  dma_tlv_header[0].length = 2;
  dma_tlv_header[0].type = 0;

  
  //cmd
  tlv_headers[2] = 0x800000000a000601;
  tlv_headers[3] = 0x000000000780b000;
  tlv_headers[4] = 0x3a00000000200d42; //xp10:0x3a00000000200654;
  dma_tlv_header[1].data_ptr = tlv_headers+2;
  dma_tlv_header[1].length = 3;
  dma_tlv_header[1].type = 1;
  

  //frmd 
  tlv_headers[5] = 0xc00000000a00020b;
  dma_tlv_header[2].data_ptr = tlv_headers+5;
  dma_tlv_header[2].length = 1;
  dma_tlv_header[2].type = 2;

  //data
  tlv_headers[6]  = 0xa00000000a000005;
  dma_tlv_header[3].data_ptr = tlv_headers+6;
  dma_tlv_header[3].length = 1;
  dma_tlv_header[3].type = 3;
  dma_tlv_header[3].part = 1;

  
  dma_tlv_header[4].data_ptr = (uint64_t *) spec_fd[0].buf;
  dma_tlv_header[4].length = input_size*MB/8;//input_size/8; //input_size*MB/8;
  dma_tlv_header[4].type = 3;
  dma_tlv_header[4].part = 2;

  //cqe
  tlv_headers[7] = 0x800000000a000409;
  tlv_headers[8] = 0x0000000000000000;
  dma_tlv_header[5].data_ptr = tlv_headers+7;
  dma_tlv_header[5].length = 2;
  dma_tlv_header[5].type = 4;
 
  
    
  //type:1, streaming
  zipline_csr.input_ptr = dma_tlv_header;
  zipline_csr.resp_ptr =  (uint64_t *) spec_fd[1].buf;
  uint64_t tlv_num;//, comp_size;
    
      
  tlv_num = bp_call_zipline_accelerator(1, zipline_csr, 6);
  */        

  /*
  comp_size = (tlv_num-1) * 8;
    
  int j=0;
  for(i = 0; i < 16;++i)
    bp_cprint(TO_HEX((uint8_t)((comp_size>>i*4) & 0x0F)));
    
  bp_cprint(10);

  for(j=0; j < tlv_num; j++)
    for(i = 0; i < 16;++i)     
      bp_cprint(TO_HEX((uint8_t)((spec_fd[1].buf[j]>>i*4) & 0x0F)));
  
  */

  /*      bp_finish(0);
          __asm__ volatile("fence": : :); */
  //software compress


  timeend();

    return 0;
}

#if defined(SPEC_BZIP)
extern unsigned char smallMode;
extern int     verbosity;
extern FILE*  bsStream;
extern int     workFactor, blockSize100k;
void spec_initbufs() {
   smallMode               = 0;
   verbosity               = 0;
   blockSize100k           = 9;
   bsStream                = NULL;
   workFactor              = 30;
   allocateCompressStructures();
}
void spec_compress(int in, int out, int lev) {
    blockSize100k           = lev;
    compressStream ( in, out );
}
void spec_uncompress(int in, int out, int lev) {
    blockSize100k           = 0;
    uncompressStream( in, out );
}
#elif defined(SPEC_GZIP)
extern int method;/* compression method */
extern int no_name;     /* don't save or restore the original file name */
extern int no_time;     /* don't save or restore the original file time */
extern int save_orig_name;   /* set if original name must be saved */
extern long time_stamp;      /* original time stamp (modification time) */
extern long ifile_size;      /* input file size, -1 for devices (debug only) */
extern long time_stamp;      /* original time stamp (modification time) */
extern int to_stdout;    /* output to stdout (-c) */
extern int part_nb;          /* number of parts in .gz file */
extern int  ifd;                  /* input file descriptor */
extern int  ofd;                  /* output file descriptor */
extern int level;        /* compression level */

void spec_initbufs() {
    /* These set up some state for gzip */
    no_name=0;
    no_time=0;
    time_stamp=0;
    save_orig_name=0;
    ifile_size = -1L;
    to_stdout = 1;

}
void spec_compress(int in, int out, int lev) {
    level=lev;
    part_nb=0;
    clear_bufs();
    ifd=in; ofd=out;
    zip(ifd,ofd);
}
void spec_uncompress(int in, int out, int lev) {
    level=lev;
    part_nb=0;
    clear_bufs();
    ifd=in; ofd=out;
    method = get_method(1);
    unzip(ifd,ofd);
}

#else
#error You must have SPEC_BZIP or SPEC_GZIP defined!
#endif

int debug_time () {
#ifdef TIMING_OUTPUT
    static int last = 0;
    struct timeval tv;
    gettimeofday(&tv,NULL);
    debug2(2, "Time: %10d, %10d\n", tv.tv_sec, tv.tv_sec-last);
    last = tv.tv_sec;
#endif
    return 0;
}
#endif
