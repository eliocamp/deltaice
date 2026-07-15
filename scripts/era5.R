box::use(R / datasets[...])
future::plan("multicore", workers = 7)
ERA5_sst()
ERA5_t2m()

ERA5_t2mdaily()
