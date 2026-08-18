{
  pkgs,
  settings,
  ...
}:
{
  imports = [
    ./apps-directory.nix
    ./certificates.nix
    ./speech.nix
    ./clash-verge.nix
    ./kokoro.nix
  ];

  networking.hostName = settings.hostname;
  networking.networkmanager.enable = true;
  networking.firewall = {
    enable = true;
    checkReversePath = "loose";

    # Clash Verge / Mihomo TUN interfaces. Keep the historical relaxed
    # reverse-path filtering fix for Discord RTC and explicitly trust traffic
    # arriving from the TUN device so nftables does not drop return UDP.
    trustedInterfaces = [
      "Mihomo"
      "Meta"
    ];

    extraReversePathFilterRules = ''
      iifname { "Mihomo", "Meta" } accept comment "allow Clash Verge TUN"
    '';

    allowedTCPPorts = [
      # Minecraft server.
      25565
      # ComfyUI remote interface.
      8188
      # llama.cpp, compatible with Ollama clients on the local network.
      11434
    ];

    # Simple Voice Chat and Webcam mod use separate UDP sockets.
    allowedUDPPorts = [
      24454
      25454
    ];
  };

  time.timeZone = settings.timezone;
  i18n.defaultLocale = settings.locale;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    max-jobs = "auto";
    cores = 0;

    # These caches are also advertised by flake.nix. Register them in the
    # system daemon so unprivileged `nix develop` calls may use them without
    # requiring the user to be a Nix trusted-user.
    extra-substituters = [
      "https://ayugram-desktop.cachix.org"
      "https://tg-owt.cachix.org"
    ];
    extra-trusted-public-keys = [
      "ayugram-desktop.cachix.org-1:AZ5EqHrJsAKL5YkZYLPEsb1FdD9QlypUwQ0REcJftgA="
      "tg-owt.cachix.org-1:lp0BukIhSK3EIyLcDhDZ5zABgT48nmNp6t4SnZ0wr8w="
    ];
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  nixpkgs.config.allowUnfree = true;

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    initrd.systemd.enable = true;
    tmp.cleanOnBoot = true;
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
      };
      efi.canTouchEfiVariables = true;
      timeout = 3;
    };
    kernel.sysctl = {
      "fs.inotify.max_user_watches" = 1048576;
      "vm.swappiness" = 180;
      "vm.watermark_boost_factor" = 0;
      "vm.watermark_scale_factor" = 125;
      "vm.page-cluster" = 0;
    };
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
  };

  # ext4 on NVMe only needs periodic TRIM; there are no Btrfs scrub/snapshot jobs.
  services = {
    # SDDM needs Xorg, but the fallback xterm desktop/session is unwanted.
    xserver = {
      desktopManager.xterm.enable = false;
      excludePackages = [ pkgs.xterm ];
    };

    fstrim.enable = true;
    flatpak.enable = true;

    # Keep the host resolver independent from Clash Verge/Mihomo. When the TUN
    # process is stopped or fails during startup, /etc/resolv.conf must still
    # point at a live resolver instead of becoming an empty resolvconf file.
    # NetworkManager feeds per-link DNS into resolved; public DNS is only a
    # fallback when the active link does not provide usable resolvers.
    resolved = {
      enable = true;
      settings.Resolve.FallbackDNS = [
        "1.1.1.1"
        "8.8.8.8"
      ];
    };

    syncthing = {
      enable = true;
      user = settings.username;
      group = "users";
      dataDir = "/home/${settings.username}/Sync";
      configDir = "/home/${settings.username}/.config/syncthing";
      guiAddress = "127.0.0.1:8384";
      openDefaultPorts = true;
    };
  };

  programs = {
    fish.enable = true;
    git.enable = true;
    nix-ld.enable = true;

    # Gradle-based Minecraft mod development uses Java 21. The NixOS Java
    # module installs the full JDK and exports JAVA_HOME for all login shells.
    java = {
      enable = true;
      package = pkgs.jdk21;
    };

    appimage = {
      enable = true;
      binfmt = true;
    };
  };

  users.users.${settings.username} = {
    isNormalUser = true;
    description = settings.fullName;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "render"
      "audio"
      "input"
      "dialout"
    ];
    shell = pkgs.fish;
  };

  security.sudo.wheelNeedsPassword = true;

  environment.systemPackages = with pkgs; [
    android-tools
    git
    curl
    wget
    vim
    nano
    just
    pciutils
    usbutils
    lm_sensors
    smartmontools
    nvme-cli
    e2fsprogs
    nix-output-monitor
  ];

  system.stateVersion = settings.stateVersion;
}
