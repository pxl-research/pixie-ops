from hera.workflows import Workflow, Steps, script
from hera.shared import global_config

import os
import time
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

global_config.host = "https://localhost:2746" 
global_config.verify_ssl = False
global_config.token = None


@script()
def echo(message: str):
    """A simple function to print a message."""
    print(message)

with Workflow(
    generate_name="hello-world-",
    entrypoint="steps",
    namespace="argo", # The Kubernetes namespace where Argo Workflows is installed
) as w:
    with Steps(name="steps"):
        echo(arguments={"message": "Hello from Hera!"})

# This submits the workflow to Argo Workflows for execution
submitted_workflow = w.create()

# --- INTERACTING WITH THE LIVE WORKFLOW ---
# You need to access the execution-specific methods through the WorkflowsService.

# Get a reference to the service
service = w.workflows_service 
name = submitted_workflow.metadata.name
namespace = submitted_workflow.metadata.namespace


print(f"Waiting for workflow: {name} in namespace: {namespace}...")

# 1. 🔁 Wait for the workflow to complete using a polling loop
status = ""
while status not in ["Succeeded", "Failed", "Error"]:
    time.sleep(5)  # Wait 5 seconds between checks
    try:
        workflow = service.get_workflow(name=name, namespace=namespace)
        status = workflow.status.phase
        print(f"Current Status: {status}...")
    except Exception as e:
        print(f"Error checking status: {e}. Retrying...")
        status = "Error" # Break loop if a critical error occurs

# 2. Get the final status (already have it from the loop)
print(f"\nWorkflow Status: {status}")

# 3. Stream the logs for all nodes/steps
try:
    print("\nWorkflow Logs:")
    # This method is likely still correct for streaming logs
    service.get_logs(name=name, namespace=namespace)
except Exception as e:
    print(f"An error occurred while streaming logs: {e}")

# 4. Clean up (delete the workflow object from the cluster)
try:
    service.delete_workflow(name=name, namespace=namespace)
    print(f"\nWorkflow {name} deleted.")
except Exception as e:
    print(f"Could not delete workflow {name}: {e}")