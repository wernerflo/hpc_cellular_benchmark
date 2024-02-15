#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <assert.h>


#include "openssl/md5.h"
#include "openssl/evp.h"

#include "random.h"
#include "random.c"

#define randInt(n) ((int)(nextRandomLEcuyer() * n))
#define XSIZE 10
#define LINES 10
typedef uint8_t cell_state_t;
typedef cell_state_t line_t[XSIZE+2];
static const cell_state_t anneal[10] = {0, 0, 0, 0, 1, 0, 1, 1, 1, 1};

#define transition(a, x, y) \
   (anneal[(a)[(y)-1][(x)-1] + (a)[(y)][(x)-1] + (a)[(y)+1][(x)-1] +\
           (a)[(y)-1][(x)  ] + (a)[(y)][(x)  ] + (a)[(y)+1][(x)  ] +\
           (a)[(y)-1][(x)+1] + (a)[(y)][(x)+1] + (a)[(y)+1][(x)+1]])


static char* ca_buffer_to_hex_str(const uint8_t* buf, size_t buf_size)
{
  char *retval, *ptr;

  retval = ptr = calloc(MD5_DIGEST_LENGTH * 2 + 1, sizeof(*retval));
  for (size_t i = 0; i < MD5_DIGEST_LENGTH; i++) {
    snprintf(ptr, 3, "%02X", buf[i]);
    ptr += 2;
  }

  return retval;
}

static void ca_print_hash_and_time(const char *hash, const double time)
{
	printf("hash: %s\ttime: %.3f s\n", (hash ? hash : "ERROR"), time);
}


static void ca_clean_ghost_zones(line_t *buf, int lines)
{
	for (int y = 0; y < lines; y++) {
		buf[y][0] = 0;
		buf[y][XSIZE + 1] = 0;
	}
}

void ca_hash_and_report(line_t *buf, int lines)
{
	uint8_t hash[MD5_DIGEST_LENGTH];
	uint32_t md_len;
	EVP_MD_CTX *ctx = EVP_MD_CTX_new();
	EVP_DigestInit_ex(ctx, EVP_md5(), NULL);

	ca_clean_ghost_zones(buf, lines);

	EVP_DigestUpdate(ctx, buf, lines * sizeof(*buf));
	EVP_DigestFinal_ex(ctx, hash, &md_len);

	char* hash_str = ca_buffer_to_hex_str(hash, MD5_DIGEST_LENGTH);
	printf("hash: %s\n", (hash_str ? hash_str : "ERROR"));
	free(hash_str);

	EVP_MD_CTX_free(ctx);
}

void ca_init_config(line_t *buf, int lines)
{
	volatile int scratch;

	initRandomLEcuyer(424243);

	/* let the RNG spin for some rounds (used for distributed initialization) */

	for (int y = 1;  y <= lines;  y++) {
		for (int x = 1;  x <= XSIZE;  x++) {
			buf[y][x] = randInt(100) >= 50;
		}
	}
}


/* treat torus like boundary conditions */
static void boundary(line_t *buf, int lines)
{
   for (int y = 0;  y <= lines + 1; y++) {
      /* copy rightmost column to the buffer column 0 */
      buf[y][0] = buf[y][XSIZE];

      /* copy leftmost column to the buffer column XSIZE + 1 */
      buf[y][XSIZE+1] = buf[y][1];
   }

    for (int x = 0;  x <= XSIZE + 1; x++) {
      /* copy rightmost column to the buffer column 0 */
      buf[0][x] = buf[lines][x];

      /* copy leftmost column to the buffer column XSIZE + 1 */
      buf[lines+1][x] = buf[1][x];
   }
}


static void simulate(line_t *from, line_t *to, int start_line, int lines)
{
	for (int y = start_line; y < start_line + lines; y++) {
		for (int x = 1; x <= XSIZE; x++) {
			to[y][x] = transition(from, x, y);
		}
	}
}


int main(){
    line_t *from, *to, *temp, *result;
    from = malloc((LINES+2) * sizeof(*from));
    to = malloc((LINES+2) * sizeof(*to));
    result = malloc((LINES) * sizeof(*result));
  
    ca_init_config(from, LINES);
    
    printf("c-matrix, init:\n");
    for (int y = 1; y <= LINES; y++) {
        for (int x = 1; x <= XSIZE; x++) {
            printf("%d ", from[y][x]);
        }
        printf("\n");
    }

    for(int i = 0; i<10; i++){
      boundary(from, LINES);

      simulate(from, to, 1, 1);
		  simulate(from, to, LINES, 1);

      simulate(from, to, 2, LINES - 1);

      temp = from;
		  from = to;
		  to = temp;
    }

    printf("c-matrix, nach 10 its:\n");
    for (int y = 1; y <= LINES; y++) {
        for (int x = 1; x <= XSIZE; x++) {
            printf("%d ", from[y][x]);
            result[y-1][x-1] = from[y][x];
        }
        printf("\n");
    }

    ca_hash_and_report(result ,LINES);
    free(from);
    free(to);
    free(result);
    return 0;
}