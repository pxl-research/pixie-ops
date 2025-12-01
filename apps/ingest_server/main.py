import os
import time
import uuid
import threading
from typing import Any
from fastapi import FastAPI, HTTPException, Response, status, BackgroundTasks
import psycopg2 as pg
from psycopg2 import extras
from pydantic import BaseModel, Field
from hello_flow import HelloFlow

# from qdrant_client import QdrantClient
# from qdrant_client.models import Distance, VectorParams, PointStruct, CountRequest
# from sentence_transformers import SentenceTransformer

# -----------------------------
# In-memory workflow status store
# -----------------------------
workflow_status: dict[str, dict[str, Any]] = {}  # {workflow_id: {"status": "running|completed|failed", "result": Any}}

app = FastAPI()

DB_HOST = os.environ.get("POSTGRES_HOST", "db-service-name")
DB_NAME = os.environ.get("POSTGRES_DB", "pixie_db")
DB_USER = os.environ.get("POSTGRES_USER", "user")
DB_PASS = os.environ.get("POSTGRES_PASSWORD", "password")
DB_PORT = os.environ.get("POSTGRES_PORT", "5432")

QDRANT_HOST = os.getenv("QDRANT_HOST", "qdrant")
QDRANT_PORT = int(os.getenv("QDRANT_PORT", 6333))
COLLECTION = os.getenv("QDRANT_COLLECTION", "pixie_vectors")
MODEL_NAME = os.getenv("EMBEDDING_MODEL", "sentence-transformers/all-MiniLM-L6-v2")
VECTOR_SIZE = int(os.getenv("VECTOR_SIZE", 384))
# qdrant_client = QdrantClient(host=QDRANT_HOST, port=QDRANT_PORT)
# if COLLECTION not in qdrant_client.get_collections().collections:
#     qdrant_client.create_collection(
#         collection_name=COLLECTION,
#         vectors_config=VectorParams(size=VECTOR_SIZE, distance=Distance.DOT),
#     )
#embedder = SentenceTransformer(MODEL_NAME)

def dummy_embed(text: str) -> list[float]:
    """
    Constant test embedding.
    Always returns the same vector to validate plumbing.
    """
    return [0.1] * VECTOR_SIZE

class DataItem(BaseModel):
    name: str = Field(..., max_length=100)
    value: float

class VectorItem(BaseModel):
    text: str
    metadata: dict = {}

class SearchRequest(BaseModel):
    query: str
    limit: int = 5

def get_db_connection():
    """Establishes and returns a psycopg2 connection object."""
    try:
        conn = pg.connect(
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
curl -X POST \
  http://localhost/ingest/write-data \
  -H "Content-Type: application/json" \
  -d '{"name": "flow_rate_a", "value": 12.5}'; echo
'''
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
        raise
    except Exception as e:
        # Rollback the transaction on any other error
        if conn:
            conn.rollback()
        print(f"Database write error: {e}")
        raise HTTPException(500, detail=str(e))
    finally:
        if conn:
            conn.close()


'''
curl http://localhost/ingest/read-data; echo
'''
@app.get("/read-data", response_model=list[dict[str, Any]])
def read_data():
    """
    Reads all records from the 'flow_data' table and returns them as a list of dictionaries.
    """
    conn = None
    records = []
    try:
        conn = get_db_connection()
        # RealDictCursor to fetch results as dictionaries instead of tuples
        with conn.cursor(cursor_factory=extras.RealDictCursor) as cur:
            cur.execute("SELECT id, name, value, created_at FROM flow_data ORDER BY created_at DESC;")
            records = cur.fetchall()
        return records
    except HTTPException:
        raise
    except Exception as e:
        print(f"Database read error: {e}")
        raise HTTPException(status_code=500, detail=f"Database read failed: {e}")
    finally:
        if conn:
            conn.close()

'''
curl -X POST http://localhost/ingest/write-vector \
-H "Content-Type: application/json" \
-d '{
  "text": "Pump A is running at 12.5 psi",
  "metadata": {"sensor": "pump_a"}
}'; echo
'''
# @app.post("/write-vector", status_code=201)
# def write_vector(item: VectorItem):
#     try:
#         # vector = embedder.encode(item.text).tolist()
#         vector = dummy_embed(item.text)
#         point_id = str(uuid.uuid4())
#
#         qdrant_client.upsert(
#             collection_name=COLLECTION,
#             wait=True,
#             points=[
#                 PointStruct(id=point_id, vector=vector, payload={"text": item.text, "metadata": item.metadata}),
#             ]
#         )
#
#         return {
#             "status": "success",
#             "id": point_id,
#             "message": "Vector written to Qdrant"
#         }
#
#     except Exception as e:
#         raise HTTPException(status_code=500, detail=str(e))

'''
curl -X POST http://localhost/ingest/search-vectors \
-H "Content-Type: application/json" \
-d '{
  "query": "pressure from pump",
  "limit": 3
}'; echo
'''
# @app.post("/search-vectors")
# def search_vectors(data: SearchRequest):
#     try:
#         # query_vector = embedder.encode(data.query).tolist()
#         query_vector = dummy_embed(data.query)
#
#         search_result = qdrant_client.query_points(
#             collection_name=COLLECTION,
#             query=query_vector,
#             with_payload=True,
#             limit=3
#         ).points
#
#         return search_result
#
#     except Exception as e:
#         raise HTTPException(status_code=500, detail=str(e))


@app.get("/")
def read_root():
    return {"message": "FastAPI is running and ready to start a workflow."}

def run_workflow(workflow_id: str):
    try:
        workflow_status[workflow_id] = {"status": "running", "result": None}
        # Simulate long-running work
        time.sleep(61)
        flow = HelloFlow(namespace="pixie")
        result = flow.submit()
        workflow_status[workflow_id] = {"status": "completed", "result": result}
    except Exception as e:
        workflow_status[workflow_id] = {"status": "failed", "result": str(e)}

@app.post("/trigger")
def trigger_workflow(background_tasks: BackgroundTasks, status_code=status.HTTP_202_ACCEPTED):
    workflow_id = str(uuid.uuid4())
    # Schedule the workflow in the background
    background_tasks.add_task(run_workflow, workflow_id)
    # Return immediately to the client
    return {"workflow_id": workflow_id, "status": "submitted", "message": "Workflow is running asynchronously"}


@app.get("/status/{workflow_id}")
def workflow_status_endpoint(workflow_id: str):
    info = workflow_status.get(workflow_id)
    if info is None:
        raise HTTPException(status_code=404, detail="Workflow not found")
    if info["status"] in ["completed", "failed"]:
        del workflow_status[workflow_id]

    return {"workflow_id": workflow_id, "status": info["status"], "result": info["result"]}

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
    # NOTE: Here you put result status based on other dependencies such as databases.
    global is_healthy
    if is_healthy:
        response.status_code = 200
        return {"status": "ok"}
    response.status_code = 503
    return {"status": "unhealthy"}
