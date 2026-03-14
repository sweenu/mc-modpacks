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

        modrinthLatestToNix = pkgs.writeShellApplication {
          name = "modrinth-latest-to-nix";
          runtimeInputs = [
            pkgs.curl
            pkgs.jq
          ];
          text = ''
            set -euo pipefail

            if [[ $# -ne 3 ]]; then
              echo "Usage: modrinth-latest-to-nix <project-id-or-slug> <minecraft-version> <loader>" >&2
              echo "Example: modrinth-latest-to-nix sodium 1.20.1 fabric" >&2
              exit 1
            fi

            project="$1"
            mc_version="$2"
            loader="$3"

            versions_json="$(
              curl -fsSL --get \
                --data-urlencode "loaders=[\"$loader\"]" \
                --data-urlencode "game_versions=[\"$mc_version\"]" \
                "https://api.modrinth.com/v2/project/$project/version"
            )"

            if [[ "$(echo "$versions_json" | jq 'length')" -eq 0 ]]; then
              echo "No compatible version found for project=$project game_version=$mc_version loader=$loader" >&2
              exit 1
            fi

            version_json="$(echo "$versions_json" | jq -e '.[0]')"
            file_json="$(echo "$version_json" | jq -er '.files[] | select(.primary == true) // .files[0]')"

            version_id="$(echo "$version_json" | jq -er '.id')"
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
            modrinth-latest-to-nix = modrinthLatestToNix;
          }
          // modpackPackages;

        apps = {
          modrinth-to-nix = {
            type = "app";
            program = "${modrinthToNix}/bin/modrinth-to-nix";
          };

          modrinth-latest-to-nix = {
            type = "app";
            program = "${modrinthLatestToNix}/bin/modrinth-latest-to-nix";
          };
        };

        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.packwiz
            pkgs.jq
            pkgs.curl
            modrinthToNix
            modrinthLatestToNix
          ];
        };
      }
    );
}
