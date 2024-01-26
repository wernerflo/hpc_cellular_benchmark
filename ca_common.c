#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <assert.h>

#include "openssl/md5.h"
#include "openssl/evp.h"

#include "ca_common.h"
#include "random.h"


/* determine random integer between 0 and n-1 */
#define randInt(n) ((int)(nextRandomLEcuyer() * n))

struct timespec get_time() {
    struct timespec timer; \
	clock_gettime(CLOCK_MONOTONIC, &timer);
	return timer;
}

double measure_time_diff(const struct timespec *timer1, const struct timespec *timer2) {
    return ((timer2->tv_sec * 1.0E+9 + timer2->tv_nsec) -
            (timer1->tv_sec * 1.0E+9 + timer1->tv_nsec)) / 1.0E+9;
}

void ca_init(int argc, char** argv, int *lines, int *its)
{
	assert(argc == 3);

	*lines = atoi(argv[1]);
	*its = atoi(argv[2]);

	assert(*lines > 0);
}

/* random starting configuration 
void ca_init_config(line_t *buf, int lines, int skip_lines)
{
	volatile int scratch;

	initRandomLEcuyer(424243);

	/* let the RNG spin for some rounds (used for distributed initialization) 
	for (int y = 1;  y <= skip_lines;  y++) {
		for (int x = 1;  x <= XSIZE;  x++) {
			scratch = scratch + randInt(100) >= 50;
		}
	}

	for (int y = 1;  y <= lines;  y++) {
		for (int x = 1;  x <= XSIZE;  x++) {
			buf[y][x] = randInt(100) >= 50;
		}
	}
}
*/
/* to delete */
void ca_init_config(line_t *buf, int lines, int skip_lines)
{
	volatile int scratch;

	initRandomLEcuyer(424243);

	/* let the RNG spin for some rounds (used for distributed initialization) */
	for (int y = 1;  y <= skip_lines;  y++) {
		for (int x = 1;  x <= XSIZE;  x++) {
			scratch = scratch + randInt(100) >= 50;
		}
	}

	for (int y = 0;  y < lines;  y++) {
		for (int x = 0;  x < XSIZE-2;  x++) {
			buf[y][x] = randInt(100) >= 50;
		}
	}
}


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

void ca_hash_and_report(line_t *buf, int lines, double time_in_s)
{
	uint8_t hash[MD5_DIGEST_LENGTH];
	uint32_t md_len;
	EVP_MD_CTX *ctx = EVP_MD_CTX_new();
	EVP_DigestInit_ex(ctx, EVP_md5(), NULL);

	ca_clean_ghost_zones(buf, lines);

	EVP_DigestUpdate(ctx, buf, lines * sizeof(*buf));
	EVP_DigestFinal_ex(ctx, hash, &md_len);

	char* hash_str = ca_buffer_to_hex_str(hash, MD5_DIGEST_LENGTH);
	ca_print_hash_and_time(hash_str, time_in_s);
	free(hash_str);

	EVP_MD_CTX_free(ctx);
}
