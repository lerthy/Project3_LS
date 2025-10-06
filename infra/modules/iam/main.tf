# IAM role for CodePipeline
resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline-role-project3"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })
  tags = {
    Environment = "development"
    Project     = "contact-form-webapp"
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "codepipeline-policy"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketVersioning",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:DeleteObject"
        ]
        Resource = [
          var.artifacts_bucket_arn,
          "${var.artifacts_bucket_arn}/*",
          "arn:aws:s3:::codepipeline-artifacts-*",
          "arn:aws:s3:::codepipeline-artifacts-*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codestar-connections:UseConnection",
          "codestar-connections:GetConnection"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM role for CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-role-project3-v2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
  tags = {
    Environment = "development"
    Project     = "contact-form-webapp"
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "codebuild_base_policy" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess"
}

# Split CodeBuild policies into smaller chunks to avoid 10KB limit

# Core CodeBuild permissions (Logs, S3, DynamoDB)
resource "aws_iam_role_policy" "codebuild_core" {
  name = "codebuild-core-permissions"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:*:log-group:/aws/codebuild/*",
          "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::terraform-state-*",
          "arn:aws:s3:::terraform-state-*/*",
          "arn:aws:s3:::my-website-bucket-*",
          "arn:aws:s3:::my-website-bucket-*/*",
          "arn:aws:s3:::codepipeline-artifacts-*",
          "arn:aws:s3:::codepipeline-artifacts-*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable"
        ]
        Resource = [
          "arn:aws:dynamodb:${var.aws_region}:*:table/terraform-*"
        ]
      }
    ]
  })
}

# Compute services permissions (Lambda, EC2)
resource "aws_iam_role_policy" "codebuild_compute" {
  name = "codebuild-compute-permissions"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:*"
        ]
        Resource = [
          "arn:aws:lambda:${var.aws_region}:*:function:contact-form*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:CreateTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole",
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM and KMS permissions
resource "aws_iam_role_policy" "codebuild_security" {
  name = "codebuild-security-permissions" 
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole",
          "iam:GetRole"
        ]
        Resource = [
          "arn:aws:iam::*:role/lambda*",
          "arn:aws:iam::*:role/codebuild*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Describe*",
          "kms:List*",
          "kms:Get*",
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:PutParameter"
        ]
        Resource = [
          "arn:aws:ssm:${var.aws_region}:*:parameter/project3/*"
        ]
      }
    ]
  })
}