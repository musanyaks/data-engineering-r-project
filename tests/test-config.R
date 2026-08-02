context("Configuration")

test_that("load_config returns list", {
  cfg <- load_config("test")
  expect_type(cfg, "list")
  expect_true(length(cfg) > 0)
})

test_that("get_config retrieves nested values", {
  cfg <- list(a = list(b = list(c = 42)))
  expect_equal(get_config(cfg, "a.b.c"), 42)
  expect_equal(get_config(cfg, "a.b.d", "default"), "default")
  expect_null(get_config(cfg, "x.y.z"))
})

test_that("merge_configs deep merges", {
  base <- list(a = 1, b = list(c = 2, d = 3))
  override <- list(b = list(d = 4, e = 5))
  merged <- merge_configs(base, override)
  expect_equal(merged$a, 1)
  expect_equal(merged$b$c, 2)
  expect_equal(merged$b$d, 4)
  expect_equal(merged$b$e, 5)
})