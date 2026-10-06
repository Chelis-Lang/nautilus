module Nautilus.Tests.CoreVersion
import Nautilus.Core (version)
import Std.Test (assert_true)
def test_core_version_matches_candidate() -> unit ! { Test } = assert_true(eq(version(), "0.7.50"), "Core.version reports the candidate package version")
