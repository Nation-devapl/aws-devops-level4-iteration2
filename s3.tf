resource "aws_s3_bucket" "terraform-state" {
bucket = "pontusiam-apl-devops-terraform-state"
tags = {
Team = "APL"
ManagedBy = "terraform"
Environment = local.ec2_name
}
}

resource "aws_s3_bucket_versioning" "devops-terraform-state" {
bucket = aws_s3_bucket.terraform-state.id

versioning_configuration {
status = "Enabled"
}
}
