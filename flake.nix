{
  description = "My-project build environment with multiple shells";
  nixConfig.bash-prompt = "[nix(my-project)] ";
  inputs = { 
    nixpkgs.url = "github:nixos/nixpkgs/69919a28af1c181dc84523b100a8ed45d4071304";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        sysPkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells = {
          java = sysPkgs.mkShell {
            name = "java";
            buildInputs = [
              sysPkgs.openjdk11
              (sysPkgs.gradle.override { java = sysPkgs.openjdk11; })
            ];

            shellHook = ''
              if [ -n "$IN_NIX_SHELL" ]; then
                java --version
                gradle --version
              fi
              export JAVA_HOME=$(readlink -f $(which java) | xargs dirname | xargs dirname)
            '';
          };

          python = sysPkgs.mkShell {
            name = "python";
            buildInputs = [ sysPkgs.python310 ];

            shellHook = ''
              if ! [ -d .venv ]; then
                python -m venv .venv
              fi

              source .venv/bin/activate

              python -m pip install --cache-dir=$TMPDIR --upgrade pip

              if [ -e requirements.txt ]; then
                pip install --cache-dir=$TMPDIR -r requirements.txt
              fi
            '';
          };
        };
      }
    );
}

