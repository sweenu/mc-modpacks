# Composable Modpacks With Nix + packwiz

This repository lets you define reusable mod groups and compose multiple Modrinth/packwiz modpacks from those groups.

## Layout

- `modpacks.nix`: maps group names to local packwiz project directories and defines composed modpacks.
- `groups/<name>/`: standalone packwiz projects you can edit directly with `packwiz`.
- `lib/mk-packwiz-modpack.nix`: turns one modpack definition into a complete packwiz tree (`pack.toml`, `index.toml`, and `mods/*.pw.toml`).
- `flake.nix`: exposes each modpack as a build target under `packages.<system>.<name>`.

## Edit Groups With packwiz

Each group is a normal packwiz project, so you can work in that folder and run packwiz commands directly.

Example:

```bash
cd groups/base
packwiz modrinth add sodium
```

## Compose Groups With Nix

Edit `modpacks.nix`:

1. `flake.nix` auto-discovers group directories under `./groups` and passes them to `modpacks.nix` as `groups`.
1. Define each concrete modpack under `modpacks` by selecting group paths (for example `groups.base`, `groups.terrain`).
1. Optionally add one-off `extraMods` inline.

The merge is strict and fails early with explicit explanations if:

- A selected group is missing `pack.toml` or referenced mod metafiles.
- A group's Minecraft version differs from the modpack config.
- A group's loader or loader version differs from the modpack config.
- Two groups define the same mod identity with different version/hash/filename data.
- Two different mods collide on the same JAR filename.

## Build A Specific Modpack

```bash
nix build .#vanilla-plus
```

The output symlink (`./result`) contains a ready-to-use packwiz tree.

## Build All Modpacks

```bash
nix build .#default
```

This creates a directory of symlinks to each individual modpack output.

## Generate Nix Mod Entries From Modrinth

Use the helper app with a Modrinth **version ID**:

```bash
nix run .#modrinth-to-nix -- <version-id>
```

It prints a Nix attrset snippet you can paste into `modpacks.nix`.

Use the second helper to resolve the latest compatible version by project + game version + loader:

```bash
nix run .#modrinth-latest-to-nix -- <project-id-or-slug> <minecraft-version> <loader>
```

Example:

```bash
nix run .#modrinth-latest-to-nix -- sodium 1.20.1 fabric
```

## Optional Dev Shell

```bash
nix develop
```

Includes `packwiz`, `curl`, and `jq`.
