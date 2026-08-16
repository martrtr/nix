{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  inirPackage = osConfig.programs.inir.package;
  inirRuntime = "${inirPackage}/share/quickshell/inir";
  inirThemePath = lib.makeBinPath (
    [
      inirPackage
      pkgs.coreutils
      pkgs.jq
    ]
    ++ osConfig.programs.inir.extraPackages
  );
  applyInirTheme = pkgs.writeShellScript "apply-inir-theme-after-start" ''
    set -eu

    export PATH=${lib.escapeShellArg inirThemePath}

    state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated"
    ready=""

    # Reuse the persisted palette immediately on normal boots. On a fresh
    # install, wait up to one minute for iNiR to generate its first palette.
    for _ in $(${pkgs.coreutils}/bin/seq 1 120); do
      for candidate in \
        "$state_dir/app-palette.json" \
        "$state_dir/palette.json" \
        "$state_dir/colors.json"
      do
        if [ -s "$candidate" ] && ${pkgs.jq}/bin/jq empty "$candidate" >/dev/null 2>&1; then
          ready="$candidate"
          break 2
        fi
      done
      ${pkgs.coreutils}/bin/sleep 0.5
    done

    # Do not fail the whole graphical session when a first-run palette is still
    # unavailable. iNiR will apply targets itself after color generation.
    [ -n "$ready" ] || exit 0

    exec ${pkgs.bash}/bin/bash \
      ${lib.escapeShellArg "${inirRuntime}/scripts/colors/apply-gtk-theme.sh"}
  '';
in
{
  # Zen and Throne are started as user services after the persisted iNiR palette
  # has been applied. Starting them directly in Niri races the theme generator
  # on every login and leaves long-running applications with the default theme.
  programs.niri.settings.spawn-at-startup = lib.mkForce [
    { sh = "gsettings set org.gnome.desktop.interface color-scheme prefer-dark || true; gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark || true; gsettings set org.gnome.desktop.interface icon-theme WhiteSur-dark || true; systemctl --user import-environment QT_PLUGIN_PATH QT_QPA_PLATFORM QT_QPA_PLATFORMTHEME QT_STYLE_OVERRIDE XDG_CURRENT_DESKTOP XDG_MENU_PREFIX XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME XDG_DATA_DIRS && dbus-update-activation-environment QT_PLUGIN_PATH QT_QPA_PLATFORM QT_QPA_PLATFORMTHEME QT_STYLE_OVERRIDE XDG_CURRENT_DESKTOP XDG_MENU_PREFIX XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME XDG_DATA_DIRS && kbuildsycoca6 --noincremental"; }
    { argv = [ "wl-paste" "--type" "text" "--watch" "cliphist" "store" ]; }
    { argv = [ "wl-paste" "--type" "image" "--watch" "cliphist" "store" ]; }
    { argv = [ "steam" ]; }
    { argv = [ "AyuGram" ]; }
    { argv = [ "obsidian" ]; }
    { argv = [ "pear-desktop" ]; }
    { argv = [ "discord" ]; }
  ];

  systemd.user.services = {
    llama = {
      Unit = {
        Description = "llama.cpp Qwen server";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.llama-cpp-vulkan}/bin/llama serve --host 0.0.0.0 --port 11434 --alias qwen3.6-35b-a3b --hf-repo bartowski/Qwen_Qwen3.6-35B-A3B-GGUF --hf-file Qwen_Qwen3.6-35B-A3B-IQ2_M.gguf --ctx-size 61440 --n-gpu-layers all --fit on --fit-target 512 --flash-attn on --cache-type-k q4_0 --cache-type-v q4_0 --jinja --no-mmproj --sleep-idle-seconds 900";
        Restart = "always";
        RestartSec = 3;
        Environment = [
          "HOME=${config.home.homeDirectory}"
          "XDG_CACHE_HOME=${config.xdg.cacheHome}"
          "XDG_CONFIG_HOME=${config.xdg.configHome}"
          "XDG_DATA_HOME=${config.xdg.dataHome}"
          "XDG_STATE_HOME=${config.xdg.stateHome}"
        ];
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    inir-theme-apply = {
      Unit = {
        Description = "Apply persisted iNiR themes to desktop applications";
        Requires = [ "inir.service" ];
        After = [ "inir.service" ];
        Before = [
          "throne-autostart.service"
        ];
        PartOf = [ "inir.service" ];
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = applyInirTheme;
      };
      Install.WantedBy = [ "niri.service" ];
    };

    throne-autostart = {
      Unit = {
        Description = "Start Throne in the Niri session";
        Wants = [ "inir-theme-apply.service" ];
        After = [ "inir-theme-apply.service" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "/run/current-system/sw/bin/Throne";
        Restart = "on-failure";
        RestartSec = 3;
      };
      Install.WantedBy = [ "niri.service" ];
    };
  };
}
