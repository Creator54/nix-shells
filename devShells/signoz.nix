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

    # We don't need to fetch the source in the derivation anymore
    src = ./.; # dummy source

    dontBuild = true;
    dontConfigure = true;

    installPhase = ''
      mkdir -p $out/bin

      cat > $out/bin/start-signoz <<EOF
      #!${pkgs.runtimeShell}
      echo ""
      echo "🚀 Starting SigNoz services..."
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

      # Create working directory in user's home
      WORK_DIR="\$HOME/.local/share/signoz"
      echo "📁 Setting up directories in \$WORK_DIR..."

      # Create directory if it doesn't exist
      mkdir -p "\$WORK_DIR"

      # Check if this is a refresh
      if [ "\$1" = "refresh-signoz" ]; then
        echo "🔄 Refreshing SigNoz - cleaning up existing installation..."
        rm -rf "\$WORK_DIR"
        mkdir -p "\$WORK_DIR"
        echo "📥 Cloning fresh SigNoz repository..."
        ${pkgs.git}/bin/git clone --depth 1 https://github.com/signoz/signoz.git "\$WORK_DIR"
      else
        if [ -d "\$WORK_DIR/.git" ]; then
          echo "📂 Found existing SigNoz installation..."
          cd "\$WORK_DIR"
          
          # Check for local changes
          if ${pkgs.git}/bin/git diff --quiet; then
            echo "📥 No local changes found, updating from remote..."
            ${pkgs.git}/bin/git pull
          else
            echo "⚠️  Local changes detected in compose files"
            echo "ℹ️  Keeping local changes and skipping update"
            echo "💡 Use 'refresh-signoz' to get a fresh installation"
          fi
        else
          echo "📥 Cloning SigNoz repository..."
          ${pkgs.git}/bin/git clone --depth 1 https://github.com/signoz/signoz.git "\$WORK_DIR"
        fi
      fi

      cd "\$WORK_DIR/deploy/docker"
      echo ""

      echo "🔧 Applying compatibility fixes..."
      # Find and patch all docker-compose files
      ${pkgs.findutils}/bin/find "\$WORK_DIR/deploy/docker" -name "docker-compose*.yaml" -type f -exec \
        ${pkgs.gnused}/bin/sed -i \
          -e 's/ulimits:/#ulimits:/g' \
          -e 's/  nproc/#  nproc/g' \
          -e 's/  nofile/#  nofile/g' \
          -e 's/    soft/#    soft/g' \
          -e 's/    hard/#    hard/g' \
          {} \;

      # Replace Docker paths with Podman paths
      ${pkgs.findutils}/bin/find "\$WORK_DIR/deploy/docker" -name "docker-compose*.yaml" -type f -exec \
        ${pkgs.gnused}/bin/sed -i \
          -e 's|/var/lib/docker/containers|/var/lib/containers|g' \
          -e 's|/var/run/docker.sock|/run/podman/podman.sock|g' \
          {} \;

      # Remove 'version' field from docker-compose files
      ${pkgs.findutils}/bin/find "\$WORK_DIR/deploy/docker" -name "docker-compose*.yaml" -type f -exec \
        sh -c '${pkgs.coreutils}/bin/cat "{}" | ${pkgs.gnugrep}/bin/grep -v "version:" > "{}.tmp" && mv "{}.tmp" "{}"' \;

      echo "✅ Fixes applied"
      echo ""

      # Ensure data directories exist with proper permissions
      mkdir -p ./data/{clickhouse,zookeeper}
      chmod -R 777 ./data

      echo "✅ Setup complete"
      echo ""

      echo "🔧 Configuring environment..."
      # Ensure podman socket directory exists
      mkdir -p /run/user/\$(id -u)/podman
      export COMPOSE_PROJECT_NAME="signoz"
      echo "✅ Environment configured"
      echo ""

      echo "📦 Starting containers..."
      ${pkgs.podman}/bin/podman compose up -d --remove-orphans

      echo ""
      echo "✨ SigNoz is starting up!"
      echo "━━━━━━━━━━━━━━━━━━━━━━━"
      echo "🌐 UI: http://localhost:3301"
      echo "📊 Query Service: http://localhost:8080"
      echo "🔧 Management: http://localhost:3301/settings"
      echo ""
      EOF
      chmod +x $out/bin/start-signoz

      cat > $out/bin/stop-signoz <<EOF
      #!${pkgs.runtimeShell}
      echo ""
      echo "🛑 Stopping SigNoz services..."
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

      cd "\$HOME/.local/share/signoz/deploy/docker"
      ${pkgs.podman}/bin/podman compose down

      if [ \$? -eq 0 ]; then
      echo ""
      echo "✅ SigNoz services stopped successfully"
      echo ""
      else
      echo ""
      echo "❌ Failed to stop SigNoz services"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "💡 Try manual cleanup:"
      echo "   podman ps -a              # List all containers"
      echo "   podman stop <container>   # Stop a container"
      echo "   podman rm <container>     # Remove a container"
      echo ""
      fi
      EOF
      chmod +x $out/bin/stop-signoz
    '';
  };

in
pkgs.mkShell {
  buildInputs = [
    dockerCompat
    pkgs.podman
    pkgs.runc
    pkgs.conmon
    pkgs.skopeo
    pkgs.slirp4netns
    pkgs.fuse-overlayfs
    pkgs.cni-plugins
    pkgs.git # Added git for cloning
    signoz
    # Add some debug tools
    pkgs.procps
    pkgs.iproute2
  ];

  shellHook = ''
    echo ""
    echo "📦 SigNoz Development Environment"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📂 Locations:"
    echo "   Working dir: $HOME/.local/share/signoz"
    echo ""
    echo "🔧 Configuring Podman..."
    ${podmanSetupScript}
    echo "✅ Podman configured"
    echo ""

    echo "🚀 Initializing SigNoz..."
    echo "━━━━━━━━━━━━━━━━━━━━━━"
    echo "📌 Available commands:"
    echo "   start-signoz    - Start SigNoz services"
    echo "   stop-signoz     - Stop SigNoz services"
    echo "   refresh-signoz  - Refresh SigNoz services"
    echo ""
    echo "📋 Container management:"
    echo "   podman ps       - List running containers"
    echo "   podman ps -a    - List all containers"
    echo "   podman logs     - View container logs"
    echo ""

    # Start SigNoz
    start-signoz
  '';
}
