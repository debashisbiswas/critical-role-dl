{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  packages = [
    pkgs.python3Packages.yt-dlp
    pkgs.jq
    pkgs.gum
  ];
}
