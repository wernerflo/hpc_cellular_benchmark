#include <time.h>

struct timespec get_time() {
    struct timespec timer; \
	clock_gettime(CLOCK_MONOTONIC, &timer);
	return timer;
}

double measure_time_diff(const struct timespec *timer1, const struct timespec *timer2) {
    return ((timer2->tv_sec * 1.0E+9 + timer2->tv_nsec) - \
			(timer1->tv_sec * 1.0E+9 + timer1->tv_nsec)) / 1.0E+9;
}
