library(ggplot2)
library(data.table)
library(metR)

dc <- function(t2m, aice, sigma = c(0, 0, 0)) {
  alpha <- 1
  beta <- 1
  t0 <- -1.8

  t2m <- t2m + rnorm(length(t2m), sd = sigma[1])
  flux <- alpha * (t2m - t0) * (1 - aice) + rnorm(length(t2m), sd = sigma[2])

  prop <- flux / (1 + abs(flux))

  dc <- -ifelse(flux > 0, aice * prop, (1 - aice) * prop)

  dc <- dc +
    rnorm(length(t2m), sd = sigma[3])
  dc <- ifelse(aice + dc > 1, 1 - aice, dc)
  dc <- ifelse(aice + dc < 0, -aice, dc)
  dc
}

stochastic <- function(fun, N = 1000) {
  force(fun)
  force(N)
  function(...) {
    val <- sapply(1:N, \(i) fun(...))

    mean <- rowMeans(val)
    sd <- apply(val, 1, sd)

    list(mean = mean, sd = sd)
  }
}


grid_monthly

# adding stochastic component recovers the zero line shape pretty well, but
# it doesn't match the melt going back to zero at aice -> 0 i

grid <- CJ(
  t2m = seq(-15, 1, length.out = 40),
  aice = seq(0, 1, length.out = 40)
) |>
  _[,
    c("daice", "daice_sd") := stochastic(dc, 10000)(
      t2m,
      aice,
      sigma = c(0, 1, 0)
    )
  ]
# _[, daice := dc(t2m, aice, 0)] |>

grid |>
  ggplot(aes(aice, t2m)) +
  geom_contour_filled(aes(z = daice, fill = ..level_mid..)) +
  geom_contour(aes(z = daice), colour = "black", breaks = 0) +
  scale_fill_gradient2()


grid[t2m %~% -5] |>
  ggplot(aes(aice, daice)) +
  geom_line()
