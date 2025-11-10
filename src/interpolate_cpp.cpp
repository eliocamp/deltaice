#include <Rcpp.h>
using namespace Rcpp;

// [[Rcpp::export]]
NumericVector interpolate_cpp(NumericMatrix value_matrix, 
                             NumericVector time_points,
                             double target_time) {
  int n_locations = value_matrix.nrow();
  int n_times = time_points.size();
  NumericVector result(n_locations);
  
  // Find time interval
  int idx = 0;
  for(int i = 0; i < n_times - 1; i++) {
    if(target_time >= time_points[i] && target_time <= time_points[i+1]) {
      idx = i;
      break;
    }
  }
  
  double weight = (target_time - time_points[idx]) / 
                  (time_points[idx+1] - time_points[idx]);
  
  // Vectorized interpolation
  for(int i = 0; i < n_locations; i++) {
    result[i] = value_matrix(i, idx) + 
                weight * (value_matrix(i, idx+1) - value_matrix(i, idx));
  }
  
  return result;
}