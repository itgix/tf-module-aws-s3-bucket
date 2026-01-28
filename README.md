# S3 Bucket Module

Terraform module to provision an S3 bucket with secure defaults and optional features:
- Versioning, ownership controls, encryption (SSE-S3 or SSE-KMS)
- Public access block (private by default)
- Optional server access logging
- Optional lifecycle expiration
- Optional cross-region replication
- Optional S3 static website hosting (public website endpoint)
- Optional CloudFront origin access hook (private bucket)

## Naming Convention

Primary bucket name is generated as:

`<account_name>-<account_id>-<account_environment>-s3-<bucket_purpose>`

Example:

`platform-<account_id>-prod-s3-tf-state`

`account_id` is detected automatically via `aws_caller_identity`.

## Providers

This module uses a replica provider alias for optional cross-region replication. Even if CRR is disabled, it is recommended to pass the alias.

```hcl
provider "aws" {
  region = "eu-central-1"
}

provider "aws" {
  alias  = "replica"
  region = "eu-west-1"
}

module "s3_bucket" {
  source = "..."

  providers = {
    aws         = aws
    aws.replica = aws.replica
  }

  # ...
}
```

## Usage

See `example/s3.tf` for a full configuration with all options.

## Website Modes

### 1) S3 Website Endpoint (Public)

Enable:
- `enable_website_hosting = true`
- `enable_public_read_for_website = true`

This config:
- enables `aws_s3_bucket_website_configuration`
- relaxes public access block enough to allow a public bucket policy
- adds a policy statement allowing `s3:GetObject` publicly

### 2) CloudFront Origin Access Hook (Private)

Enable:
- `enable_cloudfront_origin_access = true`
- set `cloudfront_distribution_arns = ["arn:aws:cloudfront::...:distribution/...."]`

This config:
- keeps bucket private
- adds a bucket policy statement allowing `s3:GetObject` only for CloudFront with matching SourceArn

> If you prefer, you can keep `manage_bucket_policy=false` and manage all policies externally.

## Notes

- S3 bucket names are globally unique; choose `bucket_purpose` accordingly.
- If lifecycle expiration is enabled, the module can also abort incomplete multipart uploads (enabled by default) via:
  - `enable_lifecycle_abort_incomplete_multipart_upload`
  - `lifecycle_abort_incomplete_multipart_upload_days`
- If you enable cross region replication and use SSE-KMS, you must provide both `primary_kms_key_arn` and `replica_kms_key_arn` and ensure your KMS key policies allow the replication role.
