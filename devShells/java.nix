{ pkgs }:

pkgs.mkShell {
  name = "java";
  buildInputs = [
    pkgs.openjdk11
    (pkgs.gradle.override { java = pkgs.openjdk11; })
  ];

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
    if [ -n "$IN_NIX_SHELL" ]; then
      java --version
      gradle --version
    fi
    export JAVA_HOME=$(readlink -f $(which java) | xargs dirname | xargs dirname)
  '';
}
