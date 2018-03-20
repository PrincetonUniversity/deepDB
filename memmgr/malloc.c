#include <stddef.h>
#include <stdio.h>
#include <assert.h>

/* DISCLAIMER: don't use this with unverified clients: malloc doesn't zero
the allocated blocks so clients can trash the free lists. 
A verified client can also trash the size field, owing to transparency
of the definition of malloc_token... 
*/

void *sbrk(size_t nbytes); /* Assume it returns a well aligned pointer */ 


/* About format and alignment:
malloc returns a pointer aligned modulo ALIGN*WORD, preceded by the chunk
size as an unsigned integer in WORD bytes.  Given a well aligned large block
from the operating system, the first (WORD*ALIGN - WORD) bytes are wasted
in order to achieve the alignment.  The chunk size is at least the size
given as argument to malloc.
*/

#define WORD (sizeof(size_t)) 

#define ALIGN 2  

#define WASTE ((WORD*ALIGN) - WORD)  

#define BIGBLOCK ((2<<16)*WORD)

#define BINS 8


/* max data size for blocks in bin b (not counting header),
   assuming 0<=b<BINS */
static size_t bin2size(int b) {
    return ((b+1)*ALIGN - 1)*WORD; 
}

/* bin index for blocks of size s (allowing for header and alignment) */
int size2bin(size_t s) {
  if (s > bin2size(BINS-1))
    return -1;
  else
    return (s+(WORD*(ALIGN-1)-1))/(WORD*ALIGN); 
}

/* Claim 1:  0 <= s <= bin2size(BINS-1)   <==>   s <= bin2size(size2bin(s))
   Claim 2:  0 <= s <= bin2size(BINS-1)   ==>    0 <= size2bin(s) < BINS

   Claim 3:  0 <= s <= bin2size(BINS-1)   ==>   
                            size2bin(bin2size(size2bin(s))) == size2bin(s) 
  
   Claim 4:  0 <= b < BINS  ==>  (bin2size(b)+WORD) % (WORD*ALIGN) == 0
*/

static void testclaim(void) {
  int s,b;

  for (s=0;s<122;s++) {
    b = size2bin(s);
    printf("%3d  %3d  %3zu\n", s, b, bin2size(b));
    assert( s <= bin2size(BINS-1) ? 
            s <= bin2size(size2bin(s)) 
            && size2bin(s) < BINS 
            && size2bin(bin2size(size2bin(s)))==size2bin(s)
            && (bin2size(size2bin(s))+WORD) % (WORD*ALIGN) == 0 
            : 1);
  }
}

/* for 0 <= b < BINS, bin[b] is null or points to 
   the first 'link field' of a list of blocks (sz,lnk,dat) 
   where sz is the length in bytes of (lnk,dat)
   and the link pointers point to lnk field not to sz.
*/
static void *bin[BINS];  /* initially nulls */


void *fill_bin(int b) {
  size_t s = bin2size(b);
  char *p = (char *) sbrk(BIGBLOCK);   
  int Nblocks = (BIGBLOCK-WASTE) / (s+WORD);   
  char *q = p + WASTE; /* align q+WORD, wasting WASTE bytes */  
  int j = 0; 
  while (j != Nblocks - 1) {
      /* q points to start of (sz,lnk,dat), 
         q+WORD (i.e., lnk) is aligned,
         q+s+WORD is allocated, and 
         0 <= j < Nblocks 
      */
    ((size_t *)q)[0] = s;
    *((void **)(((size_t *)q)+1)) = q+WORD+(s+WORD); /* addr of next nxt field */
/* NOTE: the last +WORD was missing in the preceding store, and was found during verification attempt. */
    q += s+WORD; 
    j++; 
  }
  /* finish last block, avoiding expression q+(s+WORD) going out of bounds */
  ((size_t *)q)[0] = s; 
  *((void **)(((size_t *)q)+1)) = NULL; /* lnk of last block */
  return (void*)(p+WASTE+WORD); /* lnk of first block */
}

void *malloc_small(size_t nbytes) {
  int b = size2bin(nbytes);
  void *q;
  void *p = bin[b];
  if (!p) {
    p = fill_bin(b);
    bin[b] = p;
  }
  q = *((void **)p);
  bin[b] = q;
//  assert ((int)p % (WORD*ALIGN) == 0);  
  return p;
}

void free_small(void *p, size_t s) {
  int b = size2bin(s);
  void *q = bin[b];
  *((void **)p) = q;
  bin[b]=p;
}

void free(void *p) {
  if (p != NULL) {
    size_t s = (size_t)(((size_t *)p)[-1]);
    if (s <= bin2size(BINS-1))
      free_small(p,s);
  }
}

void *malloc(size_t nbytes) {
  void* result;
  if (nbytes > bin2size(BINS-1))
    return NULL;
  else 
    return malloc_small(nbytes);
//  assert ((int)result % (WORD*ALIGN) == 0);  
}

int main(void) {
//  testclaim(); 
  void *p = malloc(100);
  void *q = malloc(10);
  void *r = malloc(100);
  void *s = malloc(100);
  free(r);
  free(q);
  r = malloc(100); 
  free(p);
  q = malloc(100);
  free(q);
  free(p);

  return 0;
}