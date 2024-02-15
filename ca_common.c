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
    return ((timer2->tv_sec * 1.0E+9 + timer2->tv_nsec) - \
			(timer1->tv_sec * 1.0E+9 + timer1->tv_nsec)) / 1.0E+9;
}

void ca_init(int argc, char** argv, int *lines, int *its)
{
	assert(argc == 3);

	*lines = atoi(argv[1]);
	*its = atoi(argv[2]);

	assert(*lines > 0);
}


static void ca_clean_ghost_zones(line_t *buf, int lines)
{
	for (int y = 0; y < lines; y++) {
		buf[y][0] = 0;
		buf[y][XSIZE + 1] = 0;
	}
}

