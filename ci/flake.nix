{
  description = "Nautilus CI tooling";

  inputs = {
    llm-agents.url = "github:numtide/llm-agents.nix/5cefe9e186d79d89abd38b3a225d8eb3b6d64ae3";
    nixpkgs.follows = "llm-agents/nixpkgs";
  };

  outputs =
    { nixpkgs, llm-agents, ... }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      toolingFor =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          openspec = llm-agents.packages.${system}.openspec;
          launcherText =
            builtins.replaceStrings
              [
                "@python@"
                "@git@"
                "@openspec@"
              ]
              [
                "${pkgs.python3}/bin/python3"
                "${pkgs.git}/bin/git"
                "${openspec}/bin/openspec"
              ]
              (builtins.readFile ./openspec_gate.py);
          openspecGate = pkgs.writeTextFile {
            name = "nautilus-openspec-gate";
            destination = "/bin/openspec-gate";
            executable = true;
            text = launcherText;
          };
        in
        {
          inherit openspec openspecGate;
        };
    in
    {
      packages = forAllSystems (
        system:
        let
          tooling = toolingFor system;
        in
        {
          inherit (tooling) openspec;
          openspec-gate = tooling.openspecGate;
          default = tooling.openspecGate;
        }
      );

      apps = forAllSystems (
        system:
        let
          tooling = toolingFor system;
        in
        {
          openspec = {
            type = "app";
            program = "${tooling.openspec}/bin/openspec";
          };
          openspec-gate = {
            type = "app";
            program = "${tooling.openspecGate}/bin/openspec-gate";
          };
          default = {
            type = "app";
            program = "${tooling.openspecGate}/bin/openspec-gate";
          };
        }
      );
    };
}
