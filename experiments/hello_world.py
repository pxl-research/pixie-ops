from hera.workflows import Workflow, WorkflowsService, DAG, script
from hera.auth import ArgoCLITokenGenerator
import urllib3
import subprocess

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

def get_argo_token(namespace: str = "argo", service_account: str = "hera-submitter") -> str:
    """
    Generates a Bearer token for a Kubernetes service account using kubectl.
    Equivalent to:
        ARGO_TOKEN="Bearer $(kubectl create token hera-submitter -n argo)"

    Returns:
        str: The full 'Bearer <token>' string.
    Raises:
        RuntimeError: If the token cannot be created.
    """
    try:
        token = subprocess.check_output(
            ["kubectl", "create", "token", service_account, "-n", namespace],
            stderr=subprocess.STDOUT,
        ).strip().decode()

        return f"Bearer {token}"

    except subprocess.CalledProcessError as e:
        raise RuntimeError(
            f"Failed to generate Argo token: {e.output.decode().strip()}"
        ) from e


@script()
def echo(message: str):
    print(message)


with Workflow(
    generate_name="dag-diamond-",
    entrypoint="diamond",
    namespace="argo",
    ttl_seconds_after_finished=3600,
    workflows_service=WorkflowsService(
        host="http://localhost:2746",
        token=get_argo_token(namespace="argo"),
        verify_ssl=False,
        namespace="argo"
    )
) as w:
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