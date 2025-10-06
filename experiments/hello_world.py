from hera.workflows import Workflow, Steps, DAG, script
from hera.shared import global_config

import os
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

global_config.host = "https://localhost:2746" 
global_config.verify_ssl = False
global_config.token = os.environ["ARGO_TOKEN"]


@script()
def echo(message: str):
    """A simple function to print a message."""
    print(message)

'''
with Workflow(
    generate_name="hello-world-",
    entrypoint="steps",
    namespace="argo", # The Kubernetes namespace where Argo Workflows is installed
) as w:
    with Steps(name="steps"):
        echo(arguments={"message": "Hello from Hera!"})
'''


with Workflow(generate_name="dag-diamond-", entrypoint="diamond", namespace="argo", ttl_seconds_after_finished=3600) as w:
    with DAG(name="diamond"):
        A = echo(name="A", arguments={"message": "A"})
        B = echo(name="B", arguments={"message": "B"})
        C = echo(name="C", arguments={"message": "C"})
        D = echo(name="D", arguments={"message": "D"})

        A >> [B, C] >> D

# This submits the workflow to Argo Workflows for execution
submitted_workflow = w.create()

'''
# Get a reference to the service
service = w.workflows_service 
name = submitted_workflow.metadata.name
namespace = submitted_workflow.metadata.namespace

print(f"Waiting for workflow: {name} in namespace: {namespace}...")
w.wait(poll_interval=5)

# 4. Clean up (delete the workflow object from the cluster)
try:
    service.delete_workflow(name=name, namespace=namespace)
    print(f"\nWorkflow {name} deleted.")
except Exception as e:
    print(f"Could not delete workflow {name}: {e}")

'''