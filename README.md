# Composable Modpacks With Nix + packwiz

This repository lets you define reusable mod groups and compose multiple Modrinth/packwiz modpacks from those groups.

## Layout

- `modpacks.nix`: your source of truth for reusable groups and concrete modpack definitions.
- `lib/mk-packwiz-modpack.nix`: turns one modpack definition into a complete packwiz tree (`pack.toml`, `index.toml`, and `mods/*.pw.toml`).
- `flake.nix`: exposes each modpack as a build target under `packages.<system>.<name>`.

## Define Groups And Packs

Edit `modpacks.nix`.

1. Add reusable mods and groups under `groups`.
1. Define each concrete modpack under `modpacks` with metadata, selected groups, and `extraMods`.

Each mod entry needs enough metadata for packwiz to work without running network calls inside `nix build`:

- `name`
- `filename`
- `download.url`
- `download.hashFormat` (typically `sha512`)
- `download.hash`
- `update.modrinth.projectId`
- `update.modrinth.versionId`

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
