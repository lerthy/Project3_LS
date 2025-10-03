#!/bin/bash

# Package disaster recovery Lambda function
echo "📦 Packaging disaster recovery Lambda function..."

cd "$(dirname "$0")"

# Create temp directory
rm -rf temp_package
mkdir temp_package

# Copy Python file
cp disaster_recovery.py temp_package/

# Create zip file
cd temp_package
zip -r ../disaster_recovery.zip .

# Cleanup
cd ..
rm -rf temp_package

echo "✅ Lambda package created: disaster_recovery.zip"
