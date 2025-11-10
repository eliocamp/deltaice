#include <Rcpp.h>
#include <cmath>
using namespace Rcpp;

// [[Rcpp::export]]
NumericVector daice_cpp(NumericVector ta, NumericVector c, double to = -1.8, double alpha = 1.0,
                 double Fo = 1.0, double beta_f = 1.0, double beta_m = 1.0) {
  
  int n = ta.size();
  NumericVector result(n);
  
  // Soft ifelse
  double sharpness = 5.0;
  auto norm = [sharpness](double x) {
    return (tanh(sharpness * x) + 1.0) / 2.0;
  };

  for (int i = 0; i < n; i++) {
    double air_flux =  alpha * (ta[i] - to) * (1.0 - c[i]);
    double ocean_flux = Fo * c[i] * (1.0 - c[i]);
    
    // Apply normalization to air flux
    air_flux = air_flux * 
      (beta_m * norm(air_flux) * c[i] + beta_f * norm(-air_flux) * (1.0 - c[i]));
    
    result[i] = -air_flux - beta_m * ocean_flux * c[i];
  }
  
  return result;
}