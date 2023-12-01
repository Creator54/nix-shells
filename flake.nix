{
  description = "My personal collection of nix-shells";
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
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells = {
        java = pkgs.mkShell {
          name = "java";
          buildInputs = [
            pkgs.openjdk11
            (pkgs.gradle.override { java = pkgs.openjdk11; })
          ];

          shellHook = ''
            if [ -n "$IN_NIX_SHELL" ]; then
              java --version
              gradle --version
            fi
            export JAVA_HOME=$(readlink -f $(which java) | xargs dirname | xargs dirname)
          '';
        };

        python = pkgs.mkShell {
          name = "python";
          buildInputs = [ pkgs.python310 ];

          shellHook = ''
            set -h #remove "bash: hash: hashing disabled" warning !
            SOURCE_DATE_EPOCH=$(date +%s)
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ pkgs.zlib pkgs.stdenv.cc.cc ]}":LD_LIBRARY_PATH;
            eval "$extras"

            if ! [ -d .venv ]; then
              python -m venv .venv
            fi

            source .venv/bin/activate

            python -m pip install --cache-dir=$TMPDIR --upgrade pip

            export TMPDIR=/tmp

            if [ -e requirements.txt ]; then
              pip install --cache-dir=$TMPDIR -r requirements.txt
            fi
          '';
          extras = ''
            pymod() {
            	pip list
            }

            pyadd() {
            	for pkg in "$@"; do
            		if ! grep -q "$pkg" requirements.txt; then
                  if pip install --cache-dir=$TMPDIR "$pkg"; then
                    version=$(pip list | grep $pkg | xargs | cut -d ' ' -f2)
            				echo "$pkg==$version" >>requirements.txt
                  fi
            		fi
            	done
            }

            pyrm() {
            	if [ $# -eq 0 ] && [ -e ./requirements.txt ] && [ -s ./requirements.txt ]; then
            		pkg=$(cat requirements.txt | fzf)
            		if [ -n "$pkg" ]; then
            			grep -v "$pkg" requirements.txt >requirements.tmp
            			mv requirements.tmp requirements.txt
            			pip uninstall "$pkg" -y
            		fi
            	else
            		for pkg in "$@"; do
            			grep -v "$pkg" requirements.txt >requirements.tmp
            			mv requirements.tmp requirements.txt
            			pip uninstall "$pkg" -y
            		done
            	fi
            }

            if [ -n "$IN_NIX_SHELL" ]; then
            	echo "Extra Functions:"
            	echo "pymod : Show a list of installed Python packages."
            	echo "pyadd : Add packages to requirements.txt and install them."
            	echo "pyrm  : Remove packages from requirements.txt and uninstall them."
            fi
          '';
        };
      };
    }
  );
}

