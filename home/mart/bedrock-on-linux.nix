{ pkgs, ... }:
let
  bedrockOnLinux = pkgs.appimageTools.wrapType2 rec {
    pname = "bedrock-on-linux";
    version = "1.3.0";

    src = pkgs.fetchurl {
      url = "https://github.com/Wyze3306/BedrockOnLinux/releases/download/v${version}/BedrockOnLinux-${version}-x86_64.AppImage";
      hash = "sha256-HqC0UuiBPANT2dxGm3qsxMlYGoMI9WaznyX7AEw5cug=";
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
