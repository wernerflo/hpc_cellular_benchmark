#ifndef CA_COMMON_H
#define CA_COMMON_H

#include <stdint.h>
#include <stddef.h>
#include <time.h>

#define TIME_GET(timer) \
	struct timespec timer; \
	clock_gettime(CLOCK_MONOTONIC, &timer)

#define TIME_DIFF(timer1, timer2) \
	((timer2.tv_sec * 1.0E+9 + timer2.tv_nsec) - \
	 (timer1.tv_sec * 1.0E+9 + timer1.tv_nsec)) / 1.0E+9

/* horizontal size of the configuration */
#define XSIZE 1024
#define LINE_SIZE (XSIZE + 2)

/* "ADT" State and line of states (plus border) */
typedef uint8_t cell_state_t;
typedef cell_state_t line_t[XSIZE + 2];

void ca_init(int argc, char** argv, int *lines, int *its);
void ca_init_config(line_t *buf, int lines, int skip_lines);
void ca_hash_and_report(line_t *buf, int lines, double time_in_s);

#endif /* CA_COMMON_H */
