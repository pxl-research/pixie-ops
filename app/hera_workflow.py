class HeraWorkflow:
    """Interface for Hera workflows."""
    def submit(self, **kwargs):
        """Submit the workflow."""
        raise NotImplementedError