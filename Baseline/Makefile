BASE_CC=gcc
ACC_CC=pgcc
CUDA_CC=nvcc
MPI_CC=mpicc

COMMON_CFLAGS=-O2
COMMON_LDFLAGS=-lcrypto -lrt

BASE_CFLAGS=-Wall -std=gnu99 -pedantic

OMP_CFLAGS=-fopenmp

MPI_CFLAGS=-DUSE_MPI

C_DEPS=ca_common.c random.c

MPI_TARGETS=ca_mpi_p2p ca_mpi_p2p_nb ca_mpi_p2p_nb_hybrid

TARGETS= $(MPI_TARGETS)

.PHONY: all
all: $(TARGETS)

.PHONY: mpi
mpi: $(MPI_TARGETS)

ca_mpi_p2p: ca_mpi_p2p.c $(C_DEPS)
	$(MPI_CC) $(COMMON_CFLAGS) $(BASE_CFLAGS) $(MPI_CFLAGS) $^ $(COMMON_LDFLAGS) -o $@

ca_mpi_p2p_nb: ca_mpi_p2p_nb.c $(C_DEPS)
	$(MPI_CC) $(COMMON_CFLAGS) $(BASE_CFLAGS) $(MPI_CFLAGS) $^ $(COMMON_LDFLAGS) -o $@

ca_mpi_p2p_nb_hybrid: ca_mpi_p2p_nb.c $(C_DEPS)
	$(MPI_CC) $(COMMON_CFLAGS) $(BASE_CFLAGS) $(MPI_CFLAGS) $(OMP_CFLAGS) $^ $(COMMON_LDFLAGS) -o $@

.PHONY: test

test: $(TARGETS)
	@for ITS in 10 31 57 100; do \
		for LINES in 10 33 47 100; do \
			echo "$$LINES lines, $$ITS iterations"; \
			for BINARY in $^; do printf '%-10s\t' $$BINARY; ./$$BINARY $$LINES $$ITS; done; \
		done \
	done

.PHONY: mpi-test

mpi-test: $(MPI_TARGETS)
	@for ITS in 10 31 57 100; do \
		for LINES in 20 33 47 100; do \
			for NP in 2 3 4; do \
				echo "$$LINES lines, $$ITS iterations, $$NP procs"; \
				for BINARY in ca_seq $^; do \
					printf '%-10s\t' $$BINARY; \
					mpiexec -n $$NP ./$$BINARY $$LINES $$ITS; \
				done \
			done \
		done \
	done

.PHONY: bench

bench: $(TARGETS)
	@for ITS in 128 256 512; do \
		for LINES in 1000 10000 50000; do \
			echo "$$LINES lines, $$ITS iterations"; \
			for BINARY in $^; do printf '%-10s\t' $$BINARY; mpirun ./$$BINARY $$LINES $$ITS; done; \
		done \
	done

.PHONY: clean
	
clean:
	rm -f *.o
	rm -f $(TARGETS)
