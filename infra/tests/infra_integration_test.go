package tests

import (
    "testing"

    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestInfra(t *testing.T) {
    t.Parallel()

    opts := &terraform.Options{
        TerraformDir: "../",
    }

    defer terraform.Destroy(t, opts)
    terraform.InitAndApply(t, opts)

    bucketName := terraform.Output(t, opts, "bucket_name")
    cloudfrontURL := terraform.Output(t, opts, "cloudfront_url")
    apiGateway := terraform.Output(t, opts, "api_gateway_url")
    rdsEndpoint := terraform.Output(t, opts, "rds_endpoint")

    assert.NotEmpty(t, bucketName)
    assert.NotEmpty(t, cloudfrontURL)
    assert.Contains(t, apiGateway, "execute-api")
    assert.Contains(t, rdsEndpoint, "rds.amazonaws.com")
}
