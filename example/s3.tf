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
