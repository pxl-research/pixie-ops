# Use the official PostgreSQL image as a lightweight base
FROM postgres:18-alpine

# Copy the initialization SQL script into the default bootstrap directory so
# the database schema is created automatically on first run.
# NOTE: Build context is not the current folder, but apps (previous folder)
COPY database_server/init.sql /docker-entrypoint-initdb.d/init.sql

EXPOSE 5432

# The image defaults to port 5432 and requires the following environment variables
# to be set when running/deploying:
# - POSTGRES_USER
# - POSTGRES_PASSWORD
# - POSTGRES_DB
