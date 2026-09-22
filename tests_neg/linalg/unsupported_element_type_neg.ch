module Nautilus.Tests_Neg.LinAlg.Unsupported_Element_Type_Neg
import Nautilus.LinAlg (det_2x2)
import Std.Test (assert_close)
-- chelis:provenance/v1 carrier
-- id = NAUT-CARRIER-LINALG-NEGATIVE
-- role = negative
-- atoms = NAUT-MOD-LINALG@blake3-256:469597a07dcc6f6d49c65ac83962454a47ff57d96f5a19a332cc13bafbce99fa
-- item-digest = blake3-256:31a62a2d28ba6db38cc6150959e121c7d9c1c59a2a916be2b64550bf9ba4a4f4
-- oracle-id = NAUT-GATE-CHELIS-TEST
-- oracle-digest = blake3-256:953753dd95e43c8c4e9ced041b437e1d18a38fca8d01cdcbb5a272da24d83081
-- configuration-digest = xxh3-128:ae3dfc4c0cfdd00cc99d50805da0931e
-- scope-schema = nautilus-carrier-scope/v1
-- scope = the pinned unsupported-element-type rejection in tests_neg/linalg
def unsupported_int_matrix(a: tensor[2, 2, i64]) -> f32 = det_2x2(a)
def test_negative_linalg_unsupported_element_type() -> unit ! { Test } = assert_close(cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), "should not reach here")
