from hera.workflows import Workflow, WorkflowsService, DAG, script
from shared.hera_workflow import HeraWorkflow
import os
from dotenv import load_dotenv

load_dotenv()

ARGO_WORKFLOWS_SERVER = os.getenv("ARGO_WORKFLOWS_SERVER")

@script()
def echo(message: str):
    """Simple Hera script that prints a message."""
    print(message)


class HelloFlow(HeraWorkflow):
    """Hera DAG workflow with a diamond pattern."""

    def __init__(self, namespace: str = "argo", host: str = ARGO_WORKFLOWS_SERVER):
        self.namespace = namespace
        self.host = host
        self.generate_name = "dag-diamond-"
        self.entrypoint = "diamond"
        self.ttl_seconds_after_finished = 3600

    def submit(self):
        """Create and submit the DAG workflow to Argo."""
        with Workflow(
            generate_name=self.generate_name,
            entrypoint=self.entrypoint,
            namespace=self.namespace,
            ttl_seconds_after_finished=self.ttl_seconds_after_finished,
            workflows_service=WorkflowsService(
                host=self.host,
                token=None,
                namespace=self.namespace
            )
        ) as w:
            with DAG(name="diamond"):
                A = echo(name="A", arguments={"message": "A"})
                B = echo(name="B", arguments={"message": "B"})
                C = echo(name="C", arguments={"message": "C"})
                D = echo(name="D", arguments={"message": "D"})
                A >> [B, C] >> D

        # Submit workflow
        submitted_workflow = w.create(wait=True, poll_interval=2)
        workflow_name = submitted_workflow.metadata.name
        namespace = submitted_workflow.metadata.namespace
        status = submitted_workflow.status.phase

        '''
        submitted = w.create()
        service = w.workflows_service
        name = submitted.metadata.name
        namespace = submitted.metadata.namespace

        # Wait for completion
        final_workflow = service.wait_for_workflow(name=name, namespace=namespace)
        status = final_workflow.status.phase
        
        # Optionally, cleanup
        # service.delete_workflow(name=name, namespace=namespace)
        '''

        return {
            "workflow_name": workflow_name,
            "namespace": namespace,
            "status": status,
        }
