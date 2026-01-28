output "primary_bucket_name" {
  value       = aws_s3_bucket.main.bucket
  description = "Name of the primary bucket."
}

output "primary_bucket_arn" {
  value       = aws_s3_bucket.main.arn
  description = "ARN of the primary bucket."
}

output "replica_bucket_name" {
  value       = var.enable_cross_region_replication ? aws_s3_bucket.replica_bucket[0].bucket : null
  description = "Name of the replica bucket (if replication is enabled)."
}

output "replica_bucket_arn" {
  value       = var.enable_cross_region_replication ? aws_s3_bucket.replica_bucket[0].arn : null
  description = "ARN of the replica bucket (if replication is enabled)."
}

output "replication_role_arn" {
  value       = var.enable_cross_region_replication ? aws_iam_role.replication[0].arn : null
  description = "ARN of the IAM role used by S3 for replication (if enabled)."
}

output "uses_sse_s3_encryption" {
  value       = var.use_sse_s3_encryption
  description = "Whether SSE-S3 (AES256) is used. If false, SSE-KMS is used."
}

output "primary_kms_key_arn" {
  value       = var.use_sse_s3_encryption ? null : var.primary_kms_key_arn
  description = "Primary KMS key ARN when SSE-KMS is used."
}

output "replica_kms_key_arn" {
  value       = (var.enable_cross_region_replication && !var.use_sse_s3_encryption) ? var.replica_kms_key_arn : null
  description = "Replica KMS key ARN when replication is enabled and SSE-KMS is used."
}

output "website_endpoint" {
  value       = var.enable_website_hosting ? aws_s3_bucket_website_configuration.main[0].website_endpoint : null
  description = "S3 website endpoint (if website hosting is enabled)."
}

output "website_domain" {
  value       = var.enable_website_hosting ? aws_s3_bucket_website_configuration.main[0].website_domain : null
  description = "S3 website domain (if website hosting is enabled)."
}

output "website_public_mode" {
  value       = local.website_public_mode
  description = "True when bucket is configured for S3 website endpoint + public read."
}

output "cloudfront_origin_access_mode" {
  value       = local.cloudfront_mode
  description = "True when CloudFront origin access mode is enabled (bucket intended to remain private)."
}
