{ pkgs }:

{ pname
, version
, src
, name
, comment
, categories
}:

pkgs.appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    mkdir -p $out/share/applications
    cat > $out/share/applications/${pname}.desktop <<EOF
[Desktop Entry]
Type=Application
Name=${name}
Comment=${comment}
Exec=${pname}
Categories=${categories}
Terminal=false
EOF
  '';
}
