{ pkgs }:

let
  mkAppImage = import ../lib/mkAppImage.nix { inherit pkgs; };
  zen-browser = mkAppImage {
    pname = "zen-browser";
    version = "1.7.6b";
    src = pkgs.fetchurl {
      url = "https://github.com/zen-browser/desktop/releases/download/1.17.6b/zen-x86_64.AppImage";
      sha256 = "sha256:223eda317ad84a482e32c865398ba7d559c8470a09e2635656cab9b3f6d06e03";
    };
    name = "Zen Browser";
    comment = "A modern and fast web browser";
    categories = "Network;WebBrowser;";
  };
in
pkgs.mkShell {
  buildInputs = [ zen-browser ];
}
