{ pkgs, ... }:
let
  bedrockOnLinux = pkgs.appimageTools.wrapType2 rec {
    pname = "bedrock-on-linux";
    version = "2.2.1";

    src = pkgs.fetchurl {
      url = "https://github.com/Wyze3306/BedrockOnLinux/releases/download/v${version}/BedrockOnLinux-${version}-x86_64.AppImage";
      hash = "sha256-Nx1y3l836S9cTchlVyoxKjP5EXgphEe/eWgUN7oDuZI=";
    };

    extraPkgs = pkgs: with pkgs; [
      fontconfig
      freetype
      libGL
      libxkbcommon
      libx11
      libxcursor
      libxext
      libxft
      libxi
      libxrandr
      libxrender
      libxcb
    ];
  };
in
{
  home.packages = [ bedrockOnLinux ];
}
