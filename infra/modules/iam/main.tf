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

# Split the large policy into multiple smaller policies to avoid the 10KB limit

# Policy 1: Core compute and storage services - MANAGED POLICY
resource "aws_iam_policy" "codebuild_core_policy" {
  name        = "codebuild-core-permissions-project3"
  path        = "/"
  description = "Core permissions for CodeBuild (S3, DynamoDB, CloudWatch Logs, STS)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # CloudWatch Logs permissions
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:ListTagsForResource",
          "logs:TagResource",
          "logs:UntagResource"
        ]
        Resource = [
          "arn:aws:logs:*:*:log-group:/aws/codebuild/*",
          "arn:aws:logs:*:*:log-group:/aws/lambda/*",
          "arn:aws:logs:*:*:log-group:/aws/apigateway/*",
          "arn:aws:logs:*:*:log-group:/apigw/*"
        ]
      },
      # S3 permissions - scoped to specific buckets
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning",
          "s3:ListBucket",
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:PutBucketPolicy",
          "s3:GetBucketPolicy",
          "s3:PutBucketVersioning",
          "s3:PutBucketEncryption",
          "s3:GetBucketEncryption",
          "s3:DeleteBucketEncryption",
          "s3:PutEncryptionConfiguration",
          "s3:GetEncryptionConfiguration",
          "s3:PutBucketPublicAccessBlock",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketWebsite",
          "s3:GetBucketWebsite",
          "s3:PutBucketNotification",
          "s3:GetBucketNotification",
          "s3:GetBucketAcl",
          "s3:PutBucketAcl",
          "s3:PutBucketOwnershipControls",
          "s3:GetBucketOwnershipControls",
          "s3:GetBucketTagging",
          "s3:PutBucketTagging",
          "s3:GetBucketCors",
          "s3:PutBucketCors",
          "s3:GetBucketRequestPayment",
          "s3:PutBucketRequestPayment",
          "s3:GetBucketLogging",
          "s3:PutBucketLogging",
          "s3:GetLifecycleConfiguration",
          "s3:PutLifecycleConfiguration",
          "s3:GetReplicationConfiguration",
          "s3:PutReplicationConfiguration",
          "s3:GetAccelerateConfiguration",
          "s3:PutAccelerateConfiguration",
          "s3:GetObjectLockConfiguration",
          "s3:PutObjectLockConfiguration",
          "s3:GetBucketObjectLockConfiguration",
          "s3:PutBucketObjectLockConfiguration",
          "s3:GetIntelligentTieringConfiguration",
          "s3:PutIntelligentTieringConfiguration",
          "s3:GetObjectTagging",
          "s3:PutObjectTagging",
          "s3:DeleteObjectTagging"
        ]
        Resource = [
          "arn:aws:s3:::terraform-state-*",
          "arn:aws:s3:::terraform-state-*/*",
          "arn:aws:s3:::my-website-bucket-*",
          "arn:aws:s3:::my-website-bucket-*/*",
          "arn:aws:s3:::codepipeline-artifacts-*",
          "arn:aws:s3:::codepipeline-artifacts-*/*",
          "arn:aws:s3:::project3-*",
          "arn:aws:s3:::project3-*/*"
        ]
      },
      # DynamoDB permissions for Terraform state locking
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable",
          "dynamodb:CreateTable",
          "dynamodb:DeleteTable",
          "dynamodb:TagResource",
          "dynamodb:ListTagsOfResource"
        ]
        Resource = [
          "arn:aws:dynamodb:*:*:table/terraform-*"
        ]
      },
      # STS permissions for assume role
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

  tags = {
    Environment = "development"
    Project     = "contact-form-webapp"
    ManagedBy   = "terraform"
  }
}

# Attach core policy to CodeBuild role
resource "aws_iam_role_policy_attachment" "codebuild_core_policy" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild_core_policy.arn
}

