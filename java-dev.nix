with import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/69919a28af1c181dc84523b100a8ed45d4071304.tar.gz") { };
pkgs.mkShell rec {
  name = "java-dev";
  buildInputs = [
    openjdk11
    (gradle.override { java = openjdk11; })
  ];

  NIX_LD_LIBRARY_PATH = lib.makeLibraryPath [
    stdenv.cc.cc
    glib
    openssl
    nss
    nspr
    xorg.libxcb
  ];
  NIX_LD = lib.fileContents "${stdenv.cc}/nix-support/dynamic-linker";

  shellHook = ''
    if [ -n "$IN_NIX_SHELL" ]; then
      java --version
      gradle --version
    fi
    export JAVA_HOME=$(readlink -f $(which java) | xargs dirname | xargs dirname)
  '';
}
