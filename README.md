## Terraform module for creating S3 Static Website utilizing CloudFront and Route53




![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)

###  Table of Contents
<!-- TOC -->
- [Introduction](#introduction)
- [How does the module work?](#how-does-the-module-work)
- [Prerequisites](#prerequisites)
- [Resources to be created](#resources-to-be-created)
- [How to use the module with Terragrunt](#how-to-use-the-module-with-terragrunt)
- [How to destroy the resources](#how-to-destroy-the-resources)
- [Conclusion](#conclusion)
- [References](#references)
<!-- /TOC -->

---



### Introduction

This Terraform module creates an S3 bucket with a CloudFront distribution and a Route53 A record for the domain name. The S3 bucket is configured to serve static website content via CloudFront distribution only. The S3 bucket is not publicly accessible and the content is only accessible through the CloudFront distribution.
The Route53 A record is configured to point to the CloudFront distribution. 

The module can be downloaded and hosted locally or it can be used directly from GitHub. The module designed to used with [Terragrunt](https://terragrunt.gruntwork.io/) ;however, it can be used with Terraform as well. 

### How does the module work?

The module creates an S3 bucket based on the `bucket_name` input and creates a CloudFront distribution with [an origin access control (OAC)](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html) to restrict access to the S3 bucket. The S3 bucket is not publicly accessible and is not configured as static website hosting. The S3 bucket static contents are only accessible through the CloudFront distribution. it creates a S3 bucket policy to allow CloudFront to access the S3 bucket and a Route53 A record to point to the CloudFront distribution.

It uploads the static website content to the S3 bucket using the `aws s3 sync` command using `local-exec` provisioner to avoid issues with content type and metadata. Note, I tried using `aws_s3_object` resource but it did not work as expected because I had to specify the content type and metadata for each file which is not practical. Therefore, I decided to use the `aws s3 sync` command to upload the content to the S3 bucket which is more practical to use. Moreover, the `aws s3 sync` command is used with the following options:

- `--delete` to delete any files in the S3 bucket that are not present in the local directory. This is useful when you want to remove files from the S3 bucket.
- `exclude` option is to delete terraform generated files from the `website` directory before uploading the content to the S3 bucket.
- The `null_resource` resource is used to trigger the `aws s3 sync` command only when the `index.html` file is changed. This is useful when you want to upload the content to the S3 bucket only when the content is changed.

---


### Prerequisites

1. Terraform >= 0.12.0
2. Terragrunt >= 0.23.0
3. AWS CLI >= 1.16.0
4. AWS account with permissions to create S3 buckets, CloudFront distributions, and Route53 records
5. Current AWS ACM certificate for the domain name
6. Route53 hosted zone for the domain name

---

### Resources to be created

1. S3 bucket for static website content
2. S3 bucket policy to allow CloudFront to access the S3 bucket
3. CloudFront distribution with an origin access control (OAC) to restrict access to the S3 bucket
4. Route53 A record to point to the CloudFront distribution.


---

### How to use the module with Terragrunt 

1. Create a new directory for the environment (e.g. dev, prod, etc.)
2. Create a new directory for the application (e.g. myapp)
3. Create a folder named `src` in the application directory and another folder inside the `src` folder named `website`
4. Copy the static website content into the `website` folder

Note: you can download the sample static website content using the following command:

```bash
sudo curl -o website_sample.zip https://raw.githubusercontent.com/OmarCloud20/s3-static-site-terraform-module/main/website_sample.zip
sudo unzip website_sample.zip
```
Then, copy the content of the `website_sample` folder into the `website` folder.


5. Create a new file named `terragrunt.hcl` in the application directory
6. Copy the following code into the `terragrunt.hcl` file and update the values as needed

```hcl
include {
  path = find_in_parent_folders()
}

terraform {
  source = "git::github.com/OmarCloud20/s3-static-site-terraform-module.git//.?ref=main"
}

inputs = {

  region                = "us-east-1"
  bucket_name           = "bucket.example.com"
  CNAME                 = ["bucket.example.com"]
  acm_certificate_arn   = "arn:aws:acm:us-east-1:012345678901:certificate/c422e8c9-6ac8-4b42-b804-80f736d3cd1d"
  zone_id               = "Z0123456789ABCDEF"

  tags = {
    Environment = "dev"
    product     = "myapp"
  }

}
```

Note: The CNAME value is a custom name that is used in the URLS for the files to be served by the CloudFront distribution. For example, if the domain name is `example.com` and bucket name is `bucket` then the CNAME value must be `bucket.example.com`. A second example, if the domain name is `test.com` and bucket name is `test-folder` then the CNAME value must be `test-folder.test.com`.
To simplify it, name the S3 bucket the same as the CNAME value. 

7. Configure S3 remote state backend in another file named `terragrunt.hcl` in the environment directory

```hcl
remote_state {
  backend = "s3"
  config = {
    bucket         = "terraform-state-bucket"
    key            = "environments/${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
    profile        = "default"
  }
}
```
Note: Terragrunt will automatically merge the configuration from the `terragrunt.hcl` file in the environment directory with the configuration from the `terragrunt.hcl` file in the application directory. Terragrunt will also automatically create the S3 bucket and DynamoDB table if they do not exist; therefore, ensure the name of the S3 bucket is unique. The `profile` option is optional and is used to specify the AWS profile to use.

8. This is an example of a directory structure for a development environment with a single application named `myapp` with a static website. The same structure can be used for the production environment. The final directory structure should look like the following example:

```bash
└── environments
    ├── dev
    │   ├── myapp
    │   │   ├── src
    │   │   │   └── website
    │   │   │       ├── index.html
    │   │   │       └── style.css
    │   │   └── terragrunt.hcl
    │   └── terragrunt.hcl
    └─- prd 
        ├── myapp
        │   ├── src
        │   │   └── website
        │   │       ├── index.html
        │   │       └── style.css
        │   └── terragrunt.hcl
        └── terragrunt.hcl
```
If you would like to create a multi-account setup, you can structure the directory as follows:

```bash
└── environments
    ├── terragrunt.hcl
    ├── dev
    │   ├── myapp
    │   │   ├── src
    │   │   │   └── website
    │   │   │       ├── index.html
    │   │   │       └── style.css
    │   │   └── terragrunt.hcl
    └─- prd
        └── myapp
            ├── src
            │   └── website
            │       ├── index.html
            │       └── style.css
            └── terragrunt.hcl
 
```

Notes: 

- The `terragrunt.hcl` file in the environment directory is used to configure the S3 remote state backend. 
- The `terragrunt.hcl` file in the application directory is used to configure the module. If you decide to use this configuration:
- For using multi-account setup, make sure the IAM role used has the necessary permissions to access the S3 bucket or the S3 bucket has a policy that allows access from the IAM role in the account where the S3 bucket is located.
- For using multi-account setup, Terragrunt will create DynamoDB tables in each account to store the state lock. 
- For using multi-account setup, you may need to add an extra variable to the module to specify the account ID. This is important for the CloudFront distribution to be able to access the S3 bucket. This is not included in the module as it is not required for a single account setup.




9. Run `terragrunt plan` to initialize the working directory and create an execution plan
10. Run `terragrunt apply` to apply the changes required to reach the desired state of the configuration



---


### How to destroy the resources

Run `terraform destroy` to destroy the Terraform-managed infrastructure. Note, the S3 bucket will be forced to be destroyed as the module uses the `force_destroy` option.

---

### Conclusion

In this tutorial, we learned how to create a static website using Terraform and deploy it to an S3 bucket. We also learned how to use the module with Terragrunt. The module is available on this GitHub repository.

I hope you found this tutorial useful. If you have any questions, please feel free to reach out to me on [Twitter](https://twitter.com/Omar_cloud20).


---

### References

* [Terraform: aws_s3_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket)
* [Terraform: aws_route53_record](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record)
* [Terraform: aws_cloudfront_distribution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution)
* [Terraform: aws_cloudfront_origin_access_control](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_origin_access_control)
* [Null Resource](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource)
* [Terraform Provisioner: local-exec](https://developer.hashicorp.com/terraform/language/resources/provisioners/local-exec)