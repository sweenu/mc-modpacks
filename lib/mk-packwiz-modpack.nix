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

  fail = msg: throw "Invalid modpack `${modpackName}`: ${msg}";

  tomlFormat = pkgs.formats.toml { };

  renderToml = name: value: builtins.readFile (tomlFormat.generate name value);

  parseTomlFile = path: builtins.fromTOML (builtins.readFile path);

  getAttrOrNull = attrs: name: if builtins.hasAttr name attrs then builtins.getAttr name attrs else null;

  renderModSource = mod: mod.source or "unknown source";

  modIdentityKey = mod: if mod.projectId != null then "modrinth:${mod.projectId}" else "filename:${mod.filename}";

  modCompatibilitySignature =
    mod:
    lib.concatStringsSep "|" [
      mod.filename
      (mod.projectId or "")
      (mod.versionId or "")
      (mod.side or "both")
      mod.download.url
      mod.download.hashFormat
      mod.download.hash
    ];

  validateAndNormalizeLegacyMod =
    mod:
    let
      source = "modpacks.nix extraMods entry `${mod.name or mod.filename or "<unnamed>"}`";
      checks = [
        (require (mod ? name) "${source} is missing `name`")
        (require (mod ? filename) "${source} is missing `filename`")
        (require (mod ? download) "${source} is missing `download`")
        (require (mod.download ? url) "${source} is missing `download.url`")
        (require (mod.download ? hashFormat) "${source} is missing `download.hashFormat`")
        (require (mod.download ? hash) "${source} is missing `download.hash`")
      ];

      projectId =
        if mod ? update && mod.update ? modrinth then
          mod.update.modrinth.projectId or null
        else
          null;

      versionId =
        if mod ? update && mod.update ? modrinth then
          mod.update.modrinth.versionId or null
        else
          null;
    in
    builtins.deepSeq checks {
      inherit source projectId versionId;
      name = mod.name;
      filename = mod.filename;
      side = mod.side or "both";
      pwFile = mod.pwFile or null;
      download = {
        url = mod.download.url;
        hashFormat = mod.download.hashFormat;
        hash = mod.download.hash;
        mode = mod.download.mode or "url";
      };
    };

  loadGroupFromPackwiz =
    groupName: groupPath:
    let
      groupRoot = toString groupPath;

      packTomlPath = "${groupRoot}/pack.toml";

      checks = [
        (require (builtins.pathExists packTomlPath) "group `${groupName}` points to `${groupRoot}` but `${packTomlPath}` is missing")
      ];

      packToml = parseTomlFile packTomlPath;
      versions =
        if packToml ? versions then
          packToml.versions
        else
          fail "group `${groupName}` (${groupRoot}) is missing `[versions]` in pack.toml";

      groupMinecraft = versions.minecraft or (fail "group `${groupName}` (${groupRoot}) is missing `versions.minecraft` in pack.toml");
      loaderAttrs = builtins.removeAttrs versions [ "minecraft" ];
      loaderNames = builtins.attrNames loaderAttrs;

      versionChecks = [
        (
          require (builtins.length loaderNames == 1) (
            "group `${groupName}` (${groupRoot}) must define exactly one loader in `versions` (found: "
            + (if loaderNames == [ ] then
                 "none"
               else
                 lib.concatStringsSep ", " loaderNames)
            + ")"
          )
        )
      ];

      groupLoader = builtins.head loaderNames;
      groupLoaderVersion = builtins.getAttr groupLoader loaderAttrs;

      compatibilityChecks = [
        (
          require (groupMinecraft == cfg.minecraftVersion) (
            "group `${groupName}` (${groupRoot}) minecraft version mismatch: expected `${cfg.minecraftVersion}` but found `${groupMinecraft}`"
          )
        )
        (
          require (groupLoader == cfg.loader) (
            "group `${groupName}` (${groupRoot}) loader mismatch: expected `${cfg.loader}` but found `${groupLoader}`"
          )
        )
        (
          require (groupLoaderVersion == cfg.loaderVersion) (
            "group `${groupName}` (${groupRoot}) loader version mismatch for `${cfg.loader}`: expected `${cfg.loaderVersion}` but found `${groupLoaderVersion}`"
          )
        )
      ];

      indexFile =
        if packToml ? index && packToml.index ? file then
          packToml.index.file
        else
          "index.toml";

      indexTomlPath = "${groupRoot}/${indexFile}";
      indexChecks = [
        (require (builtins.pathExists indexTomlPath) "group `${groupName}` (${groupRoot}) references index `${indexFile}` but `${indexTomlPath}` does not exist")
      ];

      indexToml = parseTomlFile indexTomlPath;
      files = indexToml.files or [ ];

      modFileEntries = builtins.filter (
        entry:
        (entry.metafile or false)
        && entry ? file
        && lib.hasSuffix ".pw.toml" entry.file
      ) files;

      normalizeModEntry =
        entry:
        let
          modRelativePath = entry.file;
          modPath = "${groupRoot}/${modRelativePath}";
          source = "group `${groupName}` file `${modRelativePath}`";

          presenceChecks = [
            (require (builtins.pathExists modPath) "${source} is listed in `${indexFile}` but `${modPath}` does not exist")
          ];

          rawToml = builtins.deepSeq presenceChecks (builtins.readFile modPath);
          modToml = builtins.fromTOML rawToml;

          modChecks = [
            (require (modToml ? name) "${source} is missing `name`")
            (require (modToml ? filename) "${source} is missing `filename`")
            (require (modToml ? download) "${source} is missing `[download]`")
            (require (modToml.download ? url) "${source} is missing `download.url`")
            (require (modToml.download ? hash) "${source} is missing `download.hash`")
            (require (builtins.hasAttr "hash-format" modToml.download) "${source} is missing `download.hash-format`")
          ];

          modrinthUpdate =
            if modToml ? update && modToml.update ? modrinth then
              modToml.update.modrinth
            else
              { };

          projectId = (modrinthUpdate."mod-id" or null);
          versionId = (modrinthUpdate.version or null);

          updateChecks = [
            (
              require (
                (projectId == null && versionId == null)
                || (projectId != null && versionId != null)
              ) "${source} must set both `update.modrinth.mod-id` and `update.modrinth.version` together"
            )
          ];
        in
          builtins.deepSeq (modChecks ++ updateChecks) {
            inherit source projectId versionId rawToml;
            name = modToml.name;
            filename = modToml.filename;
            side = modToml.side or "both";
            pwFile = builtins.baseNameOf modRelativePath;
            download = {
              url = modToml.download.url;
              hashFormat = modToml.download."hash-format";
              hash = modToml.download.hash;
              mode = modToml.download.mode or "url";
            };
          };
    in
    builtins.deepSeq (checks ++ versionChecks ++ compatibilityChecks ++ indexChecks)
      (map normalizeModEntry modFileEntries);

  requiredChecks = [
    (require (cfg ? name) "missing `name`")
    (require (cfg ? version) "missing `version`")
    (require (cfg ? groups) "missing `groups`")
    (require (cfg ? minecraftVersion) "missing `minecraftVersion`")
    (require (cfg ? loader) "missing `loader`")
    (require (cfg ? loaderVersion) "missing `loaderVersion`")
    (require (builtins.length (cfg.groups or [ ]) > 0) "`groups` must contain at least one group")
  ];

  selectedGroups = cfg.groups or [ ];

  flattenGroupDefs =
    pathLabel: groupDef:
    let
      groupType = builtins.typeOf groupDef;
    in
    if groupType == "path" || groupType == "string" then
      [
        {
          path = pathLabel;
          value = groupDef;
        }
      ]
    else if groupType == "list" then
      builtins.concatLists (
        lib.imap0 (
          idx: nestedGroupDef: flattenGroupDefs "${pathLabel}.${toString (idx + 1)}" nestedGroupDef
        ) groupDef
      )
    else
      fail (
        "`groups` entry `${pathLabel}` must be a path/string or nested list of paths; got `${groupType}` instead"
      );

  flattenedGroups = builtins.concatLists (
    lib.imap0 (
      idx: groupDef: flattenGroupDefs "#${toString (idx + 1)}" groupDef
    ) selectedGroups
  );

  resolvedGroupChecks = [
    (require (builtins.length flattenedGroups > 0) "`groups` must resolve to at least one group path")
  ];

  groupMods = builtins.deepSeq resolvedGroupChecks (
    builtins.concatLists (
      map (
        groupRef:
        loadGroupFromPackwiz "${groupRef.path} `${toString groupRef.value}`" groupRef.value
      ) flattenedGroups
    )
  );

  extraMods = map validateAndNormalizeLegacyMod (cfg.extraMods or [ ]);

  allMods = groupMods ++ extraMods;

  mergeState =
    lib.foldl'
      (
        state: mod:
        let
          identity = modIdentityKey mod;
          existingByIdentity = getAttrOrNull state.byIdentity identity;
          existingByFilename = getAttrOrNull state.byFilename mod.filename;
          signature = modCompatibilitySignature mod;

          identityConflict =
            if existingByIdentity != null && modCompatibilitySignature existingByIdentity != signature then
              [
                (
                  "conflicting definitions for `${identity}`: `${renderModSource existingByIdentity}` vs `${renderModSource mod}`;"
                  + " existing uses filename `${existingByIdentity.filename}`, version `${existingByIdentity.versionId or "<none>"}`, hash `${existingByIdentity.download.hash}`"
                  + " while new uses filename `${mod.filename}`, version `${mod.versionId or "<none>"}`, hash `${mod.download.hash}`"
                )
              ]
            else
              [ ];

          filenameConflict =
            if existingByFilename != null && modIdentityKey existingByFilename != identity then
              [
                "filename collision on `${mod.filename}` between `${renderModSource existingByFilename}` (identity `${modIdentityKey existingByFilename}`) and `${renderModSource mod}` (identity `${identity}`)"
              ]
            else
              [ ];

          shouldInsert = existingByIdentity == null && existingByFilename == null;
        in
        {
          byIdentity = if shouldInsert then state.byIdentity // { "${identity}" = mod; } else state.byIdentity;
          byFilename = if shouldInsert then state.byFilename // { "${mod.filename}" = mod; } else state.byFilename;
          errors = state.errors ++ identityConflict ++ filenameConflict;
        }
      )
      {
        byIdentity = { };
        byFilename = { };
        errors = [ ];
      }
      allMods;

  mergeConflictCheck =
    if mergeState.errors == [ ] then
      null
    else
      fail (
        "mod compatibility conflicts detected while merging groups:\n"
        + lib.concatMapStringsSep "\n" (msg: "  - ${msg}") mergeState.errors
      );

  deduplicatedMods = builtins.attrValues mergeState.byIdentity;

  mkModFileName =
    mod:
    if mod ? pwFile then
      mod.pwFile
    else
      "${lib.strings.sanitizeDerivationName (lib.toLower (mod.name or "mod"))}.pw.toml";

  mkModToml =
    mod:
    let
      modToml = {
        name = mod.name;
        filename = mod.filename;
        side = mod.side or "both";

        download = {
          url = mod.download.url;
          hash = mod.download.hash;
          "hash-format" = mod.download.hashFormat;
          mode = mod.download.mode or "url";
        };
      };
    in
    renderToml "mod-${mkModFileName mod}" (
      modToml
      // lib.optionalAttrs (mod.projectId != null && mod.versionId != null) {
        update = {
          modrinth = {
            "mod-id" = mod.projectId;
            version = mod.versionId;
          };
        };
      }
    );

  modEntries = map (
    mod:
    let
      relativePath = "mods/${mkModFileName mod}";
      content = if mod ? rawToml then mod.rawToml else mkModToml mod;
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
  builtins.deepSeq mergeConflictCheck
  ''
    mkdir -p "$out/mods"

    cp ${packTomlPath} "$out/pack.toml"
    cp ${indexTomlPath} "$out/index.toml"
  ''
  + lib.concatMapStringsSep "\n" (entry: ''
    cp ${entry.contentPath} "$out/${entry.file}"
  '') modEntries
))
