import os
from fastapi import FastAPI, BackgroundTasks
import subprocess
import uuid
from metaflow import Flow, Run, Runner
from metaflow.integrations import ArgoEvent

app = FastAPI()

os.environ['METAFLOW_DATASTORE_SYSROOT_LOCAL'] = '/metaflow-data'
os.environ['METAFLOW_PRODUCTION_TOKEN'] = 'your-production-token'

@app.get("/")
def read_root():
    return {"message": "FastAPI is running and ready to start a Metaflow flow."}

# This does not work
@app.get("/start_flow")
def start_flow():
    """
    Starts a new run of the HelloFlow.
    """
    try:
        # Set Metaflow environment variables for the runner
        os.environ['METAFLOW_USER'] = 'fastapi-user'
        os.environ['METAFLOW_PRODUCTION_TOKEN'] = 'your-production-token' # Replace with a real token if needed
        os.environ['METAFLOW_KUBERNETES_ENABLED'] = 'true'
        os.environ['METAFLOW_KUBERNETES_SECRETS'] = 'metaflow-secrets'
        os.environ['METAFLOW_SERVICE_URL'] = 'http://metadata:8080' # Use the service name defined in Metaflow Dev
        os.environ['METAFLOW_S3_ROOT'] = 's3://metaflow-dev/data' # Use the bucket defined in Metaflow Dev

        event = ArgoEvent(name='ingest_trigger', payload={})
        event.publish()
        return {"message": "Pipeline trigger event published successfully."}
    except Exception as e:
        return {"status": "error", "message": f"An error occurred: {e}"}
    

# This works!
@app.post("/trigger")
def trigger_flow():
    run_uuid = str(uuid.uuid4())[:8]  # just for tracking on your side

    cmd = ["python", "hello_flow.py", "run"]
    process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = process.communicate()

    return {
        "status": "finished",
        "run_uuid": run_uuid,     # your own UUID, not Metaflow's run_id
        "stdout": stdout.decode(),
        "stderr": stderr.decode(),
        "exit_code": process.returncode,
    }