The Terraform module is used by the ITGix AWS Landing Zone - https://itgix.com/itgix-landing-zone/

# AWS S3 Bucket Terraform Module

This module creates an S3 bucket with encryption (SSE-S3 or SSE-KMS), versioning, lifecycle policies, access logging, cross-region replication, website hosting, and CloudFront origin access support.

Part of the [ITGix AWS Landing Zone](https://itgix.com/itgix-landing-zone/).

## Resources Created

- S3 bucket with configurable encryption and versioning
- Bucket policy (deny insecure transport, enforce TLS 1.2)
- *(Optional)* Access logging configuration
- *(Optional)* Lifecycle expiration rules
- *(Optional)* Cross-region replication with IAM role
- *(Optional)* Static website hosting
- *(Optional)* CloudFront origin access policy

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `account_name` | Logical account/domain name | `string` | — | yes |
| `account_environment` | Environment name (dev, int, prod) | `string` | — | yes |
| `bucket_purpose` | Purpose of the bucket (e.g. tf-state, assets, logs) | `string` | — | yes |
| `tags` | Tags applied to all resources | `map(string)` | `{}` | no |
| `enable_versioning` | Enable bucket versioning | `bool` | `true` | no |
| `bucket_owner_enforced` | Enable BucketOwnerEnforced object ownership | `bool` | `true` | no |
| `object_lock_enabled` | Enable S3 Object Lock | `bool` | `false` | no |
| `force_destroy` | Allow Terraform to delete buckets with objects | `bool` | `false` | no |
| `use_sse_s3_encryption` | If true, use SSE-S3 (AES256). If false, use SSE-KMS | `bool` | `true` | no |
| `primary_kms_key_arn` | KMS key ARN for primary bucket (required when SSE-KMS) | `string` | `null` | no |
| `replica_kms_key_arn` | KMS key ARN for replica bucket | `string` | `null` | no |
| `manage_bucket_policy` | Whether module manages bucket policies | `bool` | `true` | no |
| `deny_insecure_transport` | Deny non-HTTPS requests | `bool` | `true` | no |
| `enforce_tls_1_2_minimum` | Deny TLS versions lower than 1.2 | `bool` | `true` | no |
| `access_logging_target_bucket` | S3 bucket for access logs (empty disables) | `string` | `""` | no |
| `access_logging_prefix` | Prefix for access logs | `string` | `"AWSLogs/"` | no |
| `enable_partitioned_access_logs` | Enable EventTime partitioning for access logs | `bool` | `false` | no |
| `enable_lifecycle_expiration` | Enable lifecycle expiration | `bool` | `false` | no |
| `lifecycle_expiration_days` | Days after which objects expire | `number` | `90` | no |
| `enable_lifecycle_abort_incomplete_multipart_upload` | Abort incomplete multipart uploads | `bool` | `true` | no |
| `lifecycle_abort_incomplete_multipart_upload_days` | Days to abort incomplete multipart uploads | `number` | `7` | no |
| `enable_cross_region_replication` | Enable S3 cross-region replication | `bool` | `false` | no |
| `replica_suffix` | Suffix for the replica bucket name | `string` | `"-replica"` | no |
| `replication_object_prefix` | Only replicate objects with this prefix | `string` | `""` | no |
| `replication_storage_class` | Storage class for replicated objects | `string` | `"STANDARD"` | no |
| `replica_role_name` | IAM role name for S3 replication | `string` | `"s3-replication"` | no |
| `enable_website_hosting` | Enable S3 static website hosting | `bool` | `false` | no |
| `website_index_document` | Index document for website hosting | `string` | `"index.html"` | no |
| `website_error_document` | Error document for website hosting | `string` | `"error.html"` | no |
| `enable_public_read_for_website` | Allow public s3:GetObject | `bool` | `false` | no |
| `enable_cloudfront_origin_access` | Enable CloudFront origin access (keep bucket private) | `bool` | `false` | no |
| `cloudfront_distribution_arns` | CloudFront distribution ARNs allowed to read from this bucket | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| `primary_bucket_name` | Name of the primary bucket |
| `primary_bucket_arn` | ARN of the primary bucket |
| `replica_bucket_name` | Name of the replica bucket (if replication enabled) |
| `replica_bucket_arn` | ARN of the replica bucket (if replication enabled) |
| `replication_role_arn` | ARN of the IAM replication role (if enabled) |
| `uses_sse_s3_encryption` | Whether SSE-S3 (AES256) is used |
| `primary_kms_key_arn` | Primary KMS key ARN (when SSE-KMS) |
| `replica_kms_key_arn` | Replica KMS key ARN (when replication + SSE-KMS) |
| `website_endpoint` | S3 website endpoint (if website hosting enabled) |
| `website_domain` | S3 website domain (if website hosting enabled) |
| `website_public_mode` | True when bucket is configured for public website |
| `cloudfront_origin_access_mode` | True when CloudFront origin access mode is enabled |

## Usage Example

```hcl
module "s3_bucket" {
  source = "path/to/tf-module-aws-s3-bucket"

  account_name        = "platform"
  account_environment = "prod"
  bucket_purpose      = "tf-state"

  enable_versioning          = true
  enable_lifecycle_expiration = false

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```
