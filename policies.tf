# Optional: Public read for S3 website endpoint hosting
data "aws_iam_policy_document" "public_website_read" {
  count = (var.manage_bucket_policy && local.website_public_mode) ? 1 : 0

  statement {
    sid    = "PublicReadForWebsite"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.main.arn}/*"]
  }
}

# Optional: CloudFront (OAC) read access to private bucket
data "aws_iam_policy_document" "cloudfront_read" {
  count = (var.manage_bucket_policy && local.cloudfront_mode && length(var.cloudfront_distribution_arns) > 0) ? 1 : 0

  statement {
    sid    = "AllowCloudFrontRead"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.main.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = var.cloudfront_distribution_arns
    }
  }
}

data "aws_iam_policy_document" "bucket_policy" {
  count = var.manage_bucket_policy ? 1 : 0

  source_policy_documents = compact([
    (var.manage_bucket_policy && local.website_public_mode) ? data.aws_iam_policy_document.public_website_read[0].json : null,
    (var.manage_bucket_policy && local.cloudfront_mode && length(var.cloudfront_distribution_arns) > 0) ? data.aws_iam_policy_document.cloudfront_read[0].json : null,
  ])

  dynamic "statement" {
    for_each = var.deny_insecure_transport ? [1] : []
    content {
      sid    = "DenyInsecureTransport"
      effect = "Deny"

      principals {
        type        = "AWS"
        identifiers = ["*"]
      }

      actions = ["s3:*"]
      resources = [
        aws_s3_bucket.main.arn,
        "${aws_s3_bucket.main.arn}/*",
      ]

      condition {
        test     = "Bool"
        variable = "aws:SecureTransport"
        values   = ["false"]
      }
    }
  }

  dynamic "statement" {
    for_each = var.enforce_tls_1_2_minimum ? [1] : []
    content {
      sid    = "DenyTLSBelow12"
      effect = "Deny"

      principals {
        type        = "AWS"
        identifiers = ["*"]
      }

      actions = ["s3:*"]
      resources = [
        aws_s3_bucket.main.arn,
        "${aws_s3_bucket.main.arn}/*",
      ]

      condition {
        test     = "NumericLessThan"
        variable = "s3:TlsVersion"
        values   = ["1.2"]
      }
    }
  }
}

resource "aws_s3_bucket_policy" "main" {
  count  = var.manage_bucket_policy ? 1 : 0
  bucket = aws_s3_bucket.main.id
  policy = data.aws_iam_policy_document.bucket_policy[0].json

  # Avoid occasional AWS ordering/race issues with Public Access Block vs policy application.
  depends_on = [aws_s3_bucket_public_access_block.main]
}

# Replica bucket policy (same security posture)
data "aws_iam_policy_document" "replica_bucket_policy" {
  count = var.enable_cross_region_replication && var.manage_bucket_policy ? 1 : 0

  dynamic "statement" {
    for_each = var.deny_insecure_transport ? [1] : []
    content {
      sid    = "DenyInsecureTransport"
      effect = "Deny"

      principals {
        type        = "AWS"
        identifiers = ["*"]
      }

      actions = ["s3:*"]
      resources = [
        aws_s3_bucket.replica_bucket[0].arn,
        "${aws_s3_bucket.replica_bucket[0].arn}/*",
      ]

      condition {
        test     = "Bool"
        variable = "aws:SecureTransport"
        values   = ["false"]
      }
    }
  }

  dynamic "statement" {
    for_each = var.enforce_tls_1_2_minimum ? [1] : []
    content {
      sid    = "DenyTLSBelow12"
      effect = "Deny"

      principals {
        type        = "AWS"
        identifiers = ["*"]
      }

      actions = ["s3:*"]
      resources = [
        aws_s3_bucket.replica_bucket[0].arn,
        "${aws_s3_bucket.replica_bucket[0].arn}/*",
      ]

      condition {
        test     = "NumericLessThan"
        variable = "s3:TlsVersion"
        values   = ["1.2"]
      }
    }
  }
}

resource "aws_s3_bucket_policy" "replica" {
  count    = var.enable_cross_region_replication && var.manage_bucket_policy ? 1 : 0
  provider = aws.replica
  bucket   = aws_s3_bucket.replica_bucket[0].id
  policy   = data.aws_iam_policy_document.replica_bucket_policy[0].json

  # Avoid occasional AWS ordering/race issues with Public Access Block vs policy application.
  depends_on = [aws_s3_bucket_public_access_block.replica_bucket]
}
