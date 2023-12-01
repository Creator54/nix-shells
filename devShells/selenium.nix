{ pkgs }:

pkgs.mkShell rec {
  name = "selenium";
  venvDir = "./.venv";
  buildInputs = [ pkgs.python310 ];
  EDITOR = builtins.getEnv "EDITOR";
  PWD = builtins.getEnv "PWD";

  NIX_LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
    pkgs.stdenv.cc.cc
    pkgs.glib
    pkgs.openssl
    pkgs.nss
    pkgs.nspr
    pkgs.xorg.libxcb
  ];

  #https://discourse.nixos.org/t/devenv-nix-ld-throws-access-to-canonical-path-is-forbidden-in-restricted-mode/25076
  #need to pass --impure flag
  NIX_LD = pkgs.lib.fileContents "${pkgs.stdenv.cc}/nix-support/dynamic-linker";

  shellHook = ''
    set -h #remove "bash: hash: hashing disabled" warning !
    SOURCE_DATE_EPOCH=$(date +%s)

    if ! [ -d "${venvDir}" ]; then
      python -m venv "${venvDir}"
    fi
    source "${venvDir}/bin/activate"
    python -m pip install --upgrade pip
    pip install selenium
    if ! [[ -e $HOME/.local/bin/geckodriver ]]; then
      curl -s https://api.github.com/repos/mozilla/geckodriver/releases/latest | grep 'geckodriver-v[0-9].[0-9][0-9].[0-9]-linux64.tar.gz' | cut -d : -f 2,3 | tr -d \" | wget -qi -
      tar -xvzf geckodriver*tar.gz
      mkdir -p $HOME/.local/bin/
      mv geckodriver $HOME/.local/bin/
      rm -rf geckodriver*
    fi
    export PATH=$HOME/.local/bin:$PATH
  '';
}

