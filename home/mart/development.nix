{ pkgs, ... }:
let
  rintawaDev = pkgs.writeShellScriptBin "rintawa" ''
    set -euo pipefail
    cd /srv/apps/rintawa
    exec ${pkgs.cargo}/bin/cargo run --quiet --locked -p rintawa -- "$@"
  '';
in
{
  home.packages = with pkgs; [
    codex
    gcc
    uv

    # Provides both `node` and `npm`.
    nodejs

    cargo
    clippy
    rustc
    rustfmt
    jdk25

    fd
    jq
    micro
    ripgrep
    rintawaDev
  ];
}
