{ pkgs }:

pkgs.mkShell {
  name = "python-3.9";
  buildInputs = [ 
    pkgs.python39
    pkgs.fzf
    (pkgs.writeShellScriptBin "pymod" ''
      #!/usr/bin/env bash
      pip list
    '')
    (pkgs.writeShellScriptBin "pyadd" ''
      #!/usr/bin/env bash
      for pkg in "$@"; do
        if ! grep -q "$pkg" requirements.txt &>/dev/null; then
          if pip install --cache-dir=$TMPDIR "$pkg"; then
            version=$(pip list | grep $pkg | xargs | cut -d ' ' -f2)
            echo "$pkg==$version" >>requirements.txt
          fi
        fi
      done
    '')
    (pkgs.writeShellScriptBin "pyrm" ''
      #!/usr/bin/env bash
      TMPDIR=${TMPDIR:-/tmp}
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
    '')
  ];

  shellHook = ''
    set -h # remove "bash: hash: hashing disabled" warning!
    SOURCE_DATE_EPOCH=$(date +%s)
    export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ pkgs.zlib pkgs.stdenv.cc.cc ]}":LD_LIBRARY_PATH;
    
    if ! [ -d .venv ]; then
      python -m venv .venv
    fi

    source .venv/bin/activate

    python -m pip install --cache-dir=$TMPDIR --upgrade pip

    export TMPDIR=/tmp

    if [ -e requirements.txt ]; then
      pip install --cache-dir=$TMPDIR -r requirements.txt
    fi

    if [ -n "$IN_NIX_SHELL" ]; then
      echo "Extra Functions:"
      echo "pymod : Show a list of installed Python packages."
      echo "pyadd : Add packages to requirements.txt and install them."
      echo "pyrm  : Remove packages from requirements.txt and uninstall them."
    fi
  '';
}

