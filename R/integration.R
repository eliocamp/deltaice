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


# euler <- function(model, state, time, forcing, dt) {

# }

# times is in days.
evolve_ <- function(
  start,
  model,
  forcing,
  start_time,
  end_time,
  dt,
  method = rk4
) {
  grid <- start[, .(x, y)]
  time <- seq(start_time, end_time, by = dt)
  N <- length(time)

  pb <- utils::txtProgressBar(min = start_time, max = end_time)
  time_out <- time[time == as.integer(time)]

  history <- lapply(time_out, \(t) data.table::copy(grid)[, t := t])

  history[[1]]$aice <- start$aice
  state <- start$aice
  save_index <- 1
  for (t in time[-1]) {
    state <- method(
      model,
      state,
      t,
      forcing,
      dt
    )

    if (t == as.integer(t)) {
      save_index <- save_index + 1
      history[[save_index]]$aice <- state
    }

    if (interactive()) utils::setTxtProgressBar(pb, t)
  }
  close(pb)
  history <- data.table::rbindlist(history)
}


# evolve <- memoise::memoise(evolve_, cache = cachem::cache_disk("data/cache"))
