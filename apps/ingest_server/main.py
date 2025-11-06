import os
import time
from typing import Any
from fastapi import FastAPI, HTTPException, Response
import psycopg2 as pg
from pydantic import BaseModel, Field
from hello_flow import HelloFlow  # Import your HelloFlow class

app = FastAPI()

DB_HOST = os.environ.get("POSTGRES_HOST", "db-service-name")
DB_NAME = os.environ.get("POSTGRES_DB", "workflow_db")
DB_USER = os.environ.get("POSTGRES_USER", "postgres_user")
DB_PASS = os.environ.get("POSTGRES_PASSWORD", "postgres_password")
DB_PORT = os.environ.get("POSTGRES_PORT", "5432")

class DataItem(BaseModel):
    name: str = Field(..., max_length=100)
    value: float

def get_db_connection():
    """Establishes and returns a psycopg2 connection object."""
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASS,
            port=DB_PORT
        )
        return conn
    except Exception as e:
        print(f"Database connection failed: {e}")
        # Raising an HTTPException here will automatically convert it to a 500 status
        raise HTTPException(
            status_code=503,
            detail=f"Database service unavailable: Could not connect to {DB_HOST}"
        )

'''
@app.on_event("startup")
async def startup_event():
    """Initializes the database table if it doesn't exist."""
    conn = None
    try:
        conn = get_db_connection()
        # Use a non-dictionary cursor for setup
        with conn.cursor() as cur:
            cur.execute("""
                CREATE TABLE IF NOT EXISTS flow_data (
                    id SERIAL PRIMARY KEY,
                    name VARCHAR(100) NOT NULL,
                    value NUMERIC(10, 2) NOT NULL,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                );
            """)
        conn.commit()
        print("Database table 'flow_data' checked/created successfully.")
    except Exception as e:
        print(f"Error during database startup check: {e}")
        # Note: Do not raise HTTPException in startup event, as it prevents app start
    finally:
        if conn:
            conn.close()

@app.post("/write-data", status_code=201)
def write_data(data: DataItem):
    """
    Inserts a single row of data (name and value) into the 'flow_data' table.
    Uses a transaction to ensure atomicity.
    """
    conn = None
    try:
        conn = get_db_connection()
        # Use a standard cursor for writing
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO flow_data (name, value) VALUES (%s, %s);",
                (data.name, data.value)
            )
        conn.commit()
        return {"status": "success", "message": "Data written to PostgreSQL successfully"}

    except HTTPException:
        # Re-raise the connection error if it occurred
        raise
    except Exception as e:
        # Rollback the transaction on any other error
        if conn:
            conn.rollback()
        print(f"Database write error: {e}")
        raise HTTPException(status_code=500, detail=f"Database write failed: {e}")
    finally:
        if conn:
            conn.close()


@app.get("/read-data", response_model=list[dict[str, Any]])
def read_data():
    """
    Reads all records from the 'flow_data' table and returns them as a list of dictionaries.
    """
    conn = None
    records = []
    try:
        conn = get_db_connection()
        # Use RealDictCursor to fetch results as dictionaries instead of tuples
        with conn.cursor(cursor_factory=extras.RealDictCursor) as cur:
            cur.execute("SELECT id, name, value, created_at FROM flow_data ORDER BY created_at DESC;")
            records = cur.fetchall()
        return records
    except HTTPException:
        # Re-raise the connection error if it occurred
        raise
    except Exception as e:
        print(f"Database read error: {e}")
        raise HTTPException(status_code=500, detail=f"Database read failed: {e}")
    finally:
        if conn:
            conn.close()
'''


@app.get("/")
def read_root():
    return {"message": "FastAPI is running and ready to start a workflow."}

@app.post("/trigger")
def trigger_workflow():
    try:
        flow = HelloFlow()
        result = flow.submit()  # submits the workflow and waits for completion
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to trigger workflow: {e}")


# -----------------------------
# Liveness and readiness checks
# -----------------------------
is_healthy: bool = True

@app.get("/livez")
def livez(response: Response) -> dict[str, str]:
    """
    Liveness Probe Endpoint.
    Not dependant on dependencies such as databases.
    Returns 200 OK with {"status": "ok"} if the application is considered healthy,
    or 503 Service Unavailable with {"status": "unhealthy"} if the health state
    has been manually set to False. The HTTP status code is set explicitly.
    """
    global is_healthy
    if is_healthy:
        response.status_code = 200
        return {"status": "ok"}
    response.status_code = 503
    return {"status": "unhealthy"}


@app.get("/readyz")
def readyz(response: Response) -> dict[str, str]:
    # NOTE: Include result status based on other dependencies such as databases.
    global is_healthy
    if is_healthy:
        response.status_code = 200
        return {"status": "ok"}
    response.status_code = 503
    return {"status": "unhealthy"}
