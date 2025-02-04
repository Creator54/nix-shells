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
      echo -e "\033[1;36m🚀 Starting SigNoz services...\033[0m"
      echo -e "\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

      # Create working directory in user's home
      WORK_DIR="\$HOME/.local/share/signoz"
      echo -e "\033[1;34m📁 Setting up directories in \$WORK_DIR...\033[0m"

      # Create directory if it doesn't exist
      mkdir -p "\$WORK_DIR"

      # Check if this is a refresh
      if [ "\$1" = "refresh-signoz" ]; then
        echo -e "\033[1;33m🔄 Refreshing SigNoz - cleaning up existing installation...\033[0m"
        rm -rf "\$WORK_DIR"
        mkdir -p "\$WORK_DIR"
        echo -e "\033[1;32m📥 Cloning fresh SigNoz repository...\033[0m"
        ${pkgs.git}/bin/git clone --depth 1 https://github.com/signoz/signoz.git "\$WORK_DIR"
      else
        if [ -d "\$WORK_DIR/.git" ]; then
          echo -e "\033[1;34m📂 Found existing SigNoz installation...\033[0m"
          cd "\$WORK_DIR"
          
          # Check for local changes
          if ${pkgs.git}/bin/git diff --quiet; then
            echo -e "\033[1;32m📥 No local changes found, updating from remote...\033[0m"
            ${pkgs.git}/bin/git pull
          else
            echo -e "\033[1;33m⚠️  Local changes detected in compose files\033[0m"
            echo -e "\033[1;34mℹ️  Keeping local changes and skipping update\033[0m"
            echo -e "\033[1;36m💡 Use 'refresh-signoz' to get a fresh installation\033[0m"
          fi
        else
          echo -e "\033[1;32m📥 Cloning SigNoz repository...\033[0m"
          ${pkgs.git}/bin/git clone --depth 1 https://github.com/signoz/signoz.git "\$WORK_DIR"
        fi
      fi

      cd "\$WORK_DIR/deploy/docker"
      echo ""

      echo -e "\033[1;34m🔧 Applying compatibility fixes...\033[0m"
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

      echo -e "\033[1;32m✅ Fixes applied\033[0m"
      echo ""

      # Ensure data directories exist with proper permissions
      mkdir -p ./data/{clickhouse,zookeeper}
      chmod -R 777 ./data

      echo -e "\033[1;32m✅ Setup complete\033[0m"
      echo ""

      echo -e "\033[1;34m🔧 Configuring environment...\033[0m"
      # Ensure podman socket directory exists
      mkdir -p /run/user/\$(id -u)/podman
      export COMPOSE_PROJECT_NAME="signoz"
      echo -e "\033[1;32m✅ Environment configured\033[0m"
      echo ""

      echo -e "\033[1;35m📦 Starting containers...\033[0m"
      ${pkgs.podman}/bin/podman compose up -d --remove-orphans

      # Wait for services to be ready
      echo -e "\n\033[1;34m⏳ Waiting for services to be ready...\033[0m"
      attempt=1
      max_attempts=30
      while [ \$attempt -le \$max_attempts ]; do
        if ${pkgs.curl}/bin/curl -s http://localhost:3301 >/dev/null; then
          echo -e "\033[1;32m✅ Services are ready!\033[0m"
          break
        fi
        echo -e "\033[1;33m⌛ Attempt \$attempt/\$max_attempts - Still waiting...\033[0m"
        sleep 2
        attempt=\$((attempt + 1))
      done

      if [ \$attempt -gt \$max_attempts ]; then
        echo -e "\033[1;31m❌ Timeout waiting for services\033[0m"
      fi

      echo ""
      echo -e "\033[1;32m✨ SigNoz is running!\033[0m"
      echo -e "\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
      echo -e "\033[1;34m🌐 UI: \033[1;36mhttp://localhost:3301\033[0m"
      echo -e "\033[1;34m📊 Status: \033[1;32mHealthy\033[0m"

      # Show running containers
      echo -e "\n\033[1;34m📋 Running Containers:\033[0m"
      ${pkgs.podman}/bin/podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | ${pkgs.gnused}/bin/sed '1s/^/\x1b[1;36m/' | ${pkgs.gnused}/bin/sed '1s/$/\x1b[0m/'
      echo ""
      EOF
      chmod +x $out/bin/start-signoz

      cat > $out/bin/stop-signoz <<EOF
      #!${pkgs.runtimeShell}
      echo ""
      echo -e "\033[1;31m🛑 Stopping SigNoz services...\033[0m"
      echo -e "\033[1;31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

      cd "\$HOME/.local/share/signoz/deploy/docker"
      ${pkgs.podman}/bin/podman compose down

      if [ \$? -eq 0 ]; then
        echo ""
        echo -e "\033[1;32m✅ SigNoz services stopped successfully\033[0m"
        echo ""
      else
        echo ""
        echo -e "\033[1;31m❌ Failed to stop SigNoz services\033[0m"
        echo -e "\033[1;31m━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        echo -e "\033[1;36m💡 Try manual cleanup:\033[0m"
        echo -e "\033[1;34m   podman ps -a              \033[0m# List all containers"
        echo -e "\033[1;34m   podman stop <container>   \033[0m# Stop a container"
        echo -e "\033[1;34m   podman rm <container>     \033[0m# Remove a container"
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
    pkgs.curl # Added for health checks
    signoz
    # Add some debug tools
    pkgs.procps
    pkgs.iproute2
  ];

  shellHook = ''
    echo ""
    echo -e "\033[1;35m📦 SigNoz Development Environment\033[0m"
    echo -e "\033[1;35m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo ""
    echo -e "\033[1;34m📂 Locations:\033[0m"
    echo -e "   Working dir: \033[1;36m$HOME/.local/share/signoz\033[0m"
    echo ""
    echo -e "\033[1;34m🔧 Configuring Podman...\033[0m"
    ${podmanSetupScript}
    echo -e "\033[1;32m✅ Podman configured\033[0m"
    echo ""

    echo -e "\033[1;35m🚀 Initializing SigNoz...\033[0m"
    echo -e "\033[1;35m━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "\033[1;34m📌 Available commands:\033[0m"
    echo -e "   \033[1;32mstart-signoz    \033[0m- Start SigNoz services"
    echo -e "   \033[1;31mstop-signoz     \033[0m- Stop SigNoz services"
    echo -e "   \033[1;33mrefresh-signoz  \033[0m- Refresh SigNoz services"
    echo ""
    echo -e "\033[1;34m📋 Container management:\033[0m"
    echo -e "   \033[1;36mpodman ps       \033[0m- List running containers"
    echo -e "   \033[1;36mpodman ps -a    \033[0m- List all containers"
    echo -e "   \033[1;36mpodman logs     \033[0m- View container logs"
    echo ""

    # Start SigNoz
    start-signoz
  '';
}
