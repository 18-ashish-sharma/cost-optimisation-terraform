module "service-resources" {
  source         = "../common"
  env            = var.env
  schedule_expression_start_rds = var.schedule_expression_start_rds
}
