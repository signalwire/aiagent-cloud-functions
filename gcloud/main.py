#!/usr/bin/env python3
"""Google Cloud Functions handler for SignalWire Hello World agent.

This demonstrates deploying a SignalWire AI Agent to Google Cloud Functions
with SWAIG functions and SWML output.

Environment variables:
    SWML_BASIC_AUTH_USER: Basic auth username (optional)
    SWML_BASIC_AUTH_PASSWORD: Basic auth password (optional)
"""

import os
from signalwire_agents import AgentBase, SwaigFunctionResult


class HelloWorldAgent(AgentBase):
    """Hello World agent for Google Cloud Functions deployment."""

    def __init__(self):
        super().__init__(name="hello-world-gcloud")

        self._configure_prompts()
        self.add_language("English", "en-US", "rime.spore")
        self._setup_functions()

    def _configure_prompts(self):
        self.prompt_add_section(
            "Role",
            "Hello World demonstration agent for Google Cloud Functions serverless deployment."
        )

        self.prompt_add_section(
            "Capabilities",
            bullets=[
                "Greet users by name",
                "Provide Google Cloud deployment information",
                "Echo back messages"
            ]
        )

    def _setup_functions(self):
        @self.tool(
            description="Say hello to a user",
            parameters={
                "type": "object",
                "properties": {
                    "name": {
                        "type": "string",
                        "description": "Name of the person to greet"
                    }
                },
                "required": ["name"]
            }
        )
        def say_hello(args, raw_data):
            name = args.get("name", "World")
            return SwaigFunctionResult(
                f"Hello {name}! Welcome to SignalWire on Google Cloud Functions."
            )

        @self.tool(description="Get Google Cloud deployment information")
        def get_platform_info(args, raw_data):
            import urllib.request

            # Gen 2 Cloud Functions run on Cloud Run with these env vars
            service = os.getenv("K_SERVICE", "unknown")
            revision = os.getenv("K_REVISION", "unknown")

            # Query metadata server for project ID (Cloud Run doesn't set GOOGLE_CLOUD_PROJECT)
            project = os.getenv("GOOGLE_CLOUD_PROJECT", "unknown")
            if project == "unknown":
                try:
                    req = urllib.request.Request(
                        "http://metadata.google.internal/computeMetadata/v1/project/project-id",
                        headers={"Metadata-Flavor": "Google"}
                    )
                    with urllib.request.urlopen(req, timeout=2) as resp:
                        project = resp.read().decode()
                except Exception:
                    pass

            # Query metadata server for memory limit
            memory = "unknown"
            try:
                req = urllib.request.Request(
                    "http://metadata.google.internal/computeMetadata/v1/instance/attributes/MEMORY_LIMIT",
                    headers={"Metadata-Flavor": "Google"}
                )
                with urllib.request.urlopen(req, timeout=2) as resp:
                    memory = resp.read().decode()
            except Exception:
                # Memory not available via metadata, check env
                memory = os.getenv("MEMORY_LIMIT", "512Mi")

            return SwaigFunctionResult(
                f"Running on Google Cloud Functions Gen 2. "
                f"Service: {service}, Revision: {revision}, "
                f"Project: {project}, Memory: {memory}."
            )

        @self.tool(
            description="Echo back a message",
            parameters={
                "type": "object",
                "properties": {
                    "message": {
                        "type": "string",
                        "description": "Message to echo back"
                    }
                },
                "required": ["message"]
            }
        )
        def echo(args, raw_data):
            message = args.get("message", "")
            return SwaigFunctionResult(f"You said: {message}")


# Create agent instance outside handler for warm starts
agent = HelloWorldAgent()


def main(request):
    """Google Cloud Functions entry point.

    Args:
        request: Flask request object

    Returns:
        Flask response
    """
    return agent.run(request)
