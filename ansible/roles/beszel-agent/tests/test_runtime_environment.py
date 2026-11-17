import base64
import unittest
from pathlib import Path

import yaml
from jinja2 import Environment


class RuntimeEnvironmentTests(unittest.TestCase):
    @classmethod
    def setUpClass(test_class):
        manifest = Path(__file__).resolve().parents[1] / "tasks" / "main.yml"
        tasks = yaml.safe_load(manifest.read_text())
        expression = next(
            task
            for task in tasks
            if task["name"] == "Verify the running agent uses the declared hub URL"
        )["ansible.builtin.assert"]["that"][0]
        environment = Environment()
        environment.filters["b64decode"] = lambda value: base64.b64decode(
            value
        ).decode()
        test_class.template = environment.from_string("{{ " + expression + " }}")

    def test_accepts_declared_hub_environment_variable(self):
        result = self.template.render(
            beszel_hub_url="https://beszel.saikat.dev",
            beszel_agent_runtime_environment={
                "content": base64.b64encode(
                    b"TOKEN=fixture\x00HUB_URL=https://beszel.saikat.dev\x00"
                ).decode()
            },
        )
        self.assertEqual(result, "True")

    def test_rejects_old_hub_and_token_substring(self):
        for contents in (
            b"TOKEN=fixture\x00HUB_URL=https://beszel.saikat.oleole.ai\x00",
            b"TOKEN=HUB_URL=https://beszel.saikat.dev\x00",
        ):
            with self.subTest(contents=contents):
                result = self.template.render(
                    beszel_hub_url="https://beszel.saikat.dev",
                    beszel_agent_runtime_environment={
                        "content": base64.b64encode(contents).decode()
                    },
                )
                self.assertEqual(result, "False")


if __name__ == "__main__":
    unittest.main()
