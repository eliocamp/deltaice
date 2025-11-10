rk4 <- function(model, state, time, forcing, dt) {
  k1 <- model(state = state, time = time, forcing = forcing)
  k2 <- model(
    state = state + k1 * dt / 2,
    time = time + dt / 2,
    forcing = forcing
  )
  k3 <- model(
    state = state + k2 * dt / 2,
    time = time + dt / 2,
    forcing = forcing
  )
  k4 <- model(state = state + k3 * dt, time = time + dt, forcing = forcing)

  state <- state + (k1 + 2 * k2 + 2 * k3 + k4) * dt / 6

  state
}


evolve_ <- function(
  start,
  model,
  start_time,
  end_time,
  dt,
  method = rk4,
  forcing
) {
  time <- seq(start_time, end_time, by = dt)
  N <- length(time)

  pb <- txtProgressBar(min = 0, max = N - 1)

  grid <- start[, .(lon, lat)]
  history <- lapply(time, \(t) copy(grid)[, time := t])

  history[[1]]$aice <- start$aice
  for (n in seq_len(N - 1)) {
    history[[n + 1]]$aice <- method(
      model,
      history[[n]]$aice,
      time[n],
      forcing,
      dt
    )
    setTxtProgressBar(pb, n)
  }
  close(pb)
  history <- data.table::rbindlist(history)
}

evolve <- memoise::memoise(evolve_, cache = cachem::cache_disk("data/cache"))
