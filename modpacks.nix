{ lib, groups }:
{
  modpacks = {
    vanilla-plus = {
      name = "Vanilla+";
      author = "sweenu";
      version = "1.0.0";

      minecraftVersion = "1.20.1";
      loader = "fabric";
      loaderVersion = "0.15.11";

      groups = with groups; [
        base
        terrain
      ];

      extraMods = [
        # Optional legacy inline entries still supported for one-off mods.
      ];
    };

    create-plus = {
      name = "Create+";
      author = "sweenu";
      version = "1.0.0";

      minecraftVersion = "1.20.1";
      loader = "fabric";
      loaderVersion = "0.15.11";

      groups = with groups; [
        base
        create
      ];

      extraMods = [ ];
    };
  };
}
