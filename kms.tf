resource "aws_kms_key" "sops_key" {
  description = "KMS key for SOPS encryption"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow SOPS Usage"
        Effect = "Allow"
        Principal = {
          AWS = var.sops_user_arn
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "sops_key_alias" {
  name          = "alias/sops-key-${var.environment}"
  target_key_id = aws_kms_key.sops_key.key_id
}
