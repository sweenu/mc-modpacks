{ lib, groups }:
{
  modpacks = {
    creabblemon = {
      name = "Creabblemon";
      author = "sweenu";
      version = "26.03.151913";

      minecraftVersion = "1.21.1";
      loader = "neoforge";
      loaderVersion = "21.1.219";

      groups = with groups.neoforge; [
        optimization
        utilities
        worldgen
        decoration
        create
        cobblemon
      ];
    };
    creabblemon-fabric = {
      name = "Creabblemon-fabric";
      author = "sweenu";
      version = "26.03.151913";

      minecraftVersion = "1.20.1";
      loader = "fabric";
      loaderVersion = "0.18.4";

      groups = with groups.fabric; [
        optimization
        utilities
        decoration
        create
        cobblemon
      ];
    };
  };
}
