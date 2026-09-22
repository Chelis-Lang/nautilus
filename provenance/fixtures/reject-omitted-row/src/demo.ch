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
-- members = demo;extra
-- rows = demo:normative:NAUT-FIX-DEMO@xxh3-128:b387a37ccaf3946c5a6306a75ab6cc7a
def demo_surface_anchor(x: f32) -> f32 = x
