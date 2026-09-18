{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  # Keep Nixcord's initial defaults, but let the app own subsequent changes.
  common = import (inputs.nixcord.outPath + "/modules/lib/mkCommonConfig.nix") {
    inherit config lib pkgs;
  };
  mutableSettings = builtins.filter (
    spec: builtins.elem spec.name [ "equicord-settings" "discord-settings" ]
  ) common.fileSpecs;

  # Discord's native Linux game detector knows only a fraction of Linux/Proton
  # executables. This bridge identifies the Steam game from /proc and uses the
  # matching official Discord application ID from Discord's detectable-app DB.
  discordRpcBridge = pkgs.buildGoModule rec {
    pname = "discord-rpc-bridge";
    version = "unstable-2026-09-16";
    src = pkgs.fetchFromGitHub {
      owner = "barrettotte";
      repo = "discord-rpc-bridge";
      rev = "ccfe5aeba1790ca6f2909012394e5fe7aa773b38";
      sha256 = "0n69ikjc9c05gf55vk9dzcj85193q0bqrwdx5aalnnq1i5kip4vr";
    };
    vendorHash = "sha256-qaiwFz1SVJz6rehoSs8akyk5qXXGpoOVR2zspmY9eSw=";
    ldflags = [ "-X main.version=${version}" ];
    meta.mainProgram = "discord-rpc-bridge";
  };
in
{
  imports = [
    inputs.nixcord.homeModules.nixcord
  ];

  # Home Manager also activates at boot. Never overwrite GUI settings there.
  home.activation = builtins.listToAttrs (map (spec: {
    name = "nixcord-${spec.name}";
    value = lib.mkForce (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      dest=${lib.escapeShellArg spec.dest}
      src=${lib.escapeShellArg spec.src}
      if [ -L "$dest" ] && [ -e "$dest" ]; then
        tmp="$(${pkgs.coreutils}/bin/mktemp "$dest.mutable.XXXXXX")"
        ${pkgs.coreutils}/bin/cp --dereference "$dest" "$tmp"
        ${pkgs.coreutils}/bin/chmod 600 "$tmp"
        ${pkgs.coreutils}/bin/mv -f "$tmp" "$dest"
      elif [ ! -e "$dest" ]; then
        if [ -L "$dest" ]; then
          ${pkgs.coreutils}/bin/rm "$dest"
        fi
        ${pkgs.coreutils}/bin/install -Dm600 "$src" "$dest"
      fi
    '');
  }) mutableSettings);

  home.packages = [ discordRpcBridge ];

  xdg.configFile."discord-rpc-bridge/config.json".text = builtins.toJSON {
    scan_interval_seconds = 5;
    discord_api_version = 10;
    game_cache_ttl_days = 7;
    ignored_games = [
      "SteamControllerConfigs"
      "shader_compiler"
      "Steamworks Shared"
    ];
    ignored_processes = [
      "gamescopereaper"
      "reaper"
      "steam-launch-wrapper"
      "pressure-vessel-wrap"
    ];
    manual_mappings = {
      # Steam still keeps CS2 in the old CSGO install directory.
      "Counter-Strike Global Offensive" = "1158877933042143272";
    };
  };

  systemd.user.services.discord-rpc-bridge = {
    Unit = {
      Description = "Map Steam games to official Discord Rich Presence applications";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      ExecStart = "${discordRpcBridge}/bin/discord-rpc-bridge";
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };

  programs.nixcord = {
    enable = true;
    discord = {
      enable = true;
      equicord.enable = true;
      openASAR.enable = true;
      commandLineArgs = [
        "--ozone-platform-hint=auto"
        "--enable-features=WaylandWindowDecorations,VaapiVideoDecoder"
        "--enable-wayland-ime"
      ];
      settings = {
        openasar.setup = true;
      };
    };
  };
}