# Policy 2: Application services (Lambda, API Gateway, CloudFront)
resource "aws_iam_role_policy" "codebuild_app_policy" {
  name = "codebuild-app-permissions"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Lambda permissions
      {
        Effect = "Allow"
        Action = [
          "lambda:*"
        ]
        Resource = [
          "arn:aws:lambda:${var.aws_region}:*:function:contact-form*",
          "arn:aws:lambda:${var.aws_region}:*:function:*disaster*",
          "arn:aws:lambda:${var.aws_region}:*:function:*backup*"
        ]
      },
      # API Gateway permissions
      {
        Effect = "Allow"
        Action = [
          "apigateway:*"
        ]
        Resource = [
          "arn:aws:apigateway:${var.aws_region}::/restapis",
          "arn:aws:apigateway:${var.aws_region}::/restapis/*"
        ]
      },
      # CloudFront permissions
      {
        Effect = "Allow"
        Action = [
          "cloudfront:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# Policy 3: Infrastructure services (IAM, RDS, EC2)
resource "aws_iam_role_policy" "codebuild_infra_policy" {
  name = "codebuild-infra-permissions"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # IAM permissions - scoped to specific roles and policies
      {
        Effect = "Allow"
        Action = [
          "iam:*"
        ]
        Resource = [
          "arn:aws:iam::*:role/lambda*",
          "arn:aws:iam::*:role/codebuild*",
          "arn:aws:iam::*:role/codepipeline*",
          "arn:aws:iam::*:role/rds*",
          "arn:aws:iam::*:role/dms*",
          "arn:aws:iam::*:role/api-gateway*",
          "arn:aws:iam::*:role/*drift*",
          "arn:aws:iam::*:role/*backup*",
          "arn:aws:iam::*:role/*disaster*",
          "arn:aws:iam::*:policy/*",
          "arn:aws:iam::*:instance-profile/*"
        ]
      },
      # RDS permissions
      {
        Effect = "Allow"
        Action = [
          "rds:*"
        ]
        Resource = [
          "arn:aws:rds:${var.aws_region}:*:db:contact-db*",
          "arn:aws:rds:${var.aws_region}:*:subnet-group:*",
          "arn:aws:rds:${var.aws_region}:*:pg:*"
        ]
      },
      # EC2 permissions for VPC and Security Groups
      {
        Effect = "Allow"
        Action = [
          "ec2:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# Policy 5: Additional infrastructure services (DMS, Route53, WAF, etc.) - MANAGED POLICY
resource "aws_iam_policy" "codebuild_additional_infra_policy" {
  name = "codebuild-additional-infra-permissions-project3"
  path = "/"
  description = "Additional infrastructure permissions for CodeBuild (DMS, Route53, WAF, EventBridge, Backup)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # DMS permissions for Database Migration Service
      {
        Effect = "Allow"
        Action = [
          "dms:*"
        ]
        Resource = "*"
      },
      # Route53 permissions for DNS and health checks
      {
        Effect = "Allow"
        Action = [
          "route53:*"
        ]
        Resource = "*"
      },
      # WAFv2 permissions for Web Application Firewall
      {
        Effect = "Allow"
        Action = [
          "wafv2:*"
        ]
        Resource = "*"
      },
      # EventBridge permissions for automation
      {
        Effect = "Allow"
        Action = [
          "events:*"
        ]
        Resource = "*"
      },
      # Backup permissions for AWS Backup service
      {
        Effect = "Allow"
        Action = [
          "backup:*"
        ]
        Resource = "*"
      }
    ]
  })
  
  tags = {
    Environment = "development"
    Project     = "contact-form-webapp"
    ManagedBy   = "terraform"
  }
}

# Attach the managed policy to CodeBuild role
resource "aws_iam_role_policy_attachment" "codebuild_additional_infra_policy" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild_additional_infra_policy.arn
}

# Policy 4: Configuration and monitoring services
resource "aws_iam_role_policy" "codebuild_config_policy" {
  name = "codebuild-config-permissions"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # SSM Parameter Store permissions
      {
        Effect = "Allow"
        Action = [
          "ssm:*"
        ]
        Resource = [
          "arn:aws:ssm:${var.aws_region}:*:parameter/project3/*",
          "arn:aws:ssm:${var.aws_region}:*:parameter/s3/*",
          "arn:aws:ssm:${var.aws_region}:*:parameter/cloudfront/*",
          "arn:aws:ssm:${var.aws_region}:*:parameter/api-gateway/*",
          "arn:aws:ssm:${var.aws_region}:*:parameter/lambda/*",
          "arn:aws:ssm:${var.aws_region}:*:parameter/rds/*"
        ]
      },
      # SSM DescribeParameters permission (needs wildcard resource)
      {
        Effect = "Allow"
        Action = [
          "ssm:DescribeParameters"
        ]
        Resource = "*"
      },
      # Secrets Manager permissions (multi-region support for disaster recovery)
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:*"
        ]
        Resource = [
          "arn:aws:secretsmanager:*:*:secret:project3/*"
        ]
      },
      # CloudWatch permissions
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:*"
        ]
        Resource = "*"
      },
      # SNS permissions - all actions for project topics
      {
        Effect = "Allow"
        Action = [
          "sns:*"
        ]
        Resource = [
          "arn:aws:sns:${var.aws_region}:*:project3-*",
          "arn:aws:sns:${var.aws_region}:*:*-alerts",
          "arn:aws:sns:${var.aws_region}:*:cicd-*",
          "arn:aws:sns:${var.aws_region}:*:manual-approval-*",
          "arn:aws:sns:${var.aws_region}:*:development-*",
          "arn:aws:sns:${var.aws_region}:*:multi-region-*"
        ]
      },
      # Additional SNS subscription permissions (broad scope needed for email subscriptions)
      {
        Effect = "Allow"
        Action = [
          "sns:Subscribe",
          "sns:Unsubscribe",
          "sns:ListSubscriptionsByTopic",
          "sns:GetSubscriptionAttributes",
          "sns:SetSubscriptionAttributes"
        ]
        Resource = "*"
      },
      # SQS permissions - scoped to project queues
      {
        Effect = "Allow"
        Action = [
          "sqs:*"
        ]
        Resource = [
          "arn:aws:sqs:${var.aws_region}:*:contact-form*",
          "arn:aws:sqs:${var.aws_region}:*:project3-*"
        ]
      },
      # KMS permissions - specific keys only
      {
        Effect = "Allow"
        Action = [
          "kms:*"
        ]
        Resource = [
          "arn:aws:kms:${var.aws_region}:*:key/*",
          "arn:aws:kms:${var.aws_region}:*:alias/project3-*"
        ]
      },
      # KMS ListAliases permission (needs wildcard resource)
      {
        Effect = "Allow"
        Action = [
          "kms:ListAliases",
          "kms:ListKeys"
        ]
        Resource = "*"
      },
      # Application Auto Scaling permissions
      {
        Effect = "Allow"
        Action = [
          "application-autoscaling:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# API Gateway CloudWatch Logs role
resource "aws_iam_role" "api_gateway_cloudwatch_role" {
  name = "api-gateway-cloudwatch-role-project3"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch_policy" {
  role       = aws_iam_role.api_gateway_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# Set the API Gateway account configuration to use the CloudWatch Logs role
resource "aws_api_gateway_account" "api_gateway_account" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch_role.arn
}