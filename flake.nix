{
  description = "Composable Minecraft modpacks for Modrinth with packwiz + Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;

        config = import ./modpacks.nix { inherit lib; };
        mkPackwizModpack = import ./lib/mk-packwiz-modpack.nix { inherit lib pkgs; };

        modpackPackages = lib.mapAttrs (name: cfg: mkPackwizModpack name cfg config.groups) config.modpacks;

        modrinthToNix = pkgs.writeShellApplication {
          name = "modrinth-to-nix";
          runtimeInputs = [
            pkgs.curl
            pkgs.jq
          ];
          text = ''
            set -euo pipefail

            if [[ $# -ne 1 ]]; then
              echo "Usage: modrinth-to-nix <version-id>" >&2
              echo "Example: modrinth-to-nix vY5e0Y2S" >&2
              exit 1
            fi

            version_id="$1"
            version_json="$(curl -fsSL "https://api.modrinth.com/v2/version/$version_id")"

            file_json="$(echo "$version_json" | jq -er '.files[] | select(.primary == true) // .files[0]')"

            project_id="$(echo "$version_json" | jq -er '.project_id')"
            version_number="$(echo "$version_json" | jq -er '.version_number')"
            filename="$(echo "$file_json" | jq -er '.filename')"
            url="$(echo "$file_json" | jq -er '.url')"
            hash_sha512="$(echo "$file_json" | jq -er '.hashes.sha512')"

            cat <<EOF
            {
              name = "$version_number";
              filename = "$filename";
              side = "both";
              download = {
                url = "$url";
                hashFormat = "sha512";
                hash = "$hash_sha512";
              };
              update = {
                modrinth = {
                  projectId = "$project_id";
                  versionId = "$version_id";
                };
              };
            }
            EOF
          '';
        };
      in
      {
        packages =
          {
            default = pkgs.linkFarm "modpacks" (
              lib.mapAttrsToList (name: drv: {
                name = name;
                path = drv;
              })
              modpackPackages
            );
            modrinth-to-nix = modrinthToNix;
          }
          // modpackPackages;

        apps = {
          modrinth-to-nix = {
            type = "app";
            program = "${modrinthToNix}/bin/modrinth-to-nix";
          };
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            packwiz
            jq
            curl
          ];
        };
      }
    );
}
