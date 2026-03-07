#!/bin/sh
set -e

# 1. Fetch from Secrets Manager and render .env
echo "Fetching secrets and rendering templates..."
/usr/local/bin/confd -onetime -backend ssm -node us-east-1

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

# 4. Start server with EXEC
# This is crucial for graceful shutdowns in Kubernetes
echo "Starting Django server..."
exec python3 lookit/manage.py runserver 0.0.0.0:8000
