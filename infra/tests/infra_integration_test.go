package tests

import (
    "testing"

    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestInfra(t *testing.T) {
    t.Parallel()

    opts := &terraform.Options{
        TerraformDir: "../",
        Vars: map[string]interface{}{
            "db_password": "TestPassw0rd!",
        },
    }

    defer terraform.Destroy(t, opts)
    terraform.InitAndApply(t, opts)

    bucketName := terraform.Output(t, opts, "bucket_name")
    cloudfrontURL := terraform.Output(t, opts, "cloudfront_url")
    apiGateway := terraform.Output(t, opts, "api_gateway_url")
    rdsEndpoint := terraform.Output(t, opts, "rds_endpoint")

    t.Logf("bucket_name=%s", bucketName)
    t.Logf("cloudfront_url=%s", cloudfrontURL)
    t.Logf("api_gateway_url=%s", apiGateway)
    t.Logf("rds_endpoint=%s", rdsEndpoint)

    require.NotEmpty(t, bucketName, "bucket_name output is empty")
    require.NotEmpty(t, cloudfrontURL, "cloudfront_url output is empty")
    assert.Contains(t, apiGateway, "execute-api", "api_gateway_url does not look like an API Gateway URL")
    assert.Contains(t, rdsEndpoint, "rds.amazonaws.com", "rds_endpoint does not look like an RDS endpoint")
}
