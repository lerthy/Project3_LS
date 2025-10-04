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
          "s3:PutObjectAcl"
        ]
        Resource = [
          var.artifacts_bucket_arn,
          "${var.artifacts_bucket_arn}/*"
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

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "codebuild-custom-permissions"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # Existing permissions
          "logs:*",
          "s3:*",
          "lambda:*",
          "cloudfront:*",
          "ssm:*",
          "apigateway:*",
          "cloudwatch:*",
          "dynamodb:*",
          "codebuild:*",
          "codepipeline:*",
          "sts:*",
          "secretsmanager:*",
          
          # EC2 permissions (for VPC, Security Groups, etc.)
          "ec2:*",
          
          # IAM permissions (for creating roles)
          "iam:*",
          
          # RDS permissions
          "rds:*",
          
          # KMS permissions - explicit permissions to override restrictive key policies
          "kms:*",
          
          # WAF permissions
          "wafv2:*",
          
          # SNS permissions - explicit permissions for existing resources
          "sns:*",
          
          # SQS permissions - explicit permissions for existing resources
          "sqs:*",
          
          # Additional CloudWatch permissions
          "cloudwatch:*",
          
          # Route53 permissions
          "route53:*",
          
          # Application Auto Scaling permissions
          "application-autoscaling:*",
          
          # DMS permissions
          "dms:*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          # Explicit KMS permissions for existing keys
          "kms:DescribeKey",
          "kms:GetKeyPolicy",
          "kms:ListKeys", 
          "kms:ListAliases",
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = [
          "arn:aws:kms:eu-north-1:264765155009:key/*",
          "arn:aws:kms:us-west-2:264765155009:key/*"
        ]
      },
      {
        Effect = "Allow" 
        Action = [
          # Explicit SNS permissions for existing topics
          "sns:ListTagsForResource",
          "sns:GetTopicAttributes"
        ]
        Resource = [
          "arn:aws:sns:*:264765155009:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          # Explicit SQS permissions for existing queues
          "sqs:GetQueueAttributes",
          "sqs:ListQueueTags"
        ]
        Resource = [
          "arn:aws:sqs:*:264765155009:*"
        ]
      }
    ]
  })
}