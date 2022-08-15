
#include <stdlib.h>
#include <string.h>

#include "matrix_mul.h"

// Set the row from the values in the specified array, which must have
// size equal to the matrix width.
static void set_row(matrix *m, size_t row, matrix_cell_t *values)
{
    for (size_t i = 0; i < m->cols; i++) {
        SET(m, row, i, values[i]);
    }
}

static void zero_matrix(matrix *m)
{
    size_t sz = m->rows * m->cols * sizeof(matrix_cell_t);
    memset(m->cells, 0, sz);
}

// Allocate and optionally initialize a new matrix. The matrix is zero'd
// and then populated from 'values' if the values pointer is provided.
//
// Returns NULL if either height or width is zero.
matrix* new_matrix(size_t rows, size_t cols,
        matrix_cell_t values[rows][cols])
{
    if (rows == 0 || cols == 0) {
        return NULL;
    }

    matrix *m = malloc(sizeof(matrix));

    m->rows = rows;
    m->cols = cols;

    size_t sz = rows * cols * sizeof(matrix_cell_t);
    m->cells = malloc(sz);

    zero_matrix(m);

    if (values) {
        for (size_t i = 0; i < m->rows; i++) {
            set_row(m, i, values[i]);
        }
    }

    return m;
}

// Pretty-print a matrix.
void pp_matrix(matrix *m)
{
    for (size_t i = 0; i < m->rows; i++) {
        for (size_t j = 0; j < m->cols; j++) {
            dprintf("%5lu ", GET(m, i, j));
        }
        dprintf("\n");
    }
    dprintf("\n");
}

// Compute and return the dot product of the specified row from the
// first matrix and the specified column of the second matrix. Assumes
// that the first matrix's width is the same as the second matrix's
// height.
static matrix_cell_t dot_product(matrix *a, size_t row, matrix *b, size_t col)
{
    matrix_cell_t result = 0;

    for (size_t i = 0; i < a->cols; i++) {
        result += (GET(a, row, i) * GET(b, i, col));
    }

    return result;
}

// Multiply two matrices.
//
// Returns NULL if the matrices cannot be multiplied due to a mismatch
// in dimensions. Otherwise this allocates a new matrix of the
// appropriate size and populates it from the multiplication of the
// specified matrices.
matrix* mul(matrix *a, matrix *b)
{
    if (!a || !b || (b->rows != a->cols)) {
        return NULL;
    }

    matrix *m = new_matrix(a->rows, b->cols, NULL);

    for (size_t i = 0; i < a->rows; i++) {
        for (size_t j = 0; j < b->cols; j++) {
            SET(m, i, j, dot_product(a, i, b, j));
        }
    }

    return m;
}

// Deallocates a matrix and sets its pointer to NULL.
void free_matrix(matrix **m)
{
    if (!m || !*m) {
        return;
    }

    free((*m)->cells);
    free(*m);
    *m = NULL;
}
