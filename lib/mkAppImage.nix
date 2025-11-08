{ pkgs }:

{ pname
, version
, src
, name ? null
, comment ? null
, categories ? null
}:

let
  appName = if name != null then name else pname;
  appComment = if comment != null then comment else "Application ${appName}";
  appCategories = if categories != null then categories else "Application";
  appimageContents = pkgs.appimageTools.extract {
    inherit pname version src;
  };
in
pkgs.appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    # Create desktop entry and icon directories
    mkdir -p $out/share/applications
    
    # Create directories for different icon sizes
    for size in 16 32 48 64 128 256 512 1024; do
      mkdir -p $out/share/icons/hicolor/''${size}x''${size}/apps
    done

    # Create a desktop entry with absolute path to executable
    cat > $out/share/applications/${pname}.desktop << EOF
[Desktop Entry]
Name=${appName}
Comment=${appComment}
Exec=$out/bin/${pname}
Terminal=false
Type=Application
Categories=${appCategories}
Icon=${pname}
EOF

    # Try to find and install icons for different sizes
    for size in 16 32 48 64 128 256 512 1024; do
      for icon in \
        ${appimageContents}/usr/share/icons/hicolor/''${size}x''${size}/apps/${pname}.png \
        ${appimageContents}/icons/''${size}x''${size}.png \
        ${appimageContents}/icons/''${size}.png; do
        if [ -f "$icon" ]; then
          echo "Found ''${size}x''${size} icon at: $icon"
          install -m 444 -D "$icon" "$out/share/icons/hicolor/''${size}x''${size}/apps/${pname}.png"
          break
        fi
      done
    done

    # Fallback to any available icon if no size-specific icons found
    if [ ! -f "$out/share/icons/hicolor/512x512/apps/${pname}.png" ]; then
      for icon in \
        ${appimageContents}/usr/share/icons/hicolor/512x512/apps/${pname}.png \
        ${appimageContents}/${pname}.png \
        ${appimageContents}/.DirIcon \
        ${appimageContents}/icon.png; do
        if [ -f "$icon" ]; then
          echo "Using fallback icon from: $icon"
          for size in 16 32 48 64 128 256 512 1024; do
            mkdir -p "$out/share/icons/hicolor/''${size}x''${size}/apps"
            install -m 444 -D "$icon" "$out/share/icons/hicolor/''${size}x''${size}/apps/${pname}.png"
          done
          break
        fi
      done
    fi
    
    # Create a post-install script to update desktop database
    mkdir -p $out/bin
    cat > $out/bin/${pname}-update-desktop << EOFSCRIPT
#!/usr/bin/env bash
echo "Copying desktop file to ~/.local/share/applications/..."
mkdir -p ~/.local/share/applications
cp $out/share/applications/${pname}.desktop ~/.local/share/applications/

echo "Copying icons to ~/.local/share/icons/..."
mkdir -p ~/.local/share/icons/hicolor
for size in 16 32 48 64 128 256 512 1024; do
  if [ -f "$out/share/icons/hicolor/\''${size}x\''${size}/apps/${pname}.png" ]; then
    mkdir -p ~/.local/share/icons/hicolor/\''${size}x\''${size}/apps
    cp "$out/share/icons/hicolor/\''${size}x\''${size}/apps/${pname}.png" ~/.local/share/icons/hicolor/\''${size}x\''${size}/apps/
  fi
done

echo "Updating desktop database..."
if command -v update-desktop-database &> /dev/null; then
  update-desktop-database ~/.local/share/applications 2>/dev/null || true
fi
if command -v gtk-update-icon-cache &> /dev/null; then
  gtk-update-icon-cache ~/.local/share/icons/hicolor 2>/dev/null || true
fi

echo "Done! ${appName} should now appear in your application menu."
echo "If not, try logging out and back in."
EOFSCRIPT
    chmod +x $out/bin/${pname}-update-desktop
    
    echo ""
    echo "=========================================="
    echo "${appName} installed successfully!"
    echo "If the application doesn't appear in your menu, run:"
    echo "  ${pname}-update-desktop"
    echo "Or manually run:"
    echo "  update-desktop-database ~/.nix-profile/share/applications"
    echo "  gtk-update-icon-cache ~/.nix-profile/share/icons/hicolor"
    echo "=========================================="
    echo ""
  '';
}
