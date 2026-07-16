// [[Rcpp::plugins(openmp)]]
#include <Rcpp.h>
#include <omp.h>
using namespace Rcpp;

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