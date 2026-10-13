module Nautilus.Tests.CoreVersion
import Nautilus.Core (version)
import Std.Test (assert_true)
def test_core_version_matches_candidate() -> unit ! { Test } = assert_true(eq(version(), "0.7.55"), "Core.version reports the candidate package version")
def test_core_version_is_not_previous_release() -> unit ! { Test } = assert_true(not(eq(version(), "0.7.54")), "Core.version does not report the previous package release")
