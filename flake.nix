{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";

    fenix.url = "github:nix-community/fenix";
    fenix.inputs.nixpkgs.follows = "nixpkgs";

    foundry.url = "github:shazow/foundry.nix/monthly";
    foundry.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      flake-parts,
      fenix,
      foundry,
      nixpkgs,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-linux"
      ];
      perSystem =
        { system, ... }:
        {
          # apply overlays to pkgs
          _module.args.pkgs = import nixpkgs {
            inherit system;
            overlays = [
              foundry.overlay
              fenix.overlays.default
            ];
          };

          imports = [
            ./nix/devshells.nix
          ];
        };
    };
}
