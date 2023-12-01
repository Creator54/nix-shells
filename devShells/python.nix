{ pkgs }:

pkgs.mkShell {
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
    # ... (your extra functions here)
  '';
}

