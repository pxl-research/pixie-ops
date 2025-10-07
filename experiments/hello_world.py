from hera.workflows import Workflow, WorkflowsService, DAG, script

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
        token=None,
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
submitted_workflow = w.create(wait=True, poll_interval=2)

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