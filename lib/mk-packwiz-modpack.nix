{
  lib,
  pkgs,
}:

modpackName: cfg: groups:
let
  require =
    condition: msg:
    if condition then
      null
    else
      throw "Invalid modpack `${modpackName}`: ${msg}";

  tomlFormat = pkgs.formats.toml { };

  renderToml = name: value: builtins.readFile (tomlFormat.generate name value);

  requiredChecks = [
    (require (cfg ? name) "missing `name`")
    (require (cfg ? version) "missing `version`")
    (require (cfg ? minecraftVersion) "missing `minecraftVersion`")
    (require (cfg ? loader) "missing `loader`")
    (require (cfg ? loaderVersion) "missing `loaderVersion`")
  ];

  selectedGroups = cfg.groups or [ ];

  groupMods = builtins.concatLists (
    map (
      groupName:
      if builtins.hasAttr groupName groups then
        builtins.getAttr groupName groups
      else
        throw "Invalid modpack `${modpackName}`: unknown group `${groupName}`"
    ) selectedGroups
  );

  allMods = groupMods ++ (cfg.extraMods or [ ]);

  modKey =
    mod:
    if mod ? key then
      mod.key
    else if mod ? update && mod.update ? modrinth then
      "${mod.update.modrinth.projectId}:${mod.update.modrinth.versionId}"
    else
      throw "Mod `${mod.name or "<unnamed>"}` is missing `key` and `update.modrinth.{projectId,versionId}`";

  deduplicatedMods = builtins.attrValues (builtins.listToAttrs (map (mod: {
    name = modKey mod;
    value = mod;
  }) allMods));

  mkModFileName =
    mod:
    if mod ? pwFile then
      mod.pwFile
    else
      "${lib.strings.sanitizeDerivationName (lib.toLower (mod.name or "mod"))}.pw.toml";

  mkModToml =
    mod:
    renderToml "mod-${mkModFileName mod}" {
      name = mod.name;
      filename = mod.filename;
      side = mod.side or "both";

      download = {
        url = mod.download.url;
        hash = mod.download.hash;
        "hash-format" = mod.download.hashFormat;
        mode = mod.download.mode or "url";
      };

      update = {
        modrinth = {
          "mod-id" = mod.update.modrinth.projectId;
          version = mod.update.modrinth.versionId;
        };
      };
    };

  modEntries = map (
    mod:
    let
      relativePath = "mods/${mkModFileName mod}";
      content = mkModToml mod;
    in
    {
      file = relativePath;
      hash = builtins.hashString "sha256" content;
      contentPath = pkgs.writeText "${lib.replaceStrings [ "/" ] [ "-" ] relativePath}" content;
    }
  ) deduplicatedMods;

  indexToml = renderToml "${modpackName}-index.toml" {
    "hash-format" = "sha256";
    files = map (entry: {
      file = entry.file;
      hash = entry.hash;
      metafile = true;
    }) modEntries;
  };

  indexHash = builtins.hashString "sha256" indexToml;

  packToml = renderToml "${modpackName}-pack.toml" {
    name = cfg.name;
    author = cfg.author or "";
    version = cfg.version;
    "pack-format" = "packwiz:1.1.0";

    index = {
      file = "index.toml";
      "hash-format" = "sha256";
      hash = indexHash;
    };

    versions = {
      minecraft = cfg.minecraftVersion;
    } // {
      "${cfg.loader}" = cfg.loaderVersion;
    };
  };

  packTomlPath = pkgs.writeText "${modpackName}-pack.toml" packToml;
  indexTomlPath = pkgs.writeText "${modpackName}-index.toml" indexToml;
in
builtins.deepSeq requiredChecks (pkgs.runCommand "modpack-${modpackName}" { } (
  ''
    mkdir -p "$out/mods"

    cp ${packTomlPath} "$out/pack.toml"
    cp ${indexTomlPath} "$out/index.toml"
  ''
  + lib.concatMapStringsSep "\n" (entry: ''
    cp ${entry.contentPath} "$out/${entry.file}"
  '') modEntries
))
