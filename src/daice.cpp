// [[Rcpp::plugins(openmp)]]
#include <Rcpp.h>
#include <cmath>
#include <omp.h>
using namespace Rcpp;

// [[Rcpp::export]]
NumericVector daice(NumericVector ta, NumericVector c, double to = -1.8, 
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



// [[Rcpp::export]]
NumericVector predict_dice(NumericVector x1, NumericVector x2,
                                          NumericVector coefficients,
                                          int nthreads = 0) {
    constexpr int ncol = 16; // (3+1) x (3+1) full tensor product

    if (coefficients.size() != ncol)
        stop("coefficients must have length 16");

    int n = x1.size();
    NumericVector out(n);

    const double* px1 = x1.begin();
    const double* px2 = x2.begin(); // state
    const double* b   = coefficients.begin();
    double* outp = out.begin();

    if (nthreads > 0) omp_set_num_threads(nthreads);

    #pragma omp parallel for schedule(static)
    for (int r = 0; r < n; ++r) {
        double x = px1[r], y = px2[r];

        double px1_[4], px2_[4];
        px1_[0] = px2_[0] = 1.0;
        px1_[1] = x;           px2_[1] = y;
        px1_[2] = px1_[1] * x; px2_[2] = px2_[1] * y;
        px1_[3] = px1_[2] * x; px2_[3] = px2_[2] * y;

        // order: intercept, x1^1..3, x2^1..3, then x1^i:x2^j (x1 varies fastest)
        double s = b[0];
        s += b[1]*px1_[1] + b[2]*px1_[2] + b[3]*px1_[3];
        s += b[4]*px2_[1] + b[5]*px2_[2] + b[6]*px2_[3];
        s += b[7]*px1_[1]*px2_[1] + b[8]*px1_[2]*px2_[1] + b[9]*px1_[3]*px2_[1];
        s += b[10]*px1_[1]*px2_[2] + b[11]*px1_[2]*px2_[2] + b[12]*px1_[3]*px2_[2];
        s += b[13]*px1_[1]*px2_[3] + b[14]*px1_[2]*px2_[3] + b[15]*px1_[3]*px2_[3];

        if ((y >= 1.0 && s > 0.0) || (y <= 0.0 && s < 0.0)) s = 0.0;

        if (s > (1 - y)) {
            s = (1-y);
        } else if (s < -y) {
            s = -y;
        }

        outp[r] = s;
    }

    return out;
}