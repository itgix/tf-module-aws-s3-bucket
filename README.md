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

## Usage

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.50"
    }
  }
}

# Primary region provider (example: eu-central-1)
provider "aws" {
  region = "eu-central-1"
}

# Replica region provider alias (example: eu-west-1)
provider "aws" {
  alias  = "replica"
  region = "eu-west-1"
}

# Example: One module showcasing all options.

# - Bucket names are globally unique. Pick a bucket_purpose unique enough for your org.
# - For website endpoint public mode, you MUST allow public read (enable_public_read_for_website=true).
# - For CloudFront OAC mode, keep bucket private and pass distribution ARNs, OR manage bucket policy externally.

module "s3_bucket" {
  source = ".."

  # The module requires a replica provider alias even if replication is disabled.
  providers = {
    aws         = aws
    aws.replica = aws.replica
  }

  # Naming
  account_name        = "platform"
  account_environment = "prod"
  bucket_purpose      = "tf-state" # e.g. tf-state | assets | logs | website

  # Common
  tags = {
    "managed-by" = "terraform"
    "owner"      = "platform"
    "env"        = "prod"
  }

  # Bucket core settings
  enable_versioning     = true
  bucket_owner_enforced = true
  object_lock_enabled   = false
  force_destroy         = false

  # Encryption
  # Option A: SSE-S3 (AES256)
  use_sse_s3_encryption = true

  # Option B: SSE-KMS (uncomment and set the KMS keys)
  # use_sse_s3_encryption = false
  # primary_kms_key_arn   = "arn:aws:kms:eu-central-1:123456789012:key/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

  # Security / Policies
  manage_bucket_policy    = true
  deny_insecure_transport = true
  enforce_tls_1_2_minimum = true

  # Logging
  access_logging_target_bucket   = ""         # set to enable server access logs
  access_logging_prefix          = "AWSLogs/" # default
  enable_partitioned_access_logs = false

  # Lifecycle
  enable_lifecycle_expiration = false
  lifecycle_expiration_days   = 90

  # Replication (Cross-region)
  enable_cross_region_replication = false
  replica_suffix                  = "-replica"
  replication_object_prefix       = "" # empty = replicate all
  replication_storage_class       = "STANDARD"
  replica_role_name               = "s3-replication"

  # If using replication + SSE-KMS:
  # replica_kms_key_arn = "arn:aws:kms:eu-west-1:123456789012:key/yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"

  # Website hosting
  # Variant 1: S3 website endpoint (PUBLIC)
  enable_website_hosting         = false
  website_index_document         = "index.html"
  website_error_document         = "error.html"
  enable_public_read_for_website = false

  # Website hosting
  # Variant 2: CloudFront OAC hook (PRIVATE)
  enable_cloudfront_origin_access = false
  cloudfront_distribution_arns = [
    # "arn:aws:cloudfront::123456789012:distribution/EDFDVBD6EXAMPLE"
  ]
}

output "primary_bucket_name" {
  value = module.s3_bucket.primary_bucket_name
}

output "website_endpoint" {
  value = module.s3_bucket.website_endpoint
}
```
## Notes

- S3 bucket names are globally unique; choose `bucket_purpose` accordingly.
- If lifecycle expiration is enabled, the module can also abort incomplete multipart uploads (enabled by default) via:
    - `enable_lifecycle_abort_incomplete_multipart_upload`
    - `lifecycle_abort_incomplete_multipart_upload_days`
- If you enable cross region replication and use SSE-KMS, you must provide both `primary_kms_key_arn` and `replica_kms_key_arn` and ensure your KMS key policies allow the replication role.
