check "object_lock_requires_versioning" {
  assert {
    condition     = !(var.object_lock_enabled && !var.enable_versioning)
    error_message = "object_lock_enabled requires enable_versioning=true."
  }
}

check "replication_requires_versioning" {
  assert {
    condition     = !(var.enable_cross_region_replication && !var.enable_versioning)
    error_message = "enable_cross_region_replication requires enable_versioning=true."
  }
}

check "replication_kms_requires_replica_key" {
  assert {
    condition = !(
    var.enable_cross_region_replication &&
    !var.use_sse_s3_encryption &&
    (var.replica_kms_key_arn == null || trimspace(var.replica_kms_key_arn) == "")
    )
    error_message = "When enable_cross_region_replication=true and SSE-KMS is used, replica_kms_key_arn must be set."
  }
}

check "website_public_requires_website" {
  assert {
    condition     = !(var.enable_public_read_for_website && !var.enable_website_hosting)
    error_message = "enable_public_read_for_website requires enable_website_hosting=true."
  }
}

check "website_public_conflicts_with_cloudfront_oac" {
  assert {
    condition     = !(var.enable_public_read_for_website && var.enable_cloudfront_origin_access)
    error_message = "enable_public_read_for_website cannot be used together with enable_cloudfront_origin_access."
  }
}
