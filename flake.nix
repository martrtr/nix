{
  description = "Mart's reproducible NixOS + Niri + iNiR system";

  nixConfig = {
    extra-substituters = [
      "https://ayugram-desktop.cachix.org"
      "https://tg-owt.cachix.org"
    ];
    extra-trusted-public-keys = [
      "ayugram-desktop.cachix.org-1:AZ5EqHrJsAKL5YkZYLPEsb1FdD9QlypUwQ0REcJftgA="
      "tg-owt.cachix.org-1:lp0BukIhSK3EIyLcDhDZ5zABgT48nmNp6t4SnZ0wr8w="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri.url = "github:sodiboo/niri-flake";

    # Keep iNiR on the package set selected by its own flake. Upstream's NixOS
    # module is designed around inputs.inir.packages.${system}.default.
    inir.url = "github:snowarch/iNiR";

    nixcord = {
      url = "github:4evy/nixcord";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs."nixpkgs-nixcord".follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ayugram-desktop = {
      url = "github:ndfined-crp/ayugram-desktop";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      disko,
      niri,
      inir,
      ...
    }:
    let
      settings = import ./settings.nix;
      inherit (settings) system username;
      pkgs = nixpkgs.legacyPackages.${system};

      # Gradle's Minecraft runClient task launches LWJGL directly, outside the
      # wrapper used by PrismLauncher. Supply the same graphics, input and audio
      # libraries without setting a dangerous global LD_LIBRARY_PATH.
      minecraftRuntimeLibs = with pkgs; [
        (lib.getLib stdenv.cc.cc)
        glfw3-minecraft
        openal
        alsa-lib
        libjack2
        libpulseaudio
        pipewire
        libGL
        libx11
        libxcursor
        libxext
        libxrandr
        libxxf86vm
        wayland
        udev
        vulkan-loader
        libusb1
      ];

      # PyTorch's ROCm wheels provide most user-space components themselves, but
      # still need the host AMD driver nodes and a few dynamic libraries exposed
      # in a conventional layout when running on NixOS.
      rocmRuntimeLibs = with pkgs; [
        (lib.getLib stdenv.cc.cc)
        zlib
        rocmPackages.clr
      ];

      mkHost =
        hostModule: inirPythonInterpreter:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs settings inirPythonInterpreter; };
          modules = [
            hostModule
            disko.nixosModules.disko
            niri.nixosModules.niri
            inir.nixosModules.inir
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "hm-backup";
              home-manager.extraSpecialArgs = { inherit inputs settings; laptopHost = hostModule == ./hosts/laptop; };
              home-manager.users.${username} = import (./home + "/${username}");
            }
          ];
        };
    in
    {
      # Keep the old desktop package set unchanged.
      nixosConfigurations.desktop = mkHost ./hosts/desktop pkgs.python3;
      # Python 3.13 is currently safer for the iNiR third-party ecosystem.
      nixosConfigurations.laptop = mkHost ./hosts/laptop pkgs.python313;

      packages.${system} = {
        inir = self.nixosConfigurations.desktop.config.programs.inir.package;
        disko = disko.packages.${system}.disko;
        disko-install = disko.packages.${system}.disko-install;
        installer-iso = self.nixosConfigurations.installer.config.system.build.isoImage;
        offline-installer-iso = self.nixosConfigurations.offline-installer.config.system.build.isoImage;
      };

      # Dynamic attribute names cannot be reopened multiple times in one attrset.
      # Keep every development shell under one devShells.${system} declaration.
      devShells.${system} = {
        minecraft = pkgs.mkShell {
          packages = with pkgs; [
            jdk21
            pciutils
            xrandr
          ];

          JAVA_HOME = "${pkgs.jdk21}/lib/openjdk";
          LD_LIBRARY_PATH = "${pkgs.addDriverRunpath.driverLink}/lib:${pkgs.lib.makeLibraryPath minecraftRuntimeLibs}";
        };

        rocm = pkgs.mkShell {
          packages = with pkgs; [
            python312
            uv
            rocmPackages.rocminfo
            rocmPackages.rocm-smi
          ];

          # Select the PyTorch backend explicitly per install, or pin the ROCm
          # index in pyproject.toml. A global backend can affect unrelated packages
          # when a mixed uv pip command resolves against the PyTorch wheel index.
          LD_LIBRARY_PATH = "/run/opengl-driver/lib:${pkgs.lib.makeLibraryPath rocmRuntimeLibs}";
        };
      };

      nixosConfigurations.installer = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs settings; };
        modules = [ ./installer/iso.nix ];
      };

      nixosConfigurations.offline-installer = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs settings; };
        modules = [ ./installer/offline.nix ];
      };

      formatter.${system} = pkgs.nixfmt-rfc-style;
      checks.${system} = {
        inir = self.packages.${system}.inir;
        desktop = self.nixosConfigurations.desktop.config.system.build.toplevel;
      };
    };
}
