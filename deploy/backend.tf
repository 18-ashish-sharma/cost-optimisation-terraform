# Partial backend configuration: bucket, key and region are supplied at init time so the
# same code works for any account. See backend.hcl.example.
#
#   terraform init -backend-config=backend.hcl
#
# Each Terraform workspace gets its own state object in the same bucket:
#   default   -> s3://<bucket>/<key>
#   dev       -> s3://<bucket>/env:/dev/<key>
terraform {
  backend "s3" {}
}
