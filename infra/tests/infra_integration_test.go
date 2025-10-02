package tests

import (
    "fmt"
    "net/http"
    "os"
    "strings"
    "testing"
    "time"

    "github.com/gruntwork-io/terratest/modules/aws"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestInfra(t *testing.T) {
    t.Parallel()

    if os.Getenv("CI_SKIP_TERRATEST") == "1" {
        t.Skip("Skipping Terratest in CI (CI_SKIP_TERRATEST=1)")
    }

    opts := &terraform.Options{
        TerraformDir: "../",
        Vars: map[string]interface{}{
            "db_password": "TestPassw0rd!",
            "notification_email": "test@example.com",
            "approval_email": "approval@example.com",
        },
    }

    defer terraform.Destroy(t, opts)
    terraform.InitAndApply(t, opts)

    // Test basic infrastructure outputs
    t.Run("TestBasicInfrastructure", func(t *testing.T) {
        testBasicInfrastructure(t, opts)
    })

    // Test operational excellence components
    t.Run("TestOperationalExcellence", func(t *testing.T) {
        testOperationalExcellence(t, opts)
    })

    // Test monitoring and alerting
    t.Run("TestMonitoringAlerting", func(t *testing.T) {
        testMonitoringAlerting(t, opts)
    })

    // Test security compliance
    t.Run("TestSecurityCompliance", func(t *testing.T) {
        testSecurityCompliance(t, opts)
    })

    // Test performance optimization
    t.Run("TestPerformanceOptimization", func(t *testing.T) {
        testPerformanceOptimization(t, opts)
    })

    // Test reliability features
    t.Run("TestReliabilityFeatures", func(t *testing.T) {
        testReliabilityFeatures(t, opts)
    })
}

func testBasicInfrastructure(t *testing.T, opts *terraform.Options) {
    bucketName := terraform.Output(t, opts, "bucket_name")
    cloudfrontURL := terraform.Output(t, opts, "cloudfront_url")
    apiGateway := terraform.Output(t, opts, "api_gateway_url")
    
    t.Logf("bucket_name=%s", bucketName)
    t.Logf("cloudfront_url=%s", cloudfrontURL)
    t.Logf("api_gateway_url=%s", apiGateway)

    require.NotEmpty(t, bucketName, "bucket_name output is empty")
    require.NotEmpty(t, cloudfrontURL, "cloudfront_url output is empty")
    assert.Contains(t, apiGateway, "execute-api", "api_gateway_url does not look like an API Gateway URL")

    // Skip slower RDS checks when running with -short
    if !testing.Short() {
        rdsEndpoint := terraform.Output(t, opts, "rds_endpoint")
        t.Logf("rds_endpoint=%s", rdsEndpoint)
        assert.Contains(t, rdsEndpoint, "rds.amazonaws.com", "rds_endpoint does not look like an RDS endpoint")
    }
}

func testOperationalExcellence(t *testing.T, opts *terraform.Options) {
    // Test SNS topics exist
    cicdTopicArn := terraform.Output(t, opts, "cicd_notification_topic_arn")
    approvalTopicArn := terraform.Output(t, opts, "manual_approval_topic_arn")
    
    require.NotEmpty(t, cicdTopicArn, "CI/CD notification topic ARN is empty")
    require.NotEmpty(t, approvalTopicArn, "Manual approval topic ARN is empty")
    
    assert.Contains(t, cicdTopicArn, "arn:aws:sns", "CI/CD topic ARN format is incorrect")
    assert.Contains(t, approvalTopicArn, "arn:aws:sns", "Approval topic ARN format is incorrect")

    // Test dashboards exist
    operationalDashboard := terraform.Output(t, opts, "operational_dashboard_url")
    deploymentDashboard := terraform.Output(t, opts, "deployment_dashboard_url")
    
    require.NotEmpty(t, operationalDashboard, "Operational dashboard URL is empty")
    require.NotEmpty(t, deploymentDashboard, "Deployment dashboard URL is empty")
    
    assert.Contains(t, operationalDashboard, "cloudwatch", "Operational dashboard URL format is incorrect")
    assert.Contains(t, deploymentDashboard, "cloudwatch", "Deployment dashboard URL format is incorrect")
}

func testMonitoringAlerting(t *testing.T, opts *terraform.Options) {
    awsRegion := terraform.Output(t, opts, "aws_region")
    
    // Test pipeline alarms
    infraAlarmName := terraform.Output(t, opts, "infra_pipeline_alarm_name")
    webAlarmName := terraform.Output(t, opts, "web_pipeline_alarm_name")
    
    require.NotEmpty(t, infraAlarmName, "Infrastructure pipeline alarm name is empty")
    require.NotEmpty(t, webAlarmName, "Web pipeline alarm name is empty")
    
    // Verify alarms exist in CloudWatch
    infraAlarm := aws.GetCloudWatchAlarm(t, awsRegion, infraAlarmName)
    webAlarm := aws.GetCloudWatchAlarm(t, awsRegion, webAlarmName)
    
    assert.Equal(t, "GreaterThanThreshold", *infraAlarm.ComparisonOperator, "Infrastructure alarm comparison operator is incorrect")
    assert.Equal(t, "GreaterThanThreshold", *webAlarm.ComparisonOperator, "Web alarm comparison operator is incorrect")
    assert.Equal(t, float64(0), *infraAlarm.Threshold, "Infrastructure alarm threshold is incorrect")
    assert.Equal(t, float64(0), *webAlarm.Threshold, "Web alarm threshold is incorrect")
}

func testSecurityCompliance(t *testing.T, opts *terraform.Options) {
    // Test secrets management
    dbSecretArn := terraform.Output(t, opts, "db_secret_arn")
    require.NotEmpty(t, dbSecretArn, "Database secret ARN is empty")
    assert.Contains(t, dbSecretArn, "arn:aws:secretsmanager", "Database secret ARN format is incorrect")
    
    // Test S3 bucket security
    bucketName := terraform.Output(t, opts, "bucket_name")
    awsRegion := terraform.Output(t, opts, "aws_region")
    
    // Verify S3 bucket has versioning enabled
    versioning := aws.GetS3BucketVersioning(t, awsRegion, bucketName)
    assert.Equal(t, "Enabled", versioning, "S3 bucket versioning should be enabled")
    
    // Verify S3 bucket has encryption enabled
    encryption := aws.GetS3BucketEncryption(t, awsRegion, bucketName)
    assert.NotNil(t, encryption, "S3 bucket encryption should be enabled")
}

func testPerformanceOptimization(t *testing.T, opts *terraform.Options) {
    cloudfrontURL := terraform.Output(t, opts, "cloudfront_url")
    
    // Test CloudFront response time
    start := time.Now()
    resp, err := http.Get(fmt.Sprintf("https://%s", cloudfrontURL))
    duration := time.Since(start)
    
    require.NoError(t, err, "Failed to make HTTP request to CloudFront")
    defer resp.Body.Close()
    
    assert.Equal(t, 200, resp.StatusCode, "CloudFront should return 200 OK")
    assert.Less(t, duration, 5*time.Second, "CloudFront response time should be less than 5 seconds")
    
    // Check for compression
    contentEncoding := resp.Header.Get("Content-Encoding")
    if contentEncoding != "" {
        assert.Contains(t, strings.ToLower(contentEncoding), "gzip", "CloudFront should enable compression")
    }
}

func testReliabilityFeatures(t *testing.T, opts *terraform.Options) {
    awsRegion := terraform.Output(t, opts, "aws_region")
    
    // Test Lambda function exists and is configured properly
    lambdaName := terraform.Output(t, opts, "lambda_function_name")
    require.NotEmpty(t, lambdaName, "Lambda function name is empty")
    
    lambdaFunction := aws.GetLambdaFunction(t, awsRegion, lambdaName)
    assert.NotNil(t, lambdaFunction, "Lambda function should exist")
    assert.Equal(t, "nodejs18.x", *lambdaFunction.Runtime, "Lambda runtime should be nodejs18.x")
    
    // Test API Gateway health
    apiURL := terraform.Output(t, opts, "api_gateway_url")
    resp, err := http.Get(apiURL)
    
    if err == nil {
        defer resp.Body.Close()
        // API might return 403 or 405 for GET requests, but should not be 5xx
        assert.Less(t, resp.StatusCode, 500, "API Gateway should not return 5xx errors")
    }
}
