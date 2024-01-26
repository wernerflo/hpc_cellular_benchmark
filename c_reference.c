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
typedef cell_state_t line_t[XSIZE];

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


void ca_hash_and_report(line_t *buf, int lines)
{
	uint8_t hash[MD5_DIGEST_LENGTH];
	uint32_t md_len;
	EVP_MD_CTX *ctx = EVP_MD_CTX_new();
	EVP_DigestInit_ex(ctx, EVP_md5(), NULL);

	//ca_clean_ghost_zones(buf, lines);

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

	for (int y = 0;  y < lines;  y++) {
		for (int x = 0;  x < XSIZE;  x++) {
			buf[y][x] = randInt(100) >= 50;
		}
	}
}

int main(){
    line_t *from;
    from = malloc((LINES) * sizeof(*from));
    ca_init_config(from, LINES);
    
    printf("c-matrix:\n");
    for (int y = 0; y < LINES; y++) {
        for (int x = 0; x < XSIZE; x++) {
            printf("%d ", from[y][x]);
        }
        printf("\n");
    }

    ca_hash_and_report(from ,LINES);
    free(from);
    return 0;
}