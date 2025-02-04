{ pkgs }:

let

  # To use this shell.nix on NixOS your user needs to be configured as such:
  # users.extraUsers.adisbladis = {
  #   subUidRanges = [{ startUid = 100000; count = 65536; }];
  #   subGidRanges = [{ startGid = 100000; count = 65536; }];
  # };

  # Provides a script that copies required files to ~/
  podmanSetupScript =
    let
      registriesConf = pkgs.writeText "registries.conf" ''
        [registries.search]
        registries = ['docker.io']

        [registries.block]
        registries = []
      '';

      containersConf = pkgs.writeText "containers.conf" ''
        [containers]
        netns="bridge"
        network_backend="cni"

        [engine]
        cgroup_manager="cgroupfs"
        events_logger="file"
        runtime="crun"

        [network]
        default_network="podman"
        network_backend="cni"
      '';

    in
    pkgs.writeScript "podman-setup" ''
      #!${pkgs.runtimeShell}

      mkdir -p ~/.config/containers

      # Don't overwrite customised configuration
      if ! test -f ~/.config/containers/policy.json; then
      install -Dm555 ${pkgs.skopeo.src}/default-policy.json ~/.config/containers/policy.json
      fi

      if ! test -f ~/.config/containers/registries.conf; then
      install -Dm555 ${registriesConf} ~/.config/containers/registries.conf
      fi

      if ! test -f ~/.config/containers/containers.conf; then
      install -Dm555 ${containersConf} ~/.config/containers/containers.conf
      fi
    '';

  # Provides a fake "docker" binary mapping to podman
  dockerCompat = pkgs.runCommandNoCC "docker-podman-compat" { } ''
    mkdir -p $out/bin
    ln -s ${pkgs.podman}/bin/podman $out/bin/docker
  '';

  # SigNoz derivation
  signoz = pkgs.stdenv.mkDerivation {
    name = "signoz";

    src = builtins.fetchTarball {
      url = "https://github.com/signoz/signoz/archive/main.tar.gz";
      sha256 = "sha256:19pr99qw0zqfqisfzvvcwp9jwr3lnjz2vsgwr3w759jrknsqj5z3";
    };

    dontBuild = true;
    dontConfigure = true;

    installPhase = ''
      mkdir -p $out/share/signoz
      cp -r * $out/share/signoz

      # Create wrapper scripts
      mkdir -p $out/bin
      cat > $out/bin/start-signoz <<EOF
      #!${pkgs.runtimeShell}
      cd $out/share/signoz/deploy/docker
      CONTAINERS_CONF=\$HOME/.config/containers/containers.conf exec ${pkgs.podman}/bin/podman compose up -d --remove-orphans
      EOF
      chmod +x $out/bin/start-signoz

      cat > $out/bin/stop-signoz <<EOF
      #!${pkgs.runtimeShell}
      cd $out/share/signoz/deploy/docker
      CONTAINERS_CONF=\$HOME/.config/containers/containers.conf exec ${pkgs.podman}/bin/podman compose down
      EOF
      chmod +x $out/bin/stop-signoz
    '';
  };

in
pkgs.mkShell {
  buildInputs = [
    dockerCompat
    pkgs.podman # Docker compat
    pkgs.podman-compose # Add this
    pkgs.runc # Container runtime
    pkgs.conmon # Container runtime monitor
    pkgs.skopeo # Interact with container registry
    pkgs.slirp4netns # User-mode networking for unprivileged namespaces
    pkgs.fuse-overlayfs # CoW for images, much faster than default vfs
    pkgs.cni-plugins # Added CNI plugins
    signoz
  ];

  shellHook = ''
    # Install required configuration
    ${podmanSetupScript}

    # Start SigNoz automatically
    start-signoz

    echo "SigNoz is starting up..."
    echo "Access the UI at http://localhost:3301"
    echo "To stop SigNoz, run 'stop-signoz'"
  '';
}
