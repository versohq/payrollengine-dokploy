#!/bin/bash
set -e

echo "=== PayrollEngine DB Init ==="

# Download ModelCreate.sql from GitHub
echo "Downloading ModelCreate.sql from: $SQL_SOURCE_URL"
curl -fSL "$SQL_SOURCE_URL" -o /tmp/ModelCreate.sql

# Wait for SQL Server to be ready (max 2 minutes)
echo "Waiting for SQL Server..."
for i in $(seq 1 24); do
  /opt/mssql-tools18/bin/sqlcmd -S db -U sa -P "$DB_PASSWORD" -C -Q "SELECT 1" &>/dev/null && break
  echo "  Attempt $i/24: not ready, retrying in 5s..."
  sleep 5
done

# Verify connection
/opt/mssql-tools18/bin/sqlcmd -S db -U sa -P "$DB_PASSWORD" -C -Q "SELECT @@VERSION" || {
  echo "ERROR: Cannot connect to database"; exit 1;
}

# Create database if it doesn't exist
echo "Creating database if not exists..."
/opt/mssql-tools18/bin/sqlcmd -S db -U sa -P "$DB_PASSWORD" -C \
  -Q "IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'PayrollEngine') CREATE DATABASE PayrollEngine"

# Run creation script
echo "Running ModelCreate.sql..."
/opt/mssql-tools18/bin/sqlcmd -S db -U sa -P "$DB_PASSWORD" -C -d PayrollEngine -i /tmp/ModelCreate.sql

echo "=== Database initialization complete ==="
