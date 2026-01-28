locals {
  account_id = data.aws_caller_identity.current.account_id

  primary_bucket_name = lower(join("-", [
    var.account_name,
    local.account_id,
    var.account_environment,
    "s3",
    var.bucket_purpose
  ]))

  replica_bucket_name = var.enable_cross_region_replication ? "${local.primary_bucket_name}${var.replica_suffix}" : null

  primary_region = data.aws_region.current.id
  replica_region = var.enable_cross_region_replication ? data.aws_region.replica.id : null

  logging_target_prefix = "${trim(var.access_logging_prefix, "/")}/${local.primary_bucket_name}/"

  website_public_mode = var.enable_website_hosting && var.enable_public_read_for_website
  cloudfront_mode     = var.enable_cloudfront_origin_access
}
