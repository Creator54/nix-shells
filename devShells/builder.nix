{ pkgs }:

let

  # To use this shell.nix on NixOS your user needs to be configured as such:
  # users.extraUsers.adisbladis = {
  #   subUidRanges = [{ startUid = 100000; count = 65536; }];
  #   subGidRanges = [{ startGid = 100000; count = 65536; }];
  # };

  # Provides a script that copies required files to ~/
  podmanSetupScript = let
    registriesConf = pkgs.writeText "registries.conf" ''
      [registries.search]
      registries = ['docker.io']

      [registries.block]
      registries = []
    '';
  in pkgs.writeScript "podman-setup" ''
    #!${pkgs.runtimeShell}

    # Dont overwrite customised configuration
    if ! test -f ~/.config/containers/policy.json; then
      install -Dm555 ${pkgs.skopeo.src}/default-policy.json ~/.config/containers/policy.json
    fi

    if ! test -f ~/.config/containers/registries.conf; then
      install -Dm555 ${registriesConf} ~/.config/containers/registries.conf
    fi
  '';

  # Provides a fake "docker" binary mapping to podman
  dockerCompat = pkgs.runCommandNoCC "docker-podman-compat" {} ''
    mkdir -p $out/bin
    ln -s ${pkgs.podman}/bin/podman $out/bin/docker
  '';

  # Builder derivation
  builder = pkgs.stdenv.mkDerivation {
    name = "builder";
    src = pkgs.fetchFromGitHub {
      owner = "creator54";
      repo = "metagpt-runner";
      rev = "master";  # Replace with specific commit or tag as needed
      sha256 = "sha256-iJGAI3iAy2Cj9NK7tlPItRaGavco9ByyepuYzbfv+y0=";  # Replace with correct hash
    };
    buildInputs = [ pkgs.git pkgs.podman pkgs.runc pkgs.conmon pkgs.skopeo pkgs.slirp4netns pkgs.fuse-overlayfs ];
    installPhase = ''
      # Install the builder script to the output directory
      mkdir -p $out/bin
      cp builder $out/bin/builder
      cp entrypoint $out/bin/entrypoint
      cp Dockerfile $out/bin/Dockerfile
    '';
  };

in pkgs.mkShell {

  buildInputs = [
    dockerCompat
    pkgs.podman  # Docker compat
    pkgs.runc  # Container runtime
    pkgs.conmon  # Container runtime monitor
    pkgs.skopeo  # Interact with container registry
    pkgs.slirp4netns  # User-mode networking for unprivileged namespaces
    pkgs.fuse-overlayfs  # CoW for images, much faster than default vfs
    builder
  ];

  shellHook = ''
    # Install required configuration
    ${podmanSetupScript}
    export PATH=$PATH:${builder}/bin
  '';

}


