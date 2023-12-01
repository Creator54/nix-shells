{ nixpkgs ? import <nixpkgs> {}, ... }:

{
  java = import ./devShells/java.nix { pkgs = nixpkgs; };
  python = import ./devShells/python.nix { pkgs = nixpkgs; };
  selenium = import ./devShells/selenium.nix { pkgs = nixpkgs; };
}

