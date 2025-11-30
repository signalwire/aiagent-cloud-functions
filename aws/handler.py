#!/usr/bin/env python3
"""AWS Lambda handler for SignalWire Hello World agent.

This demonstrates deploying a SignalWire AI Agent to AWS Lambda
with SWAIG functions and SWML output.

Environment variables:
    SWML_BASIC_AUTH_USER: Basic auth username (optional)
    SWML_BASIC_AUTH_PASSWORD: Basic auth password (optional)
"""

import os
from signalwire_agents import AgentBase, SwaigFunctionResult


class HelloWorldAgent(AgentBase):
    """Hello World agent for AWS Lambda deployment."""

    def __init__(self):
        super().__init__(name="hello-world-lambda")

        self._configure_prompts()
        self.add_language("English", "en-US", "rime.spore")
        self._setup_functions()

    def _configure_prompts(self):
        self.prompt_add_section(
            "Role",
            "Hello World demonstration agent for AWS Lambda serverless deployment."
        )

        self.prompt_add_section(
            "Capabilities",
            bullets=[
                "Greet users by name",
                "Provide AWS Lambda deployment information",
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
                f"Hello {name}! Welcome to SignalWire on AWS Lambda."
            )

        @self.tool(description="Get AWS Lambda deployment information")
        def get_platform_info(args, raw_data):
            region = os.getenv("AWS_REGION", "unknown")
            function_name = os.getenv("AWS_LAMBDA_FUNCTION_NAME", "unknown")
            memory = os.getenv("AWS_LAMBDA_FUNCTION_MEMORY_SIZE", "unknown")
            runtime = os.getenv("AWS_EXECUTION_ENV", "unknown")

            return SwaigFunctionResult(
                f"Running on AWS Lambda. "
                f"Function: {function_name}, Region: {region}, "
                f"Memory: {memory}MB, Runtime: {runtime}."
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


def lambda_handler(event, context):
    """AWS Lambda entry point.

    Args:
        event: Lambda event (API Gateway request)
        context: Lambda context with runtime info

    Returns:
        API Gateway response dict
    """
    return agent.run(event, context)
