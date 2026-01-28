terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 5.50"
      configuration_aliases = [aws.replica]
    }
  }
}

# Buckets
resource "aws_s3_bucket" "main" {
  bucket              = local.primary_bucket_name
  force_destroy       = var.force_destroy
  object_lock_enabled = var.object_lock_enabled
  tags                = var.tags

  lifecycle {
    precondition {
      condition     = !(var.object_lock_enabled && !var.enable_versioning)
      error_message = "object_lock_enabled requires enable_versioning=true."
    }
  }
}

resource "aws_s3_bucket" "replica_bucket" {
  count         = var.enable_cross_region_replication ? 1 : 0
  provider      = aws.replica
  bucket        = local.replica_bucket_name
  force_destroy = var.force_destroy
  tags          = var.tags
}

# Versioning
resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_versioning" "replica_bucket" {
  count    = var.enable_cross_region_replication ? 1 : 0
  provider = aws.replica
  bucket   = aws_s3_bucket.replica_bucket[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Ownership controls
resource "aws_s3_bucket_ownership_controls" "main" {
  count  = var.bucket_owner_enforced ? 1 : 0
  bucket = aws_s3_bucket.main.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_ownership_controls" "replica_bucket" {
  count    = var.enable_cross_region_replication && var.bucket_owner_enforced ? 1 : 0
  provider = aws.replica
  bucket   = aws_s3_bucket.replica_bucket[0].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Default bucket encryption (SSE-S3 / SSE-KMS)
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.use_sse_s3_encryption ? "AES256" : "aws:kms"
      kms_master_key_id = var.use_sse_s3_encryption ? null : var.primary_kms_key_arn
    }

    bucket_key_enabled = var.use_sse_s3_encryption ? null : true
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "replica_bucket" {
  count    = var.enable_cross_region_replication ? 1 : 0
  provider = aws.replica
  bucket   = aws_s3_bucket.replica_bucket[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.use_sse_s3_encryption ? "AES256" : "aws:kms"
      kms_master_key_id = var.use_sse_s3_encryption ? null : var.replica_kms_key_arn
    }

    bucket_key_enabled = var.use_sse_s3_encryption ? null : true
  }
}

# Website hosting (optional)
resource "aws_s3_bucket_website_configuration" "main" {
  count  = var.enable_website_hosting ? 1 : 0
  bucket = aws_s3_bucket.main.id

  index_document {
    suffix = var.website_index_document
  }

  error_document {
    key = var.website_error_document
  }
}

# Public access block
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id
  # Default: fully private. For S3 website endpoint public mode, allow public bucket policy.
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = local.website_public_mode ? false : true
  restrict_public_buckets = local.website_public_mode ? false : true

}

resource "aws_s3_bucket_public_access_block" "replica_bucket" {
  count    = var.enable_cross_region_replication ? 1 : 0
  provider = aws.replica
  bucket   = aws_s3_bucket.replica_bucket[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Access logging
resource "aws_s3_bucket_logging" "main" {
  count         = trimspace(var.access_logging_target_bucket) != "" ? 1 : 0
  bucket        = aws_s3_bucket.main.id
  target_bucket = var.access_logging_target_bucket
  target_prefix = local.logging_target_prefix

  dynamic "target_object_key_format" {
    for_each = var.enable_partitioned_access_logs ? [1] : []
    content {
      partitioned_prefix {
        partition_date_source = "EventTime"
      }
    }
  }
}

resource "aws_s3_bucket_logging" "replica" {
  count    = var.enable_cross_region_replication && trimspace(var.access_logging_target_bucket) != "" ? 1 : 0
  provider = aws.replica
  bucket   = aws_s3_bucket.replica_bucket[0].id

  target_bucket = var.access_logging_target_bucket
  target_prefix = "${trim(var.access_logging_prefix, "/")}/${local.replica_bucket_name}/"

  dynamic "target_object_key_format" {
    for_each = var.enable_partitioned_access_logs ? [1] : []
    content {
      partitioned_prefix {
        partition_date_source = "EventTime"
      }
    }
  }
}

# Lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "main" {
  count  = var.enable_lifecycle_expiration ? 1 : 0
  bucket = aws_s3_bucket.main.id

  rule {
    id     = "expire-all-objects"
    status = "Enabled"
    filter {}

    dynamic "abort_incomplete_multipart_upload" {
      for_each = var.enable_lifecycle_abort_incomplete_multipart_upload ? [1] : []
      content {
        days_after_initiation = var.lifecycle_abort_incomplete_multipart_upload_days
      }
    }

    expiration {
      days = var.lifecycle_expiration_days
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "replica" {
  count    = var.enable_cross_region_replication && var.enable_lifecycle_expiration ? 1 : 0
  provider = aws.replica
  bucket   = aws_s3_bucket.replica_bucket[0].id

  rule {
    id     = "expire-all-objects"
    status = "Enabled"
    filter {}

    dynamic "abort_incomplete_multipart_upload" {
      for_each = var.enable_lifecycle_abort_incomplete_multipart_upload ? [1] : []
      content {
        days_after_initiation = var.lifecycle_abort_incomplete_multipart_upload_days
      }
    }

    expiration {
      days = var.lifecycle_expiration_days
    }
  }
}

# Replication Configuration (primary -> replica)
resource "aws_s3_bucket_replication_configuration" "main" {
  count  = var.enable_cross_region_replication ? 1 : 0
  bucket = aws_s3_bucket.main.id

  depends_on = [
    aws_s3_bucket_versioning.main,
    aws_s3_bucket_server_side_encryption_configuration.main,
    aws_s3_bucket_versioning.replica_bucket,
    aws_s3_bucket_server_side_encryption_configuration.replica_bucket,
    aws_iam_role_policy_attachment.replication,
  ]

  role = aws_iam_role.replication[0].arn

  lifecycle {
    precondition {
      condition     = var.use_sse_s3_encryption || (var.replica_kms_key_arn != null && trimspace(var.replica_kms_key_arn) != "")
      error_message = "When SSE-KMS is used, replica_kms_key_arn must be set."
    }
  }

  rule {
    id     = "replicate"
    status = "Enabled"

    dynamic "filter" {
      for_each = trimspace(var.replication_object_prefix) != "" ? [1] : []
      content {
        prefix = var.replication_object_prefix
      }
    }

    dynamic "source_selection_criteria" {
      for_each = var.use_sse_s3_encryption ? [] : [1]
      content {
        sse_kms_encrypted_objects {
          status = "Enabled"
        }
      }
    }

    destination {
      bucket        = aws_s3_bucket.replica_bucket[0].arn
      storage_class = var.replication_storage_class

      dynamic "encryption_configuration" {
        for_each = var.use_sse_s3_encryption ? [] : [1]
        content {
          replica_kms_key_id = var.replica_kms_key_arn
        }
      }
    }
  }
}
