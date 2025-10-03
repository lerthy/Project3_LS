#!/bin/bash

# Package hourly backup Lambda function
echo "📦 Packaging hourly backup Lambda function..."

cd "$(dirname "$0")"

# Create temp directory
rm -rf temp_package
mkdir temp_package

# Copy Python file
cp hourly_backup.py temp_package/

# Create zip file
cd temp_package
zip -r ../hourly_backup.zip .

# Cleanup
cd ..
rm -rf temp_package

echo "✅ Lambda package created: hourly_backup.zip"
