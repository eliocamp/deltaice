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