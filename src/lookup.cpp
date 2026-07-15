// daice_lookup.cpp
#include <Rcpp.h>
using namespace Rcpp;

// [[Rcpp::export]]
NumericVector lookup(NumericVector aice, NumericVector t2m,
                            NumericMatrix grid,
                            double aice_min = 0, double aice_step = 0.01,
                            double t2m_min = -70, double t2m_step = 0.1) {
int n = aice.size();
  int n_aice = grid.nrow();
  int n_t2m  = grid.ncol();
  NumericVector out(n);

  double inv_aice_step = 1.0 / aice_step;
  double inv_t2m_step  = 1.0 / t2m_step;

  const double* g = grid.begin();  // raw pointer, avoids operator() overhead

  for (int k = 0; k < n; k++) {
    double fi = (aice[k] - aice_min) * inv_aice_step;
    double fj = (t2m[k]  - t2m_min)  * inv_t2m_step;

    if (fi < 0) fi = 0; else if (fi > n_aice - 1) fi = n_aice - 1;
    if (fj < 0) fj = 0; else if (fj > n_t2m - 1) fj = n_t2m - 1;

    int i0 = (int) fi;
    int j0 = (int) fj;
    int i1 = (i0 < n_aice - 1) ? i0 + 1 : i0;
    int j1 = (j0 < n_t2m - 1) ? j0 + 1 : j0;

    double di = fi - i0;
    double dj = fj - j0;

    // Direct pointer arithmetic (column-major: index = row + col*nrow)
    double v00 = g[i0 + j0 * n_aice];
    double v10 = g[i1 + j0 * n_aice];
    double v01 = g[i0 + j1 * n_aice];
    double v11 = g[i1 + j1 * n_aice];

    double v0 = v00 + di * (v10 - v00);
    double v1 = v01 + di * (v11 - v01);

    out[k] = v0 + dj * (v1 - v0);
  }

  return out;
}