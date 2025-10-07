#!/bin/bash

CONNECTION_ARN="arn:aws:codestar-connections:eu-north-1:791544005401:connection/ca0bd438-6bf9-40b2-82ee-d6f9ff4329b4"

echo "🔍 Monitoring GitHub CodeStar Connection Status..."
echo "Connection ARN: $CONNECTION_ARN"
echo "Direct Link: https://eu-north-1.console.aws.amazon.com/conesuite/settings/connections"
echo ""

while true; do
    STATUS=$(aws codestar-connections get-connection --connection-arn "$CONNECTION_ARN" --region eu-north-1 --query 'Connection.ConnectionStatus' --output text 2>/dev/null)
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [ "$STATUS" = "AVAILABLE" ]; then
        echo "[$TIMESTAMP] Status: ✅ AVAILABLE"
        echo ""
        echo "🎉 SUCCESS! GitHub connection is now AVAILABLE!"
        echo "Your CI/CD pipelines should now work properly."
        echo ""
        echo "Next steps:"
        echo "1. Go to CodePipeline console to check pipeline status"
        echo "2. Make a test commit to trigger the pipeline"
        break
    elif [ "$STATUS" = "PENDING" ]; then
        echo "[$TIMESTAMP] Status: 🟡 PENDING"
        echo "   👆 Please complete the connection setup in AWS Console:"
        echo "   https://eu-north-1.console.aws.amazon.com/codesuite/settings/connections"
    else
        echo "[$TIMESTAMP] Status: ❌ $STATUS"
    fi
    
    echo "   (Checking again in 10 seconds... Press Ctrl+C to stop)"
    echo ""
    sleep 10
done
