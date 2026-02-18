{
  description = "Pure Nix environment for connectwithawalsh.com/dns-scheduler";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-darwin"
        "aarch64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
      forEachSystem =
        f: nixpkgs.lib.genAttrs supportedSystems (system: f (import nixpkgs { inherit system; }));

      # Helper to create a shell with specific env files
      mkEnvShell =
        pkgs: envName: envFiles:
        pkgs.mkShell {
          packages = with pkgs; [
            go
            opentofu
          ];

          shellHook = ''
            echo "❄️ Entering Nix environment: ${envName}"

            # Load specified environment files
            for f in ${builtins.concatStringsSep " " envFiles}; do
              if [ -f "$f" ]; then
                echo "  - Loading $f"
                export $(grep -v '^#' "$f" | xargs)
              else
                echo "  - Skipping $f (not found)"
              fi
            done

            # Validation logic
            if [ -z "$GCP_PROJECT_ID" ]; then
              echo "⚠️  Warning: GCP_PROJECT_ID is not set"
            fi

            if [ -z "$NEXTDNS_API_KEY" ]; then
              echo "⚠️  Warning: NEXTDNS_API_KEY is not set"
            fi

            if [ -z "$NEXTDNS_PROFILE_ID_0" ]; then
              echo "⚠️  Warning: NEXTDNS_PROFILE_ID_0 is not set"
            fi

            if [ -z "$NEXTDNS_PROFILE_ID_1" ]; then
              echo "⚠️  Warning: NEXTDNS_PROFILE_ID_1 is not set"
            fi

            echo "Tools: $(go version | cut -d' ' -f1-3)"
            echo "Tools: $(tofu version | cut -d' ' -f1-3)"
          '';
        };
    in
    {
      devShells = forEachSystem (pkgs: {
        # Entry point: nix develop .#local
        local = mkEnvShell pkgs "local" [
          ".env_common.env"
          ".env_local.env"
        ];

        # Entry point: nix develop .#prod
        prod = mkEnvShell pkgs "prod" [
          ".env_common.env"
          ".env_prod.env"
        ];

        # Default is local
        default = self.devShells.${pkgs.system}.local;
      });
    };
}
