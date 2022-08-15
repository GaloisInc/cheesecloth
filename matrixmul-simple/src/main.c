
#include "matrix_mul.h"
#include "secret_inputs.h"

int main()
{
    matrix *m1 = new_matrix(4, 3, m1_data);
    matrix *m2 = new_matrix(3, 5, m2_data);
    matrix *m3 = mul(m1, m2);

    pp_matrix(m1);
    pp_matrix(m2);
    pp_matrix(m3);

    free_matrix(&m1);
    free_matrix(&m2);
    free_matrix(&m3);

    return 0;
}
