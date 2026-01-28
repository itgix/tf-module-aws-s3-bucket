data "aws_iam_policy_document" "replication_trust" {
  count = var.enable_cross_region_replication ? 1 : 0

  statement {
    sid     = "S3AssumeRoleForReplication"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "replication" {
  count              = var.enable_cross_region_replication ? 1 : 0
  name               = var.replica_role_name
  assume_role_policy = data.aws_iam_policy_document.replication_trust[0].json
  tags               = var.tags
}

data "aws_iam_policy_document" "replication_permissions" {
  count = var.enable_cross_region_replication ? 1 : 0

  # Read replication config + list on source
  statement {
    sid    = "ReadSourceBucketConfig"
    effect = "Allow"
    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket",
    ]
    resources = [aws_s3_bucket.main.arn]
  }

  # Read versions from source
  statement {
    sid    = "ReadSourceObjectVersions"
    effect = "Allow"
    actions = [
      "s3:GetObjectVersion",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionTagging",
    ]
    resources = ["${aws_s3_bucket.main.arn}/*"]
  }

  # Replicate to destination
  statement {
    sid    = "WriteReplicasToDestination"
    effect = "Allow"
    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
      "s3:ObjectOwnerOverrideToBucketOwner",
    ]
    # These are object-level actions; use object ARNs only.
    resources = ["${aws_s3_bucket.replica_bucket[0].arn}/*"]
  }

  # KMS permissions when using SSE-KMS
  dynamic "statement" {
    for_each = var.use_sse_s3_encryption ? [] : [1]
    content {
      sid    = "KmsForReplication"
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey",
      ]
      resources = compact([
        var.primary_kms_key_arn,
        var.replica_kms_key_arn,
      ])
    }
  }
}

resource "aws_iam_policy" "replication" {
  count       = var.enable_cross_region_replication ? 1 : 0
  name        = "${var.replica_role_name}-policy"
  description = "Permissions for S3 cross-region replication."
  policy      = data.aws_iam_policy_document.replication_permissions[0].json
}

resource "aws_iam_role_policy_attachment" "replication" {
  count      = var.enable_cross_region_replication ? 1 : 0
  role       = aws_iam_role.replication[0].name
  policy_arn = aws_iam_policy.replication[0].arn
}
