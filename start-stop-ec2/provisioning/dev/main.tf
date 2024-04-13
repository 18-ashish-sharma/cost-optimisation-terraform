module "service-resources" {
  source         = "../common"
  env            = var.env
  schedule_expression_start_ec2 = var.schedule_expression_start_ec2
}
