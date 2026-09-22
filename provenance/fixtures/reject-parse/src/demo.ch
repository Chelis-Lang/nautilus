module Nautilus.Fixture.Demo
-- chelis:provenance/v1 authority
-- id = NAUT-FIX-PARSE
-- kind = behavioral
-- scopes = nautilus-fixture
-- statement = A source outside the canonical Surf surface MUST fail loudly.
def demo(x: f32) -> f32 = 0.5 |> fn (p) -> cast(p, f32) |> mul(x)
