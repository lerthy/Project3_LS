#!/bin/bash

# List of databases to delete (keep contact-db-fb49b77e)
DATABASES_TO_DELETE=(
  "contact-db-049fbbee"
  "contact-db-05d2eb79" 
  "contact-db-112457ec"
  "contact-db-3089de82"
  "contact-db-4255103c"
  "contact-db-4f39d114"
  "contact-db-8f1ed8b5"
  "contact-db-c5cbcf31"
  "contact-db-f56a602c"
  "contact-db-f67107ab"
)

echo "🗑️  Cleaning up unused RDS databases..."
echo "⚠️  Keeping: contact-db-fb49b77e (current production database)"
echo ""

for db in "${DATABASES_TO_DELETE[@]}"; do
  echo "Deleting database: $db"
  aws rds delete-db-instance \
    --db-instance-identifier "$db" \
    --skip-final-snapshot \
    --delete-automated-backups
  
  if [ $? -eq 0 ]; then
    echo "✅ Deletion initiated for $db"
  else
    echo "❌ Failed to delete $db"
  fi
  echo ""
done

echo "🏁 Database cleanup completed!"
echo "💡 Note: Deletions are asynchronous and may take a few minutes to complete."
