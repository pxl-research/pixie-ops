from fastapi import FastAPI
import subprocess
import uuid

app = FastAPI()


@app.get("/")
def read_root():
    return {"message": "FastAPI is running and ready to start a Metaflow flow."}
  

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


@app.get("/health")
def health():
    return {"status": "ok"}