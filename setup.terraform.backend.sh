#!/bin/sh
echo refreshing backend config for terraform
cat <<EOV > terraform.tfvars
aws_owner = "${MY_USER}"
EOV

# dynamic backend
cat <<EOT > backend.tf
terraform {
  backend "s3" {
    bucket         = "${MY_USER}-apl-devops-terraform-state"
    key            = "devops.school"
    region         = "${AWS_REGION}"
    encrypt        = "true"
    use_lockfile   = "true"
  }
}
EOT
