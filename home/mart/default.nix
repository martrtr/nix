{ settings, ... }:
{
  imports = [
    ./programs.nix
    ./development.nix
    ./comfyui.nix
    ./discord.nix
    ./niri.nix
    ./niri-rules.nix
    ./inir.nix
    ./qt-theme.nix
    ./kitty.nix
    ./session-services.nix
    ./application-themes.nix
    ./audio.nix
    ./music.nix
    ./no-network-tray.nix
    ./clash-verge.nix
  ];

  home.username = settings.username;
  home.homeDirectory = "/home/${settings.username}";
  home.stateVersion = settings.stateVersion;

  programs.home-manager.enable = true;

  xdg = {
    enable = true;
    autostart.enable = true;
  };

  home.sessionVariables = {
    BROWSER = "zen";
    TERMINAL = "kitty";
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };
}
