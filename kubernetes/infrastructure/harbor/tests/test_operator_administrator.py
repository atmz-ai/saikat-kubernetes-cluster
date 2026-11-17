import ast
import unittest
from pathlib import Path

import yaml


class OperatorAdministratorTests(unittest.TestCase):
    @classmethod
    def setUpClass(test_class):
        manifest = Path(__file__).resolve().parents[1] / "operator-administrator.yaml"
        job = yaml.safe_load(manifest.read_text())
        program = ast.parse(job["spec"]["template"]["spec"]["containers"][0]["args"][0])
        selector = next(
            node
            for node in program.body
            if isinstance(node, ast.FunctionDef) and node.name == "select_operator"
        )
        test_class.selector_namespace = {}
        exec(
            compile(
                ast.Module(body=[selector], type_ignores=[]), str(manifest), "exec"
            ),
            test_class.selector_namespace,
        )

    def setUp(self):
        self.operator = {
            "user_id": 2,
            "username": "saikat@atmz.ai",
            "email": "saikat@atmz.ai",
            "sysadmin_flag": False,
        }

    def test_selects_exact_operator_with_or_without_existing_grant(self):
        for administrator in (False, True):
            with self.subTest(administrator=administrator):
                operator = dict(self.operator, sysadmin_flag=administrator)
                result = self.selector_namespace["select_operator"](
                    [operator], "saikat@atmz.ai"
                )
                self.assertEqual(result, operator)

    def test_rejects_unsafe_operator_lookup(self):
        for scenario, users in (
            ("missing-user", []),
            ("ambiguous-user", [self.operator, self.operator]),
            ("another-email", [dict(self.operator, email="another@atmz.ai")]),
            ("another-username", [dict(self.operator, username="admin")]),
            ("invalid-identifier", [dict(self.operator, user_id=True)]),
            (
                "missing-administrator-status",
                [
                    {
                        key: value
                        for key, value in self.operator.items()
                        if key != "sysadmin_flag"
                    }
                ],
            ),
        ):
            with self.subTest(scenario=scenario), self.assertRaises(ValueError):
                self.selector_namespace["select_operator"](users, "saikat@atmz.ai")


if __name__ == "__main__":
    unittest.main()
