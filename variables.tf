#==============================================================================
#  Variables
#==============================================================================
variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
#==============================================================================
#  S3 Bucket Variables
#==============================================================================
variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
  default     = "website-bucket-1912.qglobal-dev.pearsonassessments.com"
}
#==============================================================================
#  ACM Certificate Variable
#==============================================================================
variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate"
  type        = string
  default     = "arn:aws:acm:us-east-1:189072572552:certificate/c422e8c9-6ac8-4b42-b804-80f736d3cd1d"
}
#==============================================================================
#  CloudFront Variables
#  List the CNAMEs for the CloudFront distribution
#==============================================================================
variable "CNAME" {
  description = "CNAME of the custom domain name"
  type        = list(string)
  default     = ["website-bucket-1912.qglobal-dev.pearsonassessments.com"]
}
#==============================================================================
#  Route53 Variables
#==============================================================================
variable "zone_id" {
  description = "Route53 zone ID"
  type        = string
  default     = null
}
#==============================================================================