provider "aws" {
  region = var.region
}


terraform {
  backend "s3" {
    bucket = "espanelm-infra-terraform"
    region = "sa-east-1"
    key    = "terraform"
  }
}

resource "aws_s3_bucket" "espanelm-infra" {
  bucket = "espanelm-infra-terraform"
}

resource "aws_s3_bucket" "log_bucket" {
  bucket = "espanelm-website-log"
  acl    = "log-delivery-write"

  tags = {
    Name = var.name_tag
  }
}



resource "aws_s3_bucket" "espanelm" {
  bucket = var.app_bucket_name
  acl    = "public-read"

  tags = {
    Name = var.name_tag
  }

  policy = <<EOF
{
    "Version":"2008-10-17",
    "Statement":[{
    "Sid":"AllowPublicRead",
    "Effect":"Allow",
    "Principal": {"AWS": "*"},
    "Action":["s3:GetObject"],
    "Resource":["arn:aws:s3:::${var.app_bucket_name}/*"]
    }]
}
EOF

  logging {
    target_bucket = "${aws_s3_bucket.log_bucket.id}"
    target_prefix = "log/"
  }

  # error (404) points to index, so that
  # only the spa deals with routing
  website {
    index_document = "index.html"
    error_document = "index.html"
  }
}

# Creates an IAM role with write permissions to
# the s3 bucket
resource "aws_iam_user" "espanelm_deploy" {
  name = "espanelm-deploy"
  path = "/espanelm/"
}

resource "aws_iam_access_key" "espanelm_deploy" {
  user = "${aws_iam_user.espanelm_deploy.name}"
}

resource "aws_iam_user_policy" "espanelm_deploy" {
  name = "espanelm-deploy"
  user = "${aws_iam_user.espanelm_deploy.name}"

  # https://makandracards.com/makandra/42219-amazon-s3-give-a-user-write-access-to-selected-buckets
  # https://stackoverflow.com/a/54739735
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::${var.app_bucket_name}",
                "arn:aws:s3:::${var.app_bucket_name}/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:DeleteObject",
                "s3:GetObject",
                "s3:PutObject"
            ],
            "Resource": [
                "arn:aws:s3:::${var.app_bucket_name}",
                "arn:aws:s3:::${var.app_bucket_name}/*"
            ]
        }
    ]
}
EOF
}

output "espanelm_deploy_user_id" {
  value     = aws_iam_access_key.espanelm_deploy.id
  sensitive = true
}

# run terraform output espanelm_deploy_user_secret to get it
output "espanelm_deploy_user_secret" {
  value     = aws_iam_access_key.espanelm_deploy.secret
  sensitive = true
}
