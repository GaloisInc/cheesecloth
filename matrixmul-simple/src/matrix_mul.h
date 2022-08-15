#ifndef __MATRIX_MUL_H__
#define __MATRIX_MUL_H__

#include <stdint.h>
#include <stdlib.h>

// The type we'll use for matrix cells.
#define matrix_cell_t uint64_t

// A heap-allocated matrix data structure of arbitrary dimensions.
typedef struct {
    size_t rows;
    size_t cols;
    matrix_cell_t *cells;
} matrix;

#define IDX(m, row, col)      ((row * m->cols) + col)
#define SET(m, row, col, val) m->cells[IDX(m, row, col)] = val
#define GET(m, row, col)      m->cells[IDX(m, row, col)]

// Conditional support for console output:
#ifdef __GLIBC__
// When building with Glibc, compile in printing support so we can debug
// this application when running it natively.
#include <stdio.h>
#define dprintf(...)          if (1) { printf(__VA_ARGS__); }
#else
// When not building with Glibc, make printing calls no-ops since they
// won't be allowed in our alternative runtime environment.
#define dprintf(...)          if (0) { }
#endif

// Public matrix API:
matrix* new_matrix(size_t rows, size_t cols,
        matrix_cell_t values[rows][cols]);
void pp_matrix(matrix *m);
matrix* mul(matrix *a, matrix *b);
void free_matrix(matrix **m);

#endif
