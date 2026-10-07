# Installation

Nautilus 0.7.50 is a Reef package for Chelis 0.19.1. Install Chelis from the
[official releases](https://chelis.ch/docs/chelis/install/), using the compiler version
required by the Nautilus release.

Add Nautilus to your project's `[dependencies]` table in `reef.toml`:

```toml
[dependencies]
nautilus = { version = "0.7.50" }
```

Set the project's `compiler` pin to `"=0.19.1"`. From the project directory,
run:

```sh
chelis reef setup
chelis reef build
```

Reef downloads Nautilus and its declared dependencies from their releases. A
Nautilus source checkout is needed only if you want to inspect or modify the
library itself.

Continue with [Your first Nautilus program](first-program.md)
to evaluate a calculation. The [Reef and packages guide](https://chelis.ch/docs/chelis/reef/)
covers dependency setup and compiler compatibility.
