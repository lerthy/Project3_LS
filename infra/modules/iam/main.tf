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
  name = "codebuild-least-privilege-permissions"
  role = aws_iam_role.codebuild_role.id

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
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:*:log-group:/aws/codebuild/*",
          "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/*",
          "arn:aws:logs:${var.aws_region}:*:log-group:/aws/apigateway/*"
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
          "s3:PutBucketPublicAccessBlock",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketWebsite",
          "s3:GetBucketWebsite",
          "s3:PutBucketNotification",
          "s3:GetBucketNotification"
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
          "arn:aws:dynamodb:${var.aws_region}:*:table/terraform-*"
        ]
      },
      # Lambda permissions
      {
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction",
          "lambda:DeleteFunction",
          "lambda:GetFunction",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:ListVersionsByFunction",
          "lambda:PublishVersion",
          "lambda:CreateAlias",
          "lambda:DeleteAlias",
          "lambda:GetAlias",
          "lambda:UpdateAlias",
          "lambda:AddPermission",
          "lambda:RemovePermission",
          "lambda:GetPolicy",
          "lambda:PutFunctionEventInvokeConfig",
          "lambda:DeleteFunctionEventInvokeConfig",
          "lambda:GetFunctionEventInvokeConfig",
          "lambda:TagResource",
          "lambda:UntagResource",
          "lambda:ListTags"
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
          "apigateway:GET",
          "apigateway:POST",
          "apigateway:PUT",
          "apigateway:DELETE",
          "apigateway:PATCH"
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
          "cloudfront:CreateDistribution",
          "cloudfront:GetDistribution",
          "cloudfront:UpdateDistribution",
          "cloudfront:DeleteDistribution",
          "cloudfront:CreateOriginAccessIdentity",
          "cloudfront:GetOriginAccessIdentity",
          "cloudfront:DeleteOriginAccessIdentity",
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation",
          "cloudfront:ListInvalidations",
          "cloudfront:TagResource",
          "cloudfront:ListTagsForResource"
        ]
        Resource = "*"
      },
      # IAM permissions - scoped to specific roles and policies
      {
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:UpdateRole",
          "iam:PassRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:ListRoleTags"
        ]
        Resource = [
          "arn:aws:iam::*:role/lambda*",
          "arn:aws:iam::*:role/codebuild*",
          "arn:aws:iam::*:role/codepipeline*",
          "arn:aws:iam::*:role/rds*",
          "arn:aws:iam::*:role/dms*"
        ]
      },
      # RDS permissions
      {
        Effect = "Allow"
        Action = [
          "rds:CreateDBInstance",
          "rds:DeleteDBInstance",
          "rds:DescribeDBInstances",
          "rds:ModifyDBInstance",
          "rds:CreateDBSubnetGroup",
          "rds:DeleteDBSubnetGroup",
          "rds:DescribeDBSubnetGroups",
          "rds:AddTagsToResource",
          "rds:ListTagsForResource",
          "rds:RemoveTagsFromResource"
        ]
        Resource = [
          "arn:aws:rds:${var.aws_region}:*:db:contact-db*",
          "arn:aws:rds:${var.aws_region}:*:subnet-group:*"
        ]
      },
      # EC2 permissions for VPC and Security Groups
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateVpc",
          "ec2:DeleteVpc",
          "ec2:DescribeVpcs",
          "ec2:CreateSubnet",
          "ec2:DeleteSubnet",
          "ec2:DescribeSubnets",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:DescribeSecurityGroups",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateTags",
          "ec2:DescribeTags",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeNetworkInterfaces",
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:ModifyNetworkInterfaceAttribute"
        ]
        Resource = "*"
      },
      # SSM Parameter Store permissions
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:PutParameter",
          "ssm:DeleteParameter",
          "ssm:DescribeParameters",
          "ssm:AddTagsToResource",
          "ssm:ListTagsForResource",
          "ssm:RemoveTagsFromResource"
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
      # Secrets Manager permissions
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:CreateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecret",
          "secretsmanager:TagResource",
          "secretsmanager:UntagResource"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:*:secret:project3/*"
        ]
      },
      # CloudWatch permissions
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:DeleteAlarms",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:PutDashboard",
          "cloudwatch:DeleteDashboards",
          "cloudwatch:GetDashboard",
          "cloudwatch:ListDashboards"
        ]
        Resource = "*"
      },
      # SNS permissions - scoped to project topics
      {
        Effect = "Allow"
        Action = [
          "sns:CreateTopic",
          "sns:DeleteTopic",
          "sns:GetTopicAttributes",
          "sns:SetTopicAttributes",
          "sns:Subscribe",
          "sns:Unsubscribe",
          "sns:ListSubscriptionsByTopic",
          "sns:TagResource",
          "sns:UntagResource",
          "sns:ListTagsForResource"
        ]
        Resource = [
          "arn:aws:sns:${var.aws_region}:*:project3-*"
        ]
      },
      # SQS permissions - scoped to project queues
      {
        Effect = "Allow"
        Action = [
          "sqs:CreateQueue",
          "sqs:DeleteQueue",
          "sqs:GetQueueAttributes",
          "sqs:SetQueueAttributes",
          "sqs:TagQueue",
          "sqs:UntagQueue",
          "sqs:ListQueueTags"
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
          "kms:Describe*",
          "kms:List*",
          "kms:Get*",
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*",
          "kms:CreateKey",
          "kms:CreateAlias",
          "kms:DeleteAlias",
          "kms:TagResource",
          "kms:UntagResource"
        ]
        Resource = [
          "arn:aws:kms:${var.aws_region}:*:key/*",
          "arn:aws:kms:${var.aws_region}:*:alias/project3-*"
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
}