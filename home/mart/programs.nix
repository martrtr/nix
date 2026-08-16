{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  keepassxcInitialConfig = pkgs.writeText "keepassxc-initial.ini" ''
    [Browser]
    Enabled=true
    UpdateBinaryPath=false

    [FdoSecrets]
    Enabled=true
    ShowNotification=true
    ConfirmDeleteItem=true
    ConfirmAccessItem=true
    UnlockBeforeSearch=true

    [GUI]
    ApplicationTheme=dark
    ShowTrayIcon=true
    MinimizeToTray=true
    MinimizeOnClose=true

    [Security]
    ClearClipboard=true
    ClearClipboardTimeout=15
    LockDatabaseScreenLock=true
  '';
  vscodiumInitialSettings = pkgs.writeText "vscodium-initial-settings.json" (builtins.toJSON {
    "window.titleBarStyle" = "custom";
    "window.commandCenter" = true;
    "editor.fontFamily" = "JetBrainsMono Nerd Font";
    "editor.fontLigatures" = true;
    "terminal.integrated.fontFamily" = "JetBrainsMono Nerd Font";
    "telemetry.telemetryLevel" = "off";
    "update.mode" = "none";
  });
in
{
  home.packages = [
    inputs.zen-browser.packages.${system}.default
    inputs.ayugram-desktop.packages.${system}.default
  ]
  ++ (with pkgs; [
    pear-desktop
    mihomo

    aseprite
    krita
    # inkscape
    kdePackages.kdenlive
    element-desktop
    reaper

    osu-lazer-bin
    obsidian
    anki-bin
    blockbench

    kdePackages.dolphin
    kdePackages.kde-cli-tools
    # Supplies kbuildsycoca6, which indexes desktop files and MIME handlers
    # for Dolphin's "Open With" menu and terminal integration.
    kdePackages.kservice
    kdePackages.ark
    kdePackages.kio-admin
    kdePackages.kio-extras
    kdePackages.ffmpegthumbs
    kdePackages.kdegraphics-thumbnailers
    kdePackages.plasma-browser-integration

    imv
    mpv
    obs-studio
    pavucontrol
    helvum
    networkmanagerapplet

    wl-clipboard
    cliphist
    grim
    slurp
    swappy
    brightnessctl
    playerctl

    btop
    fastfetch
    tree
    unzip
    zip
    p7zip
    ffmpeg
    imagemagick
    yt-dlp
    gotop
    scrcpy

    adw-gtk3
    whitesur-icon-theme
    capitaine-cursors
  ]);

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "martrtr";
        email = "mart.buffer.v3@gmail.com";
      };
      init.defaultBranch = "main";
      pull.rebase = false;
      fetch.prune = true;
      credential.helper = "store";
    };
  };

  programs.vscodium = {
    enable = true;
    mutableExtensionsDir = true;
  };

  # iNiR updates VSCodium's color theme in settings.json. Keep the initial
  # preferences reproducible, then leave the actual file writable for iNiR and
  # VSCodium instead of linking it to the read-only Nix store.
  home.activation.seedMutableVSCodiumSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings_file="${config.xdg.configHome}/VSCodium/User/settings.json"
    ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$settings_file")"

    if [ -L "$settings_file" ]; then
      tmp="$(${pkgs.coreutils}/bin/mktemp)"
      ${pkgs.coreutils}/bin/cp --dereference "$settings_file" "$tmp"
      ${pkgs.coreutils}/bin/rm -f "$settings_file"
      ${pkgs.coreutils}/bin/cp "$tmp" "$settings_file"
      ${pkgs.coreutils}/bin/rm -f "$tmp"
      ${pkgs.coreutils}/bin/chmod u+w "$settings_file"
    elif [ ! -e "$settings_file" ]; then
      ${pkgs.coreutils}/bin/cp "${vscodiumInitialSettings}" "$settings_file"
      ${pkgs.coreutils}/bin/chmod u+w "$settings_file"
    fi
  '';

  programs.keepassxc = {
    enable = true;
    autostart = true;
  };

  # Seed a normal writable config only on the first activation. Home Manager
  # does not own the file afterwards, so KeePassXC can change its settings from
  # the GUI without hitting a read-only /nix/store symlink.
  home.activation.seedKeePassXCConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    config_file="${config.xdg.configHome}/keepassxc/keepassxc.ini"
    if [ ! -e "$config_file" ]; then
      run mkdir -p "$(dirname "$config_file")"
      run cp "${keepassxcInitialConfig}" "$config_file"
      run chmod u+w "$config_file"
    fi
  '';

  # Let applications using libsecret/org.freedesktop.secrets launch KeePassXC.
  # GNOME Keyring is disabled at the NixOS level to avoid two providers racing
  # for the same DBus name.
  xdg.dataFile."dbus-1/services/org.freedesktop.secrets.service".text = ''
    [D-BUS Service]
    Name=org.freedesktop.secrets
    Exec=${pkgs.keepassxc}/bin/keepassxc
  '';

  # Dolphin writes a selected "Open With" application to mimeapps.list.
  # Keep that file mutable; Home Manager's generated symlink rejects writes.
  xdg.mimeApps.enable = false;

  xdg.desktopEntries.imv-dir = {
    name = "imv-dir";
    exec = "imv-dir %F";
    mimeType = [ "image/png" ];
    noDisplay = false;
  };

  home.activation.prepareMutableMimeApps = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    for mime_file in \
      "${config.xdg.configHome}/mimeapps.list" \
      "${config.xdg.dataHome}/applications/mimeapps.list"
    do
      ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$mime_file")"

      if [ -L "$mime_file" ]; then
        tmp="$(${pkgs.coreutils}/bin/mktemp)"
        ${pkgs.coreutils}/bin/cp --dereference "$mime_file" "$tmp"
        ${pkgs.coreutils}/bin/rm -f "$mime_file"
        ${pkgs.coreutils}/bin/mv "$tmp" "$mime_file"
      elif [ ! -e "$mime_file" ] && [ "$mime_file" = "${config.xdg.configHome}/mimeapps.list" ]; then
        ${pkgs.coreutils}/bin/printf '%s\n' \
          '[Default Applications]' \
          'inode/directory=org.kde.dolphin.desktop' \
          > "$mime_file"
      fi

    done
  '';

  programs.kitty = {
    enable = true;
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 11;
    };
    settings = {
      confirm_os_window_close = 0;
      enable_audio_bell = false;
      scrollback_lines = 10000;
      wayland_titlebar_color = "system";
    };
    # iNiR atomically updates current-theme.conf. Declaring the include here
    # avoids its generator trying to edit Home Manager's read-only kitty.conf.
    extraConfig = ''
      include current-theme.conf
    '';
  };

  home.activation.seedKittyThemeFile = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    theme_file="${config.xdg.configHome}/kitty/current-theme.conf"
    if [ ! -e "$theme_file" ]; then
      ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$theme_file")"
      ${pkgs.coreutils}/bin/touch "$theme_file"
    fi
  '';

  programs.bash.enable = true;
  programs.fish.enable = true;

  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name = "WhiteSur-dark";
      package = pkgs.whitesur-icon-theme;
    };
    font = {
      name = "Rubik";
      size = 11;
    };
  };

  home.pointerCursor = {
    # `capitaine-cursors-light` is not a theme directory in this package.
    # Refer to the actual theme so Niri gets all pointer, move and resize
    # cursor glyphs instead of falling back to an incomplete default cursor.
    enable = true;
    name = "capitaine-cursors";
    package = pkgs.capitaine-cursors;
    size = 20;
    gtk.enable = true;
    x11.enable = true;
  };
}
