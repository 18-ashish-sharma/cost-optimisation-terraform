locals {
  function_name = join("-", [var.function_name, var.env])
  region        = var.aws_region
}
