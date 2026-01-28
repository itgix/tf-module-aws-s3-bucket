# Naming
variable "account_name" {
  description = "Logical account / domain name (e.g. platform, monitoring)."
  type        = string

  validation {
    condition     = trimspace(var.account_name) != ""
    error_message = "account_name must not be empty."
  }
}

variable "account_environment" {
  description = "Environment name (dev, int, prod)."
  type        = string

  validation {
    condition     = trimspace(var.account_environment) != ""
    error_message = "account_environment must not be empty."
  }
}

variable "bucket_purpose" {
  description = "Purpose of the bucket (e.g. tf-state, assets, logs)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.bucket_purpose))
    error_message = "bucket_purpose must contain only lowercase letters, digits, and hyphens."
  }
}

# Common
variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}

# Bucket core settings
variable "enable_versioning" {
  description = "Enable bucket versioning."
  type        = bool
  default     = true
}

variable "bucket_owner_enforced" {
  description = "Enable BucketOwnerEnforced object ownership."
  type        = bool
  default     = true
}

variable "object_lock_enabled" {
  description = "Enable S3 Object Lock on the bucket (requires versioning enabled)."
  type        = bool
  default     = false
}

variable "force_destroy" {
  description = "Allow Terraform to delete buckets with objects."
  type        = bool
  default     = false
}

# Encryption
variable "use_sse_s3_encryption" {
  description = "If true, use SSE-S3 (AES256). If false, use SSE-KMS."
  type        = bool
  default     = true
}

variable "primary_kms_key_arn" {
  description = "Existing KMS key ARN for primary bucket (required when use_sse_s3_encryption = false)."
  type        = string
  default     = null

  validation {
    condition     = var.use_sse_s3_encryption || (var.primary_kms_key_arn != null && trimspace(var.primary_kms_key_arn) != "")
    error_message = "primary_kms_key_arn is required when SSE-KMS is used (use_sse_s3_encryption=false)."
  }
}

variable "replica_kms_key_arn" {
  description = "Existing KMS key ARN for replica bucket (required when replication + SSE-KMS)."
  type        = string
  default     = null
}

# Security / Policies
variable "manage_bucket_policy" {
  description = "If true, module manages bucket policies (deny insecure transport / TLS). If false, policies are managed externally."
  type        = bool
  default     = true
}

variable "deny_insecure_transport" {
  description = "Deny requests that are not using HTTPS (aws:SecureTransport=false)."
  type        = bool
  default     = true
}

variable "enforce_tls_1_2_minimum" {
  description = "Deny TLS versions lower than 1.2."
  type        = bool
  default     = true
}

# Logging
variable "access_logging_target_bucket" {
  description = "S3 bucket where access logs are delivered (empty disables access logging)."
  type        = string
  default     = ""
}

variable "access_logging_prefix" {
  description = "Prefix for access logs inside the logging bucket."
  type        = string
  default     = "AWSLogs/"
}

variable "enable_partitioned_access_logs" {
  description = "Enable EventTime partitioning for access logs."
  type        = bool
  default     = false
}

# Lifecycle
variable "enable_lifecycle_expiration" {
  description = "Enable lifecycle expiration for objects."
  type        = bool
  default     = false
}

variable "lifecycle_expiration_days" {
  description = "Number of days after which objects expire."
  type        = number
  default     = 90

  validation {
    condition     = var.lifecycle_expiration_days >= 1
    error_message = "lifecycle_expiration_days must be at least 1."
  }
}

variable "enable_lifecycle_abort_incomplete_multipart_upload" {
  description = "When lifecycle expiration is enabled, also abort incomplete multipart uploads after a number of days."
  type        = bool
  default     = true
}

variable "lifecycle_abort_incomplete_multipart_upload_days" {
  description = "Number of days after initiation to abort incomplete multipart uploads (when enabled)."
  type        = number
  default     = 7

  validation {
    condition     = var.lifecycle_abort_incomplete_multipart_upload_days >= 1
    error_message = "lifecycle_abort_incomplete_multipart_upload_days must be at least 1."
  }
}

# Replication
variable "enable_cross_region_replication" {
  description = "Enable S3 cross-region replication."
  type        = bool
  default     = false
}

variable "replica_suffix" {
  description = "Suffix appended to the primary bucket name for the replica."
  type        = string
  default     = "-replica"
}

variable "replication_object_prefix" {
  description = "Only objects with this prefix are replicated. Empty string means all objects."
  type        = string
  default     = ""
}

variable "replication_storage_class" {
  description = "Storage class for replicated objects."
  type        = string
  default     = "STANDARD"
}

variable "replica_role_name" {
  description = "IAM role name created for S3 replication."
  type        = string
  default     = "s3-replication"
}

# Website hosting / public access / CloudFront OAC hook
variable "enable_website_hosting" {
  description = "Enable S3 static website hosting configuration (website endpoint)."
  type        = bool
  default     = false
}

variable "website_index_document" {
  description = "Index document for S3 website hosting."
  type        = string
  default     = "index.html"
}

variable "website_error_document" {
  description = "Error document for S3 website hosting."
  type        = string
  default     = "error.html"
}

variable "enable_public_read_for_website" {
  description = "If true, allow public s3:GetObject on bucket objects (required for S3 website endpoint)."
  type        = bool
  default     = false
}

variable "enable_cloudfront_origin_access" {
  description = "If true, keep bucket private and optionally allow CloudFront (OAC/OAI via service principal) to read objects."
  type        = bool
  default     = false
}

variable "cloudfront_distribution_arns" {
  description = "CloudFront distribution ARNs allowed to read from this bucket when enable_cloudfront_origin_access=true. Leave empty to manage policies externally."
  type        = list(string)
  default     = []
}
