module Nautilus.Fixture.Compact
-- chelis:provenance/v1 authority
-- id = NAUT-FIX-COMPACT
-- kind = behavioral
-- scopes = nautilus-fixture
-- statement = Compact fixture declarations MUST retain one stored implementation relation.
def compact_requirement(x: f32) -> f32 = x
-- chelis:provenance/v1 binding
-- record = blake3-256:ee0b4b79be1ec115d93d817ddb25415beeda90e8cbe3e8d55fb5d57b296844e2
def compact_implementation(x: f32) -> f32 = add(x, x)
-- chelis:provenance/v1 surface
-- id = NAUT-FIX-COMPACT-SURFACE
-- member-key-schema = nautilus-module-key/v1
-- disposition-schema = nautilus-module-disposition/v1
-- generation = 1
-- members = compact
-- rows = compact:normative:NAUT-FIX-COMPACT@blake3-256:f3c1bbaeed3234c117008d47211263a48b0aedc275b980f443230823131bb5d1
def compact_surface_anchor(x: f32) -> f32 = x
