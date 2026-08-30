module Nautilus.Tests_Neg.LinAlg.Unsupported_Element_Type_Neg
import Nautilus.LinAlg (det_2x2)
import Std.Test (assert_close)
-- chelis:provenance/v1 carrier
-- id = NAUT-CARRIER-LINALG-NEGATIVE
-- role = negative
-- atoms = NAUT-MOD-LINALG@xxh3-128:49dca51dd2b5269319d41eaa1523c417
-- item-digest = xxh3-128:5ac56cd4d01ef98ab4922ce007877912
-- oracle-id = NAUT-GATE-CHELIS-TEST
-- oracle-digest = xxh3-128:b5a32db6d41c30665962063a6052d0a5
-- configuration-digest = xxh3-128:ae3dfc4c0cfdd00cc99d50805da0931e
-- scope-schema = nautilus-carrier-scope/v1
-- scope = the pinned unsupported-element-type rejection in tests_neg/linalg
def unsupported_int_matrix(a: tensor[2, 2, int64]) -> f32 = det_2x2(a)
def test_negative_linalg_unsupported_element_type() -> unit ! { Test } = assert_close(cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), "should not reach here")
