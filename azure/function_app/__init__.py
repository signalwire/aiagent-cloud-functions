#!/usr/bin/env python3
"""Azure Functions handler for SignalWire Hello World agent.

This demonstrates deploying a SignalWire AI Agent to Azure Functions
with SWAIG functions and SWML output.

Environment variables:
    SWML_BASIC_AUTH_USER: Basic auth username (optional)
    SWML_BASIC_AUTH_PASSWORD: Basic auth password (optional)
"""

import os
import azure.functions as func
from signalwire_agents import AgentBase, SwaigFunctionResult


class HelloWorldAgent(AgentBase):
    """Hello World agent for Azure Functions deployment."""

    def __init__(self):
        super().__init__(name="hello-world-azure")

        self._configure_prompts()
        self.add_language("English", "en-US", "rime.spore")
        self._setup_functions()

    def _configure_prompts(self):
        self.prompt_add_section(
            "Role",
            "Hello World demonstration agent for Azure Functions serverless deployment."
        )

        self.prompt_add_section(
            "Capabilities",
            bullets=[
                "Greet users by name",
                "Provide Azure Functions deployment information",
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
                f"Hello {name}! Welcome to SignalWire on Azure Functions."
            )

        @self.tool(description="Get Azure Functions deployment information")
        def get_platform_info(args, raw_data):
            function_name = os.getenv("WEBSITE_SITE_NAME", "unknown")
            region = os.getenv("REGION_NAME", "unknown")
            runtime = os.getenv("FUNCTIONS_WORKER_RUNTIME", "unknown")
            version = os.getenv("FUNCTIONS_EXTENSION_VERSION", "unknown")

            return SwaigFunctionResult(
                f"Running on Azure Functions. "
                f"App: {function_name}, Region: {region}, "
                f"Runtime: {runtime}, Version: {version}."
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


def main(req: func.HttpRequest) -> func.HttpResponse:
    """Azure Functions entry point.

    Args:
        req: Azure Functions HTTP request object

    Returns:
        Azure Functions HTTP response
    """
    return agent.run(req)
