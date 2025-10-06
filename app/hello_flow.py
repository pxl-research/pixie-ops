from hera.workflows import Workflow, DAG, script
from hera.shared import global_config
from hera_workflow import HeraWorkflow

@script()
def echo(message: str):
    """Simple Hera script that prints a message."""
    print(message)


class HelloFlow(HeraWorkflow):
    """Hera DAG workflow with a diamond pattern."""

    def __init__(self, namespace: str = "argo"):
        self.namespace = namespace

    def submit(self):
        """Create and submit the DAG workflow to Argo."""
        with Workflow(
            generate_name="dag-diamond-",
            entrypoint="diamond",
            namespace=self.namespace,
            ttl_seconds_after_finished=3600,  # workflow auto-cleanup after 1h
        ) as w:
            with DAG(name="diamond"):
                A = echo(name="A", arguments={"message": "A"})
                B = echo(name="B", arguments={"message": "B"})
                C = echo(name="C", arguments={"message": "C"})
                D = echo(name="D", arguments={"message": "D"})
                A >> [B, C] >> D

        # Submit workflow
        submitted = w.create()
        service = w.workflows_service
        name = submitted.metadata.name
        namespace = submitted.metadata.namespace

        # Wait for completion
        final_workflow = service.wait_for_workflow(name=name, namespace=namespace)
        status = final_workflow.status.phase

        # Optionally, cleanup
        # service.delete_workflow(name=name, namespace=namespace)

        return {
            "workflow_name": name,
            "namespace": namespace,
            "status": status,
        }
