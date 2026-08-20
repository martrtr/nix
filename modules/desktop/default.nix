{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inirSddmTheme = pkgs.runCommand "inir-ii-pixel-sddm-theme" { } ''
    mkdir -p "$out/share/sddm/themes"
    cp -R "${inputs.inir}/dots/sddm/pixel" "$out/share/sddm/themes/ii-pixel"
  '';

  # iNiR's Arch installer treats these as its UI font set. Google Fonts allows
  # selecting the same families without downloading the entire collection.
  inirGoogleFonts = pkgs.google-fonts.override {
    fonts = [
      "Gabarito"
      "Oxanium"
      "Readex Pro"
      "Roboto Flex"
      "Space Grotesk"
    ];
  };
in
{
  imports = [
    ./askpass.nix
    ./inir.nix
    ./inir-runtime.nix
  ];

  # niri-flake still defaults to its 25.08 stable package. Use the released
  # Niri from our pinned nixpkgs instead; 25.11+ includes Smithay fixes for
  # nested popup stacking, including xwayland-satellite popups used by X11 DAWs.
  programs.niri.package = pkgs.niri;

  # Use the mature X11 SDDM greeter. Keep its login layout deliberately simple;
  # Niri itself provides US/Russian switching after login.
  services.xserver = {
    enable = true;
    xkb = {
      layout = "us";
      variant = "";
      options = "";
    };
  };

  services.displayManager = {
    defaultSession = "niri";
    sddm = {
      enable = true;
      wayland.enable = false;
      theme = "ii-pixel";
      extraPackages = with pkgs; [
        qt6.qt5compat
        qt6.qtdeclarative
        qt6.qtimageformats
        qt6.qtsvg
      ];
      settings.General.InputMethod = "";
    };
  };

  services.dbus.enable = true;
  security.polkit.enable = true;

  # Niri's default portal stack provides the compositor-specific services but
  # otherwise falls back to a GTK file chooser.  Route FileChooser explicitly
  # through the KDE backend so Electron/GTK/Flatpak applications get the
  # KIO-based file dialog used by Dolphin.  Keep GNOME for Niri-specific
  # interfaces such as screencasting, with GTK as a general fallback.
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = [
      pkgs.kdePackages.xdg-desktop-portal-kde
      pkgs.xdg-desktop-portal-gtk
    ];
    config.niri = {
      default = [
        "gnome"
        "gtk"
      ];
      "org.freedesktop.impl.portal.FileChooser" = "kde";
      "org.freedesktop.impl.portal.Settings" = "kde";
    };
  };

  # Removable media and desktop file access.
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.printing.enable = true;
  programs.dconf.enable = true;

  # niri-flake enables GNOME Keyring by default. Force it off so KeePassXC is
  # the only org.freedesktop.secrets provider in the user session.
  services.gnome.gnome-keyring.enable = lib.mkForce false;

  fonts = {
    packages = with pkgs; [
      inirGoogleFonts
      material-symbols
      geist-font
      nerd-fonts.jetbrains-mono
      roboto
      rubik
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      liberation_ttf
      dejavu_fonts
    ];

    fontconfig.defaultFonts = {
      sansSerif = [
        "Roboto Flex"
        "Noto Sans"
      ];
      serif = [ "Noto Serif" ];
      monospace = [
        "JetBrainsMono Nerd Font"
        "Noto Sans Mono"
      ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

  environment.systemPackages = [
    inirSddmTheme
  ] ++ (with pkgs; [
    gparted
    ntfs3g
    exfatprogs
  ]);

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    # Make GTK-based pickers (including Electron applications using GTK) use
    # the portal above instead of opening a separate, non-native dialog.
    GTK_USE_PORTAL = "1";
    QT_QPA_PLATFORM = "wayland;xcb";
  };
}
