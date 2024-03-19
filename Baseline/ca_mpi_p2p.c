/*
 * simulate a cellular automaton with periodic boundaries (torus-like)
 * MPI version using two-sided blocking communication
 *
 * (c) 2016 Steffen Christgau (C99 port, modularization, parallelization)
 * (c) 1996,1997 Peter Sanders, Ingo Boesnach (original source)
 *
 * command line arguments:
 * #1: Number of lines
 * #2: Number of iterations to be simulated
 *
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <mpi.h>

#include "ca_common.h"

/* tags for communication */
#define TAG_SEND_UPPER_BOUND (1)
#define TAG_SEND_LOWER_BOUND (2)

#define TAG_RECV_UPPER_BOUND TAG_SEND_LOWER_BOUND
#define TAG_RECV_LOWER_BOUND TAG_SEND_UPPER_BOUND

/* --------------------- CA simulation -------------------------------- */

/* annealing rule from ChoDro96 page 34
 * the table is used to map the number of nonzero
 * states in the neighborhood to the new state
 */
static const cell_state_t anneal[10] = {0, 0, 0, 0, 1, 0, 1, 1, 1, 1};

/* treat torus like boundary conditions */
static void boundary(line_t *buf, int lines)
{
   for (int y = 0;  y <= lines + 1; y++) {
      /* copy rightmost column to the buffer column 0 */
      buf[y][0] = buf[y][XSIZE];

      /* copy leftmost column to the buffer column XSIZE + 1 */
      buf[y][XSIZE+1] = buf[y][1];
   }

   /* no wrap of upper/lower boundary, since it is done by exchanged ghost zones */
}

/* make one simulation iteration with lines lines.
 * old configuration is in from, new one is written to to.
 */
static void simulate(line_t *from, line_t *to, int lines)
{
	#ifdef _OPENMP
	#pragma omp parallel for
	#endif
	for (int y = 1;  y <= lines;  y++) {
		for (int x = 1;  x <= XSIZE;  x++) {
			to[y][x] = transition(from, x, y);
		}
	}
}

/* --------------------- measurement ---------------------------------- */

int main(int argc, char** argv)
{
	int num_total_lines, num_local_lines, num_skip_lines, its;

	/* init MPI and application */
	MPI_Init(&argc, &argv);

	ca_init(argc, argv, &num_total_lines, &its);

	int num_procs, local_rank;
	MPI_Comm_size(MPI_COMM_WORLD, &num_procs);
	MPI_Comm_rank(MPI_COMM_WORLD, &local_rank);

	ca_mpi_init(num_procs, local_rank, num_total_lines,
		&num_local_lines, &num_skip_lines);

	line_t *from = calloc((num_local_lines + 2), sizeof(*from));
	line_t *to = calloc((num_local_lines + 2), sizeof(*to));

	ca_init_config(from, num_local_lines, num_skip_lines);

	/* actual computation */
	TIME_GET(sim_start);
	for (int i = 0; i < its; i++) {
		MPI_Sendrecv(
			from[1], LINE_SIZE, CA_MPI_CELL_DATATYPE,
			PREV_PROC(local_rank, num_procs), TAG_SEND_UPPER_BOUND,
			from[num_local_lines + 1], LINE_SIZE, CA_MPI_CELL_DATATYPE,
			SUCC_PROC(local_rank, num_procs), TAG_RECV_LOWER_BOUND, MPI_COMM_WORLD,
			MPI_STATUS_IGNORE);

		MPI_Sendrecv(
			from[num_local_lines], LINE_SIZE, CA_MPI_CELL_DATATYPE,
			SUCC_PROC(local_rank, num_procs), TAG_SEND_LOWER_BOUND,
			from[0], LINE_SIZE, CA_MPI_CELL_DATATYPE,
			PREV_PROC(local_rank, num_procs), TAG_RECV_UPPER_BOUND, MPI_COMM_WORLD,
			MPI_STATUS_IGNORE);

		boundary(from, num_local_lines);
		simulate(from, to, num_local_lines);

		line_t *temp = from;
		from = to;
		to = temp;
	}
	TIME_GET(sim_stop);

	ca_mpi_hash_and_report(from, num_local_lines, num_total_lines,
		num_procs, TIME_DIFF(sim_start, sim_stop));

	free(from);
	free(to);

	MPI_Finalize();

	return EXIT_SUCCESS;
}
