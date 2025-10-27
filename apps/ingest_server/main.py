from fastapi import FastAPI, HTTPException, Response
from hello_flow import HelloFlow  # Import your HelloFlow class

app = FastAPI()


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
