#!/bin/bash
set -e

echo "Fetching secrets from AWS SSM..."

# This command fetches all parameters under /lookit/, 
# converts them to UPPERCASE env variables, and exports them.
export $(aws ssm get-parameters-by-path --path "/lookit/" --with-decryption --recursive --region us-east-1 \
  | jq -r '.Parameters[] | "\((.Name | split("/") | last | ascii_upcase))=\(.Value)"')

echo "Secrets loaded. Rendering templates with confd..."

# Change the backend to 'env' so confd doesn't try to talk to AWS
confd -onetime -backend env

# 2. Wait for DB (Good practice to avoid migration crashes)
# This assumes your DB_HOST and DB_PORT were rendered into the .env
# You might need to install 'netcat' in your Dockerfile for this
until nc -z $DB_HOST $DB_PORT; do
  echo "Waiting for database..."
  sleep 2
done

# 3. Run migrations
echo "Running migrations..."
python3 lookit/manage.py migrate
python3 lookit/manage.py collectstatic --noinput

# 4. Start server with EXEC
# This is crucial for graceful shutdowns in Kubernetes
echo "Starting Django server..."
exec python3 lookit/manage.py runserver 0.0.0.0:8000
