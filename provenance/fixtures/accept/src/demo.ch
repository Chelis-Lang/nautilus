module Nautilus.Fixture.Demo
-- chelis:provenance/v1 authority
-- id = NAUT-FIX-DEMO
-- kind = behavioral
-- scopes = nautilus-fixture
-- statement = Fixture modules MUST stay governed by the demo surface.
def demo(x: f32) -> f32 = x
-- chelis:provenance/v1 surface
-- id = NAUT-FIX-SURFACE
-- member-key-schema = nautilus-module-key/v1
-- disposition-schema = nautilus-module-disposition/v1
-- generation = 1
-- members = demo
-- rows = demo:normative:NAUT-FIX-DEMO@blake3-256:821b576e3dbad6200a5362f16713a7b65fc3d5f238453749f846ccd58aef49e0
def demo_surface_anchor(x: f32) -> f32 = x
