{
  description = "My personal collection of nix-shells";
  nixConfig.bash-prompt = "[nix(my-project)] ";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/69919a28af1c181dc84523b100a8ed45d4071304";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
  flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells = {
        git = import ./devShells/git.nix { inherit pkgs; };
        java = import ./devShells/java.nix { inherit pkgs; };
        python = import ./devShells/python.nix { inherit pkgs; };
        selenium = import ./devShells/selenium.nix { inherit pkgs; };
      };
    }
  );
}

