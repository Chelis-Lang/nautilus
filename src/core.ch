module Nautilus.Core
export (version)
-- chelis:provenance/v1 authority
-- id = NAUT-MOD-CORE
-- kind = behavioral
-- scopes = nautilus
-- statement = Nautilus.Core MUST report the exact package version metadata.
def version() -> int32 = 1000
