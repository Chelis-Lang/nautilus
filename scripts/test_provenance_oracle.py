import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


class ProvenanceOracleTests(unittest.TestCase):
    def test_completed_runs_are_normalized_and_raw_output_is_only_stderr(self):
        oracle = Path(__file__).with_name("provenance_oracle.py")
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            binary = home / "bin/chelis"
            binary.parent.mkdir()
            for status in [0, 3]:
                binary.write_text(
                    f"#!{sys.executable}\nimport sys\n"
                    "assert sys.argv[1:] == ['test', 'tests/', '--timeout', '600', '--jobs', 'auto']\n"
                    "print('compiler stdout')\nprint('compiler stderr', file=sys.stderr)\n"
                    f"raise SystemExit({status})\n"
                )
                binary.chmod(0o755)
                result = subprocess.run(
                    [sys.executable, str(oracle)], env=dict(os.environ, CHELIS_HOME=str(home)),
                    capture_output=True, text=True,
                )
                self.assertEqual(result.returncode, 0)
                self.assertEqual(result.stdout, f"spec-provenance-result/v1\t{'pass' if status == 0 else 'fail'}\n")
                self.assertIn("compiler stdout", result.stderr)
                self.assertIn("compiler stderr", result.stderr)


if __name__ == "__main__":
    unittest.main()
