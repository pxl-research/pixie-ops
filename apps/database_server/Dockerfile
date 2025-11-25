# Use the official PostgreSQL image as a lightweight base
FROM postgres:16-alpine

ENV PGDATA /var/lib/app/data
RUN mkdir -p ${PGDATA} \
    && chown -R postgres:postgres /var/lib/postgresql \
    && chown -R postgres:postgres ${PGDATA}


# Copy the initialization SQL script into the default bootstrap directory so
# the database schema is created automatically on first run.
# NOTE: Build context is not the current folder, but apps (previous folder)
COPY database_server/init.sql /docker-entrypoint-initdb.d/init.sql

EXPOSE 5432

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["postgres"]

# The image defaults to port 5432 and requires the following environment variables
# to be set when running/deploying:
# - POSTGRES_USER
# - POSTGRES_PASSWORD
# - POSTGRES_DB
