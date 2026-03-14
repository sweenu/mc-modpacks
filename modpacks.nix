{ lib }:

let
  # Reusable constructor for Modrinth-backed packwiz mod entries.
  mkModrinthMod =
    {
      name,
      filename,
      url,
      sha512,
      projectId,
      versionId,
      side ? "both",
      key ? null,
      pwFile ? null,
    }:
    {
      inherit
        name
        filename
        side
        ;

      download = {
        inherit url;
        hashFormat = "sha512";
        hash = sha512;
      };

      update = {
        modrinth = {
          inherit projectId versionId;
        };
      };
    }
    // lib.optionalAttrs (key != null) { inherit key; }
    // lib.optionalAttrs (pwFile != null) { inherit pwFile; };

  mods = rec {
    ferriteCore = mkModrinthMod {
      name = "FerriteCore";
      filename = "ferritecore-6.0.1-fabric.jar";
      url = "https://cdn.modrinth.com/data/uXXizFIs/versions/unerR5MN/ferritecore-6.0.1-fabric.jar";
      sha512 = "9b7dc686bfa7937815d88c7bbc6908857cd6646b05e7a96ddbdcada328a385bd4ba056532cd1d7df9d2d7f4265fd48bd49ff683f217f6d4e817177b87f6bc457";
      projectId = "uXXizFIs";
      versionId = "unerR5MN";
      key = "ferrite-core";
      pwFile = "ferrite-core.pw.toml";
    };

    lithium = mkModrinthMod {
      name = "Lithium";
      filename = "lithium-fabric-mc1.20.1-0.11.4.jar";
      url = "https://cdn.modrinth.com/data/gvQqBUqZ/versions/iEcXOkz4/lithium-fabric-mc1.20.1-0.11.4.jar";
      sha512 = "31938b7e849609892ffa1710e41f2e163d11876f824452540658c4b53cd13c666dbdad8d200989461932bd9952814c5943e64252530c72bdd5d8641775151500";
      projectId = "gvQqBUqZ";
      versionId = "iEcXOkz4";
    };
  };
in
{
  groups = {
    base = [
      mods.ferriteCore
      mods.lithium
    ];

    terrain = [
      # Add terrain generation mods here.
    ];

    create = [
      # Add Create ecosystem mods here.
    ];
  };

  modpacks = {
    vanilla-plus = {
      name = "Vanilla+";
      author = "sweenu";
      version = "1.0.0";

      minecraftVersion = "1.20.1";
      loader = "fabric";
      loaderVersion = "0.15.11";

      groups = [
        "base"
        "terrain"
      ];

      extraMods = [
        # Add one-off mods for this pack that are not in reusable groups.
      ];
    };

    create-plus = {
      name = "Create+";
      author = "sweenu";
      version = "1.0.0";

      minecraftVersion = "1.20.1";
      loader = "fabric";
      loaderVersion = "0.15.11";

      groups = [
        "base"
        "create"
      ];

      extraMods = [ ];
    };
  };
}
