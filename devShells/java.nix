{ pkgs }:

pkgs.mkShell {
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
}
