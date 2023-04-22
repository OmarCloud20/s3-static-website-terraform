#==============================================================================
# This Terraform module is used to create an S3 bucket to host a static website
# It will also create a CloudFront distribution to serve the content
# The CloudFront distribution will be configured to use a custom domain name
# The custom domain name will be created using Route53 and ACM
# 4/23/2023 - 1.0.0
# Omar A Omar
#==============================================================================
terraform {
  required_version = ">= 0.12.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.0"
    }
  }
  backend "s3" {}
}

provider "aws" {
  region = var.region
  default_tags {
    tags = var.tags
  }
}
#==============================================================================
# S3 Bucket for hosting the static website
#==============================================================================
resource "aws_s3_bucket" "website" {
  bucket = var.bucket_name
  force_destroy = true
}
#==============================================================================
# S3 Bucket Ownership Controls
#==============================================================================
resource "aws_s3_bucket_ownership_controls" "website" {
  bucket = aws_s3_bucket.website.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
  depends_on = [aws_s3_bucket_acl.website]
}
#==============================================================================
# S3 Bucket Access Control List (ACL)
#==============================================================================
resource "aws_s3_bucket_acl" "website" {
  bucket = aws_s3_bucket.website.id
  acl    = "private"
}
#==============================================================================
# S3 Bucket Public Access Block
#==============================================================================
resource "aws_s3_bucket_public_access_block" "website" {
  bucket                  = aws_s3_bucket.website.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
#==============================================================================
# S3 Bucket Policy to allow CloudFront to access the content
#==============================================================================
resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = templatefile("${path.module}/src/policy/bucket_policy.json", {
    bucket_name     = var.bucket_name
    region          = var.region
    distribution_id = aws_cloudfront_distribution.s3_distribution.id
  })
}
#==============================================================================
# Upload the S3 Static Contents to the S3 Bucket using the S3 Sync Command
#==============================================================================
# Note: Uploading the static website content to the S3 bucket resource "aws_s3_object" without using content_type metadata
# will cause the browser to download the files instead of displaying them as a static site. Defining the content_type metadata
# for each file is not a good idea. Instead, we can use the S3 Sync command to upload the files to the S3 bucket, which will
# automatically set the content_type metadata based on the file extension and will make it more efficient to upload the files.
# The S3 Sync command will run on the local machine and not on the AWS cloud and will always run when the terraform apply command
# is executed. 
# If you don't want to run the S3 Sync command every time the terraform apply command is executed, remove the `trigger` block.
#==============================================================================
resource "null_resource" "website" {

  # trigger when changes is made to the index.html file
  triggers = {
    changes = sha1(file("src/website/index.html"))
  }

  provisioner "local-exec" {
    command = "aws s3 sync ${path.module}/src/website s3://${aws_s3_bucket.website.id} --delete --exclude \"*.terra*\""
  }
  depends_on = [aws_s3_bucket_policy.website]
}
# flag `--delete` will delete any files in the S3 bucket that are not present in the local folder
# flag `--exclude \"*.terra*\"` will exclude any terraform files from being uploaded to the S3 bucket
#==============================================================================
# Create a local variable to use in the CloudFront distribution
#==============================================================================
locals {
  s3_origin_id = "S3-${aws_s3_bucket.website.id}"
}
#==============================================================================
# CloudFront Origin Access Identity
#==============================================================================
resource "aws_cloudfront_origin_access_identity" "website" {
  comment = "CloudFront Origin Access Identity for ${var.bucket_name}"
}
#==============================================================================
# CloudFront Cache Policy
#==============================================================================
data "aws_cloudfront_cache_policy" "website" {
  name = "Managed-CachingOptimized"
}
#==============================================================================
# CloudFront 
#=============================================================================
resource "aws_cloudfront_origin_access_control" "website" {
  name                              = var.bucket_name
  description                       = "CloudFront Origin Access Control for ${var.bucket_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
#==============================================================================
# CloudFront distribution to serve the content
#==============================================================================
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = "${aws_s3_bucket.website.bucket}.s3.${var.region}.amazonaws.com"
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id
    origin_id                = local.s3_origin_id
    connection_attempts      = 3
    connection_timeout       = 10
  }
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront distribution for ${var.bucket_name}"
  default_root_object = "index.html"
  aliases             = var.CNAME
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = false
    target_origin_id       = local.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id        = data.aws_cloudfront_cache_policy.website.id
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    acm_certificate_arn            = var.acm_certificate_arn
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = "TLSv1.2_2021"
    cloudfront_default_certificate = false
  }

  # wait_for_deployment is set to false to avoid waiting for the deployment to complete
  wait_for_deployment = false
}
#==============================================================================
# Route53 record to validate the ACM certificate
#==============================================================================
resource "aws_route53_record" "website" {
  name    = var.bucket_name
  type    = "A"
  zone_id = var.zone_id
  
  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
  depends_on = [aws_cloudfront_distribution.s3_distribution]
}
#==============================================================================