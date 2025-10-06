from fastapi import FastAPI, HTTPException
from hera.shared import global_config
from hello_flow import HelloFlow  # Import your HelloFlow class
import urllib3

# Disable SSL warnings for local Argo dev
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Configure Hera / Argo connection
global_config.host = "https://localhost:2746"
global_config.verify_ssl = False
global_config.token = None

app = FastAPI()


@app.get("/")
def read_root():
    return {"message": "FastAPI is running and ready to start a workflow."}
  

@app.post("/trigger")
def trigger_workflow():
    """Trigger the HelloFlow DAG workflow."""
    try:
        flow = HelloFlow()
        result = flow.submit()  # submits the workflow and waits for completion
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to trigger workflow: {e}")


@app.get("/health")
def health():
    return {"status": "ok"}
