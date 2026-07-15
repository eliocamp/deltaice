#include <Rcpp.h>
#include <cmath>
using namespace Rcpp;

/**
 * Smooth (soft) if-else blending two values based on the sign of `x`.
 * 
 * @param x          The discriminant (air_flux in your case)
 * @param pos_val    Value to return when x > 0
 * @param neg_val    Value to return when x < 0
 * @param sharpness  Controls transition width; higher = sharper (try 1.0–100.0)
 */
double soft_ifelse(double x, double pos_val, double neg_val, double sharpness = 10.0) {
    double w = 1.0 / (1.0 + std::exp(-sharpness * x));  // sigmoid ∈ (0, 1)
    return w * pos_val + (1.0 - w) * neg_val;
}



// [[Rcpp::export]]
NumericVector daice_cpp(NumericVector ta, NumericVector c, double to = -1.8, 
   NumericVector tf_a = NumericVector::create(0), double alpha = 1.0,
                 double gamma = 0, double beta_f = 1.0, double beta_m = 1.0, 
                 double beta_m2 = 0.0, double damping_strength = 0.0, 
                 NumericVector t_damping_range = NumericVector::create(-20, 0)) {
  
  int n = ta.size();
  NumericVector result(n);
  int m = tf_a.size();
  double midpoint = t_damping_range[0];
  double r = t_damping_range[1] - t_damping_range[0];
  double zero1 = midpoint - r;
  double zero2 = midpoint + r;
  double max_value = ((midpoint - zero1) * (midpoint - zero2));

  for (int i = 0; i < n; i++) {
    double tf = to;

    for (int p = 0; p < m; p++) {
      tf = tf + tf_a[p] * pow(c[i], p+1);
    }
    double t_dif = ta[i] - tf;
    // t_dif = t_dif / (1.0 + std::abs(t_dif)); 

    double air_flux =  alpha * t_dif * (1.0 - c[i]) ;
    double prop = air_flux / (1.0 + std::abs(air_flux));

    if (air_flux > 0) {
      result[i] = -beta_m*prop*c[i];
    } else {
      result[i] = -beta_f*prop*(1 - c[i]);
    }
    // c[i] -= result[i];
    double extra_flux = gamma * (1 - c[i]);
    prop = extra_flux / (1.0 + std::abs(extra_flux));
  
    result[i] += -beta_m2*prop*c[i];
    double damping_value;
    if (ta[i] < midpoint) {
       damping_value = max_value;
    } else if (ta[i] > zero2) {
      damping_value = 0;
    } else {
      damping_value = (ta[i] - zero1)* (ta[i] - zero2)/max_value;
    }

    result[i] += damping_strength * (c[i] - damping_value);

  }
    return result;
}

