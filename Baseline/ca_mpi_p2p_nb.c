/*
 * simulate a cellular automaton with periodic boundaries (torus-like)
 * MPI version using two-sided non-blocking communication
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
static void simulate(line_t *from, line_t *to, int start_line, int lines)
{
	for (int y = start_line; y < start_line + lines; y++) {
		for (int x = 1; x <= XSIZE; x++) {
			to[y][x] = transition(from, x, y);
		}
	}
}

#ifdef _OPENMP
static void simulate_omp(line_t *from, line_t *to, int start_line, int lines)
{
	#pragma omp parallel for
	for (int y = start_line; y < start_line + lines; y++) {
		for (int x = 1; x <= XSIZE; x++) {
			to[y][x] = transition(from, x, y);
		}
	}
}	
#endif

/* --------------------- measurement ---------------------------------- */

int main(int argc, char** argv)
{
	int num_total_lines, num_local_lines, num_skip_lines, its;
	int num_procs, local_rank;
	line_t *from, *to, *temp;

	/* init MPI and application */
	MPI_Init(&argc, &argv);

	MPI_Comm_size(MPI_COMM_WORLD, &num_procs);
	MPI_Comm_rank(MPI_COMM_WORLD, &local_rank);

	ca_init(argc, argv, &num_total_lines, &its);

	ca_mpi_init(num_procs, local_rank, num_total_lines,
		&num_local_lines, &num_skip_lines);

	from = malloc((num_local_lines + 2) * sizeof(*from));
	to = malloc((num_local_lines + 2) * sizeof(*to));

	ca_init_config(from, num_local_lines, num_skip_lines);

	/* initial exchange */
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

	/* actual computation */
	TIME_GET(sim_start);
	for (int i = 0; i < its; i++) {
		MPI_Request req[4];
		boundary(from, num_local_lines);

		/* prepost matching receive operation (prevent early sender/late receiver) */
		MPI_Irecv(to[0], LINE_SIZE, CA_MPI_CELL_DATATYPE,
				PREV_PROC(local_rank, num_procs), TAG_RECV_UPPER_BOUND, MPI_COMM_WORLD, &req[0]);
		MPI_Irecv(to[num_local_lines + 1], LINE_SIZE, CA_MPI_CELL_DATATYPE,
				SUCC_PROC(local_rank, num_procs), TAG_RECV_LOWER_BOUND, MPI_COMM_WORLD, &req[1]);

		/* compute boundaries */
		simulate(from, to, 1, 1);
		simulate(from, to, num_local_lines, 1);

		MPI_Isend(to[1], LINE_SIZE, CA_MPI_CELL_DATATYPE,
				PREV_PROC(local_rank, num_procs), TAG_SEND_UPPER_BOUND, MPI_COMM_WORLD, &req[2]);
		MPI_Isend(to[num_local_lines], LINE_SIZE, CA_MPI_CELL_DATATYPE,
				SUCC_PROC(local_rank, num_procs), TAG_SEND_LOWER_BOUND, MPI_COMM_WORLD, &req[3]);

		/* simulate inner lines */
		#ifdef _OPENMP
		simulate_omp(from, to, 2, num_local_lines - 1);
		#else
		simulate(from, to, 2, num_local_lines - 1);
		#endif

		temp = from;
		from = to;
		to = temp;

		MPI_Waitall(4, req, MPI_STATUS_IGNORE);
	}
	TIME_GET(sim_stop);


	ca_mpi_hash_and_report(from, num_local_lines, num_total_lines,
		num_procs, TIME_DIFF(sim_start, sim_stop));

	free(from);
	free(to);

	MPI_Finalize();

	return EXIT_SUCCESS;
}
