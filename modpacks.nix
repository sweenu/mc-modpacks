{ lib, groups }:
{
  modpacks = {
    creabblemon = {
      name = "Creabblemon";
      author = "sweenu";
      version = "26.03.150750";

      minecraftVersion = "1.21.1";
      loader = "neoforge";
      loaderVersion = "21.1.219";

      groups = with groups; [
        optimization
        utilities
        worldgen
        decoration
        create
      ];
    };
  };
}
