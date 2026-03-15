#!/bin/bash
set -e

echo "Fetching secrets from AWS SSM..."

# Added @sh to the jq filter to properly escape values with spaces or symbols
# This ensures that a password like "My P@ssword!" doesn't break the shell script
eval $(aws ssm get-parameters-by-path --path "/lookit/" --with-decryption --recursive --region us-east-1 \
  | jq -r '.Parameters[] | "export \((.Name | split("/") | last | ascii_upcase))=\(.Value|@sh)"')

echo "Secrets loaded. Rendering templates with confd..."

# Backend 'env' is the key here—it's fast and avoids the credential chain error
confd -onetime -backend env

# The DB_HOST and DB_PORT variables should now be available from the export above
if [ -n "$DB_HOST" ] && [ -n "$DB_PORT" ]; then
    echo "Checking connection to database at $DB_HOST:$DB_PORT..."
    until nc -z -v -w30 $DB_HOST $DB_PORT; do
      echo "Waiting for database to be ready..."
      sleep 2
    done
fi

echo "Running migrations..."
python3 lookit/manage.py migrate --noinput
python3 lookit/manage.py collectstatic --noinput

echo "Starting Django server..."
# Using 'exec' ensures the Django process becomes PID 1, 
# which is required for Kubernetes to stop the pod gracefully.
exec python3 lookit/manage.py runserver 0.0.0.0:8000
