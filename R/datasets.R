source(here::here("R/functions.R"))

cdo_apply <- function(ifile, op, ofile = NULL) {
  rcdo::cdo_operator("apply", params = c("op"), Inf, 1) |>
    rcdo::cdo(
      input = list(ifile),
      params = list(op = op),
      output = ofile
    )
}

CDR_grid <- function() {
  here::here("data/raw/nsidc_grid.txt")
}

CDR <- function() {
  file <- here::here("data/raw/cdr.nc")
  years <- 1981:2025

  if (file.exists(file)) {
    return(file)
  }

  urls <- paste0(
    "https://polarwatch.noaa.gov/erddap/griddap/nsidcG02202v4sh1day.nc?cdr_seaice_conc[(",
    years,
    "-01-01T00:00:00Z):1:(",
    years,
    "-12-31T00:00:00Z)][(4350000.0):1:(-3950000.0)][(-3950000.0):1:(3950000.0)]"
  )

  files <- glue::glue("data/temp/CDR/{years}.nc")
  dir.create(dirname(files[1]), showWarnings = FALSE, recursive = TRUE)

  r <- lapply(seq_along(urls), \(i) {
    curl::multi_download(urls[i], files[i], resume = TRUE)
  })

  files |>
    rcdo::cdo_mergetime() |>
    cdo_chname("cdr_seaice_conc", "aice") |>
    cdo_del29feb() |>
    rcdo::cdo_setgrid(CDR_grid()) |>
    rcdo::cdo_execute(output = file, options = c("-L", "-O"))

  remove(files)
  return(file)
}


ERA5_t2m <- function() {
  temp_era_full <- here::here("data/derived/era5_temp_antarctic.nc")

  if (file.exists(temp_era_full)) {
    return(temp_era_full)
  }

  files <- "/g/data/rt52/era5/single-levels/reanalysis/2t/*/*.nc" |>
    Sys.glob()

  years <- as.numeric(dir_part(files, 1))

  files <- files[years > 1979]

  files |>
    furrr::future_map_chr(
      \(x) {
        x |>
          rcdo::cdo_remapbil(CDR_grid()) |>
          rcdo::cdo_daymean() |>
          rcdo::cdo_execute(cache = TRUE)
      }
    ) |>
    rcdo::cdo_mergetime() |>
    rcdo::cdo_execute(
      output = temp_era_full,
      options = "-O -b f32",
      cache = TRUE
    )
  return(temp_era_full)
}


ERA5_sst <- function() {
  temp_era_full <- here::here("data/derived/era5_sst_antarctic.nc")

  files <- "/g/data/rt52/era5/single-levels/reanalysis/sst/*/*.nc" |>
    Sys.glob()

  years <- as.numeric(dir_part(files, 1))

  files <- files[years > 1979]

  files |>
    furrr::future_map_chr(
      \(x) {
        x |>
          rcdo::cdo_remapbil(CDR_grid()) |>
          rcdo::cdo_daymean() |>
          rcdo::cdo_execute(cache = TRUE)
      }
    ) |>
    rcdo::cdo_mergetime() |>
    rcdo::cdo_execute(
      output = temp_era_full,
      options = "-O -b f32",
      cache = TRUE
    )
  return(temp_era_full)
}

ERA5_t2m_mon <- function() {
  temp_era_full <- here::here("data/derived/era5_temp_antarctic_mon.nc")

  files <- "/g/data/rt52/era5/single-levels/monthly-averaged/2t/*/*.nc" |>
    Sys.glob()

  years <- as.numeric(dir_part(files, 1))

  files <- files[years > 1979]

  files |>
    furrr::future_map_chr(
      \(x) {
        x |>
          rcdo::cdo_remapbil(CDR_grid()) |>
          rcdo::cdo_execute(cache = TRUE)
      }
    ) |>
    rcdo::cdo_mergetime() |>
    rcdo::cdo_execute(
      output = temp_era_full,
      options = "-O -b f32",
      cache = TRUE
    )
  return(temp_era_full)
}

# ERA5 <- function() {
#   file_raw <- here::here("data/raw/era5_ic.nc")
#   file <- here::here("data/derived/era5_ic.nc")

#   if (file.exists(file)) {
#     return(file)
#   }

#   if (!file.exists(file_raw)) {
#     years <- 1981:2023

#     request <- list(
#       dataset_short_name = "reanalysis-era5-single-levels",
#       product_type = "reanalysis",
#       variable = "sea_ice_cover",
#       year = years,
#       month = 1:12,
#       day = 1:31,
#       time = "00:00",
#       data_format = "netcdf",
#       download_format = "unarchived",
#       area = c(-20, 0, -90, 360),
#       target = basename(file_raw)
#     )

#     ecmwfr::wf_request(request, path = dirname(file_raw))
#   }

#   file_raw |>
#     rcdo::cdo_selname("siconc") |>
#     cdo_chname("siconc", "aice") |>
#     remap_cdr() |>
#     cdo_del29feb() |>
#     rcdo::cdo_execute(output = file, options = c("-L", "-O", "-f nc"))

