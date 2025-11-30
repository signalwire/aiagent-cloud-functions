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
            # Gen 2 Cloud Functions run on Cloud Run with these env vars
            service = os.getenv("K_SERVICE", "unknown")
            revision = os.getenv("K_REVISION", "unknown")
            project = os.getenv("GOOGLE_CLOUD_PROJECT", os.getenv("GCLOUD_PROJECT", "unknown"))
            # Cloud Run sets memory limit in K8s format
            memory_limit = os.getenv("MEMORY_LIMIT", "unknown")

            return SwaigFunctionResult(
                f"Running on Google Cloud Functions Gen 2. "
                f"Service: {service}, Revision: {revision}, "
                f"Project: {project}, Memory: {memory_limit}."
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
    try:
        return agent.run(request, force_mode='google_cloud_function')
    except Exception as e:
        import traceback
        print(f"ERROR: {e}")
        print(f"TRACEBACK: {traceback.format_exc()}")
        raise
