// [[Rcpp::plugins(openmp)]]
#include <Rcpp.h>
#include <omp.h>
using namespace Rcpp;

// [[Rcpp::export]]
NumericVector interpolate_cpp(NumericMatrix value_matrix,
                               NumericVector time_points,
                               double target_time,
                               int nthreads = 0) {
  int n_locations = value_matrix.nrow();
  int n_times = time_points.size();

  int idx = 0;
  const double* tp = time_points.begin();
  for (int i = 0; i < n_times - 1; i++) {
    if (target_time >= tp[i] && target_time <= tp[i+1]) {
      idx = i;
      break;
    }
  }

  double weight = (target_time - tp[idx]) / (tp[idx+1] - tp[idx]);

  NumericVector result(n_locations);
  double* res = result.begin();
  const double* col0 = value_matrix.begin() + (size_t)idx * n_locations;
  const double* col1 = value_matrix.begin() + (size_t)(idx + 1) * n_locations;

  if (nthreads > 0) omp_set_num_threads(nthreads);

  #pragma omp parallel for schedule(static)
  for (int i = 0; i < n_locations; i++) {
    res[i] = col0[i] + weight * (col1[i] - col0[i]);
  }

  return result;
}