#   system(paste0(
#     "module load nco && ncrename -O -d valid_time,time -v valid_time,time ",
#     file,
#     " ",
#     file
#   ))

#   return(file)
# }

S2_reanalysis <- function() {
  file <- here::here("data/derived/access-s2_reanalylsis.nc")

  if (file.exists(file)) {
    return(file)
  }

  years <- 1981:2023
  grid <- CDR_grid()

  weights <- rcdo::cdo_genbil(
    "/g/data/ux62/access-s2/reanalysis/ice/aice/di_aice_1981.nc",
    grid
  ) |>
    rcdo::cdo_execute(options = "-L")

  out <- furrr::future_map_chr(years, \(year) {
    file <- file.path("data", "temp", paste0("s2-reanalys_", year, ".nc"))
    if (file.exists(file)) {
      return(file)
    }
    paste0(
      "/g/data/ux62/access-s2/reanalysis/ice/aice/di_aice_",
      year,
      ".nc"
    ) |>
      rcdo::cdo_remap(grid = grid, weights = weights) |>
      cdo_del29feb() |>
      rcdo::cdo_execute(output = file, options = "-L")
  })

  out |>
    rcdo::cdo_mergetime() |>
    rcdo::cdo_execute(output = file, options = "-L")
}

hindcast <- function(forecast_times, model, members = 1:9, variable = "aice") {
  members <- ifelse(
    members == "em",
    members,
    formatC(as.numeric(members), width = 2, flag = "0")
  )

  data <- data.table::CJ(forecast_time = forecast_times, member = members)

  raw_files <- here::here(
    "data/derived/hindcast",
    variable,
    model,
    data$forecast_time,
    paste0(formatC(data$member, width = 2, flag = "0"), ".nc")
  )
  raw_files[file.exists(raw_files)]
}

OSI <- function() {
  years <- 1981:2020
  file <- here::here("data/derived/OSI.nc")

  if (file.exists(file)) {
    return(file)
  }

  dir <- here::here("data/temp/osi/")
  dir.create(dir, FALSE, TRUE)
  requests <- lapply(years, \(year) {
    raw_file <- paste0("OSI_", year, ".zip")

    if (file.exists(here::here(dir, raw_file))) {
      return(NULL)
    }

    list(
      dataset_short_name = "satellite-sea-ice-concentration",
      variable = "all",
      version = "v3",
      sensor = "ssmis",
      origin = "eumetsat_osi_saf",
      region = "southern_hemisphere",
      cdr_type = "cdr",
      temporal_aggregation = "daily",
      year = paste0(year),
      month = c(
        "01",
        "02",
        "03",
        "04",
        "05",
        "06",
        "07",
        "08",
        "09",
        "10",
        "11",
        "12"
      ),
      day = c(
        "01",
        "02",
        "03",
        "04",
        "05",
        "06",
        "07",
        "08",
        "09",
        "10",
        "11",
        "12",
        "13",
        "14",
        "15",
        "16",
        "17",
        "18",
        "19",
        "20",
        "21",
        "22",
        "23",
        "24",
        "25",
        "26",
        "27",
        "28",
        "29",
        "30",
        "31"
      ),
      target = raw_file
    )
  })
  requests <- Filter(Negate(is.null), requests)

  if (length(requests) != 0) {
    res <- ecmwfr::wf_request_batch(
      requests,
      retry = 1,
      workers = 20,
      path = dir
    )
  }

  files_year <- vapply(years, FUN.VALUE = character(1), \(year) {
    in_file <- file.path(dir, paste0("OSI_", year, ".zip"))
    out_file <- file.path(dir, paste0(year, "merged"))

    if (file.exists(out_file)) {
      return(out_file)
    }
    message("Joining year ", year)
    fs <- unzip(in_file, exdir = tempdir())
    dates <- seq(
      as.Date(paste0(year, "-01-01")),
      as.Date(paste0(year, "-12-31")),
      by = "1 day"
    )
    files <- format(dates, "ice_conc_sh_ease2-250_cdr-v3p0_%Y%m%d1200.nc")

    exists <- (files %in% basename(fs))
    missing <- !exists

    if (any(missing)) {
      extras <- fs[1] |>
        rcdo::cdo_setvrange(200, 300) |>
        rcdo::cdo_duplicate(length(dates)) |>
        rcdo::cdo_settaxis(as.character(min(dates)), "12:00:00", "1day") |>
        rcdo::cdo_seltimestep(paste0(which(missing), collapse = ",")) |>
        rcdo::cdo_execute(options = "-L -f nc -s")
    } else {
      extras <- NULL
    }

    as.list(c(extras, fs)) |>
      rcdo::cdo_mergetime() |>
      rcdo::cdo_selname("ice_conc") |>
      cdo_chname("ice_conc", "aice") |>
      rcdo::cdo_settaxis(as.character(min(dates)), "12:00:00", "1day") |>
      cdo_del29feb() |>
      remap_cdr() |>
      rcdo::cdo_execute(options = c("-L -O -s"), output = out_file)
  })

  files_year |>
    rcdo::cdo_mergetime() |>
    rcdo::cdo_divc(100) |>
    rcdo::cdo_execute(output = file, options = c("-L -O"))
}
