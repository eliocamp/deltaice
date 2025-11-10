#include <Rcpp.h>
using namespace Rcpp;

// [[Rcpp::export]]
NumericMatrix poly_interactions_cpp(NumericVector x1, NumericVector x2, int degree) {
  int n = x1.size();
  if(n != x2.size()) {
    Rcpp::stop("x1 and x2 must have the same length");
  }
  
  // Calculate total number of columns:
  // 1 (intercept) + degree (x1 terms) + degree (x2 terms) + degree*degree (interactions)
  int total_cols = 1 + degree + degree + degree * degree;
  NumericMatrix result(n, total_cols);
  
  int col_idx = 0;
  
  // Column 1: Intercept
  for(int i = 0; i < n; i++) {
    result(i, col_idx) = 1.0;
  }
  col_idx++;
  
  // Build polynomial matrices for both variables
  NumericMatrix poly1(n, degree);
  NumericMatrix poly2(n, degree);
  
  // Fill polynomial matrices efficiently
  for(int i = 0; i < n; i++) {
    double x1_val = x1[i];
    double x2_val = x2[i];
    double x1_power = x1_val;
    double x2_power = x2_val;
    
    for(int j = 0; j < degree; j++) {
      poly1(i, j) = x1_power;
      poly2(i, j) = x2_power;
      x1_power *= x1_val;
      x2_power *= x2_val;
    }
  }
  
  // Add x1 polynomial terms
  for(int j = 0; j < degree; j++) {
    for(int i = 0; i < n; i++) {
      result(i, col_idx) = poly1(i, j);
    }
    col_idx++;
  }
  
  // Add x2 polynomial terms
  for(int j = 0; j < degree; j++) {
    for(int i = 0; i < n; i++) {
      result(i, col_idx) = poly2(i, j);
    }
    col_idx++;
  }
  
  // Add all interactions (x1^i * x2^j for i,j = 1 to degree)
  for(int j2 = 0; j2 < degree; j2++) {        // x2 powers
    for(int j1 = 0; j1 < degree; j1++) {      // x1 powers
      for(int i = 0; i < n; i++) {
        result(i, col_idx) = poly1(i, j1) * poly2(i, j2);
      }
      col_idx++;
    }
  }
  
  return result;
}