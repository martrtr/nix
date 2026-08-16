{ config, lib, ... }:
let
  xdgDataDirs = lib.concatStringsSep ":" [
    config.xdg.dataHome
    "${config.home.profileDirectory}/share"
    "/etc/profiles/per-user/${config.home.username}/share"
    "/run/current-system/sw/share"
  ];
  spring = damping: stiffness: {
    kind.spring = {
      damping-ratio = damping;
      inherit stiffness;
      epsilon = 0.0001;
    };
  };
in
{
  # niri-flake generates and validates ~/.config/niri/config.kdl from this file.
  # Edit this source, never the read-only Home Manager symlink in ~/.config/niri.
  programs.niri.settings = {
    environment = {
      NIXOS_OZONE_WL = "1";
      ELECTRON_OZONE_PLATFORM_HINT = "auto";
      XDG_CURRENT_DESKTOP = "niri";
      XDG_MENU_PREFIX = "plasma-";
      XDG_CONFIG_HOME = config.xdg.configHome;
      XDG_DATA_HOME = config.xdg.dataHome;
      XDG_CACHE_HOME = config.xdg.cacheHome;
      XDG_STATE_HOME = config.xdg.stateHome;
      XDG_DATA_DIRS = xdgDataDirs;
      QT_QPA_PLATFORM = "wayland";
      QT_LOGGING_RULES = "quickshell.dbus.properties=false";
    };

    input = {
      keyboard = {
        xkb = {
          layout = "de,ru";
          options = "grp:caps_toggle";
        };
        repeat-delay = 250;
        repeat-rate = 50;
      };
      touchpad = {
        tap = true;
        tap-button-map = "left-right-middle";
        natural-scroll = false;
      };
      mouse.accel-profile = "flat";
      mod-key = "Super";
      mod-key-nested = "Alt";
      workspace-auto-back-and-forth = true;
    };

    outputs."HDMI-A-1" = {
      mode = {
        width = 1680;
        height = 1050;
        refresh = 59.883;
      };
      scale = 1.0;
    };

    cursor = {
      theme = "capitaine-cursors";
      size = 20;
      hide-when-typing = true;
    };

    prefer-no-csd = true;
    hotkey-overlay.skip-at-startup = true;
    screenshot-path = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";
    debug.honor-xdg-activation-with-invalid-serial = true;

    overview.zoom = 0.6;

    layout = {
      gaps = 10;
      background-color = "transparent";
      center-focused-column = "never";
      always-center-single-column = true;
      default-column-width.proportion = 1.0;
      preset-column-widths = [
        { proportion = 0.33333; }
        { proportion = 0.5; }
        { proportion = 0.66667; }
        { proportion = 1.0; }
      ];
      focus-ring.enable = false;
      border.enable = false;
      shadow = {
        enable = true;
        softness = 30;
        spread = 5;
        offset = {
          x = 0;
          y = 5;
        };
        color = "#0007";
      };
    };

    animations = {
      workspace-switch = spring 0.98 300;
      window-open = spring 0.98 300;
      window-close = spring 0.18 300;
      horizontal-view-movement = spring 0.98 300;
      window-movement = spring 0.98 900;
      window-resize = spring 0.98 300;
      config-notification-open-close = spring 0.98 300;
      screenshot-ui-open = spring 0.98 300;
    };

    workspaces = {
      "01".name = "1";
      "02".name = "2";
      "03".name = "3";
      "04".name = "4";
      "05".name = "5";
      "06".name = "6";
      "07".name = "7";
      "08".name = "8";
      "09".name = "9";
    };

    spawn-at-startup = [
      { sh = "gsettings set org.gnome.desktop.interface color-scheme prefer-dark || true; gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark || true; gsettings set org.gnome.desktop.interface icon-theme WhiteSur-dark || true; systemctl --user import-environment QT_PLUGIN_PATH QT_QPA_PLATFORM QT_QPA_PLATFORMTHEME QT_STYLE_OVERRIDE XDG_CURRENT_DESKTOP XDG_MENU_PREFIX XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME XDG_DATA_DIRS && dbus-update-activation-environment QT_PLUGIN_PATH QT_QPA_PLATFORM QT_QPA_PLATFORMTHEME QT_STYLE_OVERRIDE XDG_CURRENT_DESKTOP XDG_MENU_PREFIX XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME XDG_DATA_DIRS && kbuildsycoca6 --noincremental"; }
      { argv = [ "wl-paste" "--type" "text" "--watch" "cliphist" "store" ]; }
      { argv = [ "wl-paste" "--type" "image" "--watch" "cliphist" "store" ]; }
      { argv = [ "zen-browser" ]; }
      { argv = [ "throne" ]; }
      { argv = [ "steam" ]; }
      { argv = [ "AyuGram" ]; }
      { argv = [ "obsidian" ]; }
      { argv = [ "pear-desktop" ]; }
      { argv = [ "discord" ]; }
    ];

    window-rules = [
      # Global appearance and full-width default.
      {
        geometry-corner-radius = {
          top-left = 16.0;
          top-right = 16.0;
          bottom-right = 16.0;
          bottom-left = 16.0;
        };
        clip-to-geometry = true;
      }
      {
        matches = [ { is-active = false; } ];
        opacity = 0.9;
      }
      { open-maximized = true; }

      # Only the terminal and file manager start at half width.
      {
        matches = [
          { app-id = "^kitty$"; }
          { app-id = "^org\\.kde\\.dolphin$"; }
          { app-id = "^dolphin$"; }
        ];
        open-maximized = false;
        default-column-width.proportion = 0.5;
      }

      # Floating utility windows must not inherit the global maximize rule.
      {
        matches = [
          {
            app-id = "firefox$";
            title = "^Picture-in-Picture$";
          }
          {
            app-id = "zen$";
            title = "^Picture-in-Picture$";
          }
        ];
        open-maximized = false;
        open-floating = true;
      }
      {
        matches = [
          {
            app-id = "^steam$";
            title = "^notificationtoasts_[0-9]+_desktop$";
          }
        ];
        open-maximized = false;
        open-floating = true;
        default-floating-position = {
          x = 10;
          y = 10;
          relative-to = "bottom-right";
        };
      }

      # Old workspace placement, updated for Pear Desktop's current app-id.
      {
        matches = [ { app-id = "^zen$"; } ];
        open-on-workspace = "1";
      }
      {
        matches = [
          { app-id = "^codium$"; }
          { app-id = "^krita$"; }
          { app-id = "^org\\.kde\\.kdenlive$"; }
          { app-id = "^Aseprite$"; }
        ];
        open-on-workspace = "2";
      }
      {
        matches = [
          { app-id = "^org\\.telegram\\.desktop$"; }
          { app-id = "^com\\.ayugram\\.desktop$"; }
        ];
        open-on-workspace = "3";
      }
      {
        matches = [ { app-id = "^discord$"; } ];
        open-on-workspace = "4";
      }
      {
        matches = [
          { app-id = "^obsidian$"; }
          { app-id = "^org\\.keepassxc\\.KeePassXC$"; }
        ];
        open-on-workspace = "5";
      }
      {
        matches = [ { app-id = "^com\\.github\\.th-ch\\.youtube-music$"; } ];
        open-on-workspace = "6";
      }
      {
        matches = [ { app-id = "^org\\.prismlauncher\\.PrismLauncher$"; } ];
        open-on-workspace = "7";
      }
      {
        matches = [
          {
            app-id = "^org\\.quickshell$";
            title = "^Settings — iNiR$";
          }
        ];
        open-floating = true;
        open-focused = true;
      }
      {
        matches = [
          { app-id = "^steam$"; }
          { app-id = "^Throne$"; }
        ];
        open-on-workspace = "8";
      }
    ];

    layer-rules = [
      {
        matches = [ { namespace = "^quickshell:iiBackdrop$"; } ];
        place-within-backdrop = true;
        opacity = 1.0;
      }
      {
        matches = [ { namespace = "^quickshell:wBackdrop$"; } ];
        place-within-backdrop = true;
        opacity = 1.0;
      }
    ];

    binds = {
      "Mod+Tab" = {
        repeat = false;
        action.toggle-overview = { };
      };
      "Mod+Shift+E".action.quit = { };
      "Mod+Escape" = {
        allow-inhibiting = false;
        action.toggle-keyboard-shortcuts-inhibit = { };
      };
      "Mod+Shift+O".action.power-off-monitors = { };

      "Alt+Tab".action.spawn = [ "inir" "altSwitcher" "next" ];
      "Alt+Shift+Tab".action.spawn = [ "inir" "altSwitcher" "previous" ];
      "Super+G".action.spawn = [ "inir" "overlay" "toggle" ];
      "Mod+Space" = {
        repeat = false;
        action.spawn = [ "inir" "overview" "toggle" ];
      };
      "Mod+V".action.spawn = [ "inir" "clipboard" "toggle" ];
      "Mod+Alt+L" = {
        allow-when-locked = true;
        action.spawn = [ "inir" "lock" "activate" ];
      };
      "Mod+Shift+S".action.spawn = [ "inir" "region" "screenshot" ];
      "Mod+Shift+X".action.spawn = [ "inir" "region" "ocr" ];
      "Mod+Shift+A".action.spawn = [ "inir" "region" "search" ];
      "Ctrl+Shift+S".action.spawn = [ "inir" "region" "menu" ];
      "Ctrl+Alt+T".action.spawn = [ "inir" "wallpaperSelector" "toggle" ];
      "Mod+Comma".action.spawn = [ "inir" "settings" ];
      "Mod+Slash".action.spawn = [ "inir" "cheatsheet" "toggle" ];
      "Mod+Shift+W".action.spawn = [ "inir" "panelFamily" "cycle" ];
      "Mod+Shift+Q".action.spawn = [ "inir" "session" "toggle" ];

      "Mod+Return".action.spawn = [ "inir" "terminal" ];
      "Mod+T".action.spawn = [ "inir" "terminal" ];
      "Mod+E".action.spawn = "dolphin";
      "Mod+W".action.spawn = [ "inir" "browser" ];

      "Mod+Q" = {
        repeat = false;
        action.spawn = [ "inir" "close-window" ];
      };
      "Mod+D".action.maximize-column = { };
      "Mod+F".action.fullscreen-window = { };
      "Mod+A".action.toggle-window-floating = { };
      "Mod+Shift+V".action.switch-focus-between-floating-and-tiling = { };
      "Mod+R".action.switch-preset-column-width = { };
      "Mod+Shift+R".action.spawn = [ "inir" "region" "recordWithSound" ];
      "Mod+Ctrl+R".action.reset-window-height = { };
      "Mod+C".action.center-column = { };
      "Mod+Minus".action.set-column-width = "-10%";
      "Mod+Equal".action.set-column-width = "+10%";
      "Mod+Shift+Minus".action.set-window-height = "-10%";
      "Mod+Shift+Equal".action.set-window-height = "+10%";
      "Mod+BracketLeft".action.consume-or-expel-window-left = { };
      "Mod+BracketRight".action.consume-or-expel-window-right = { };

      "Mod+H".action.focus-column-left = { };
      "Mod+L".action.focus-column-right = { };
      "Mod+K".action.focus-window-up = { };
      "Mod+J".action.focus-window-down = { };
      "Mod+Left".action.focus-column-left = { };
      "Mod+Right".action.focus-column-right = { };
      "Mod+Up".action.focus-window-up = { };
      "Mod+Down".action.focus-window-down = { };
      "Mod+Home".action.focus-column-first = { };
      "Mod+End".action.focus-column-last = { };

      "Mod+Shift+H".action.move-column-left = { };
      "Mod+Shift+L".action.move-column-right = { };
      "Mod+Shift+K".action.move-window-up = { };
      "Mod+Shift+J".action.move-window-down = { };
      "Mod+Shift+Left".action.move-column-left = { };
      "Mod+Shift+Right".action.move-column-right = { };
      "Mod+Shift+Up".action.move-window-up = { };
      "Mod+Shift+Down".action.move-window-down = { };
      "Mod+Ctrl+Home".action.move-column-to-first = { };
      "Mod+Ctrl+End".action.move-column-to-last = { };

      "Mod+Ctrl+Left".action.focus-monitor-left = { };
      "Mod+Ctrl+Right".action.focus-monitor-right = { };
      "Mod+Ctrl+Up".action.focus-monitor-up = { };
      "Mod+Ctrl+Down".action.focus-monitor-down = { };
      "Mod+Ctrl+Shift+Left".action.move-column-to-monitor-left = { };
      "Mod+Ctrl+Shift+Right".action.move-column-to-monitor-right = { };
      "Mod+Ctrl+Shift+Up".action.move-column-to-monitor-up = { };
      "Mod+Ctrl+Shift+Down".action.move-column-to-monitor-down = { };

      "Mod+1".action.focus-workspace = 1;
      "Mod+2".action.focus-workspace = 2;
      "Mod+3".action.focus-workspace = 3;
      "Mod+4".action.focus-workspace = 4;
      "Mod+5".action.focus-workspace = 5;
      "Mod+6".action.focus-workspace = 6;
      "Mod+7".action.focus-workspace = 7;
      "Mod+8".action.focus-workspace = 8;
      "Mod+9".action.focus-workspace = 9;
      "Mod+Ctrl+1".action.move-column-to-workspace = 1;
      "Mod+Ctrl+2".action.move-column-to-workspace = 2;
      "Mod+Ctrl+3".action.move-column-to-workspace = 3;
      "Mod+Ctrl+4".action.move-column-to-workspace = 4;
      "Mod+Ctrl+5".action.move-column-to-workspace = 5;
      "Mod+Ctrl+6".action.move-column-to-workspace = 6;
      "Mod+Ctrl+7".action.move-column-to-workspace = 7;
      "Mod+Ctrl+8".action.move-column-to-workspace = 8;
      "Mod+Ctrl+9".action.move-column-to-workspace = 9;
      "Mod+Page_Down".action.focus-workspace-down = { };
      "Mod+Page_Up".action.focus-workspace-up = { };
      "Mod+Ctrl+Page_Down".action.move-column-to-workspace-down = { };
      "Mod+Ctrl+Page_Up".action.move-column-to-workspace-up = { };
      "Mod+WheelScrollDown" = {
        cooldown-ms = 150;
        action.focus-workspace-down = { };
      };
      "Mod+WheelScrollUp" = {
        cooldown-ms = 150;
        action.focus-workspace-up = { };
      };
      "Mod+Ctrl+WheelScrollDown" = {
        cooldown-ms = 150;
        action.move-column-to-workspace-down = { };
      };
      "Mod+Ctrl+WheelScrollUp" = {
        cooldown-ms = 150;
        action.move-column-to-workspace-up = { };
      };
      "Mod+WheelScrollRight".action.focus-column-right = { };
      "Mod+WheelScrollLeft".action.focus-column-left = { };

      "Print".action.screenshot = { };
      "Ctrl+Print".action.screenshot-screen = { };
      "Alt+Print".action.screenshot-window = { };

      "XF86AudioRaiseVolume" = {
        allow-when-locked = true;
        action.spawn = [ "inir" "audio" "volumeUp" ];
      };
      "XF86AudioLowerVolume" = {
        allow-when-locked = true;
        action.spawn = [ "inir" "audio" "volumeDown" ];
      };
      "XF86AudioMute" = {
        allow-when-locked = true;
        action.spawn = [ "inir" "audio" "mute" ];
      };
      "XF86AudioMicMute" = {
        allow-when-locked = true;
        action.spawn = [ "inir" "audio" "micMute" ];
      };
      "XF86MonBrightnessUp" = {
        allow-when-locked = true;
        action.spawn = [ "inir" "brightness" "increment" ];
      };
      "XF86MonBrightnessDown" = {
        allow-when-locked = true;
        action.spawn = [ "inir" "brightness" "decrement" ];
      };

      # Generic MPRIS: these target the currently active media player.
      "XF86AudioPlay".action.spawn = [ "inir" "mpris" "playPause" ];
      "XF86AudioPause".action.spawn = [ "inir" "mpris" "playPause" ];
      "XF86AudioNext".action.spawn = [ "inir" "mpris" "next" ];
      "XF86AudioPrev".action.spawn = [ "inir" "mpris" "previous" ];
      "Ctrl+Mod+Space".action.spawn = [ "inir" "mpris" "playPause" ];
      "Mod+Alt+N".action.spawn = [ "inir" "mpris" "next" ];
      "Mod+Alt+P".action.spawn = [ "inir" "mpris" "previous" ];
      "Mod+Shift+M".action.spawn = [ "inir" "audio" "mute" ];
      "Mod+Shift+P".action.spawn = [ "inir" "mpris" "playPause" ];
      "Mod+Shift+N".action.spawn = [ "inir" "mpris" "next" ];
      "Mod+Shift+B".action.spawn = [ "inir" "mpris" "previous" ];
    };
  };
}
