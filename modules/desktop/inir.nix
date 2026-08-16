{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;

  optionalTop = name:
    lib.optional (builtins.hasAttr name pkgs) (builtins.getAttr name pkgs);
  optionalKde = name:
    lib.optional
      (builtins.hasAttr "kdePackages" pkgs && builtins.hasAttr name pkgs.kdePackages)
      (builtins.getAttr name pkgs.kdePackages);
  optionalPython = name:
    lib.optional
      (builtins.hasAttr name pkgs.python3Packages)
      (builtins.getAttr name pkgs.python3Packages);

  # Equivalent of upstream sdata/uv/requirements.in, built by Nix rather than
  # downloaded into a mutable per-user venv.
  inirPython = pkgs.python3.withPackages (_:
    lib.concatLists (map optionalPython [
      "click"
      "evdev"
      "kde-material-you-colors"
      "loguru"
      "material-color-utilities"
      "materialyoucolor"
      "numpy"
      "opencv4"
      "pillow"
      "psutil"
      "pycairo"
      "pygobject3"
      "tqdm"
    ]));

  # Several upstream scripts source $INIR_VENV/bin/activate before invoking
  # Python. Provide that interface while keeping the actual environment in the
  # immutable Nix store.
  inirVenv = pkgs.runCommand "inir-python-venv" { } ''
    mkdir -p "$out/bin"
    ln -s ${inirPython}/bin/python "$out/bin/python"
    ln -s ${inirPython}/bin/python3 "$out/bin/python3"
    cat > "$out/bin/activate" <<EOF
export VIRTUAL_ENV="$out"
export PATH="${inirPython}/bin:\$PATH"
EOF
  '';

  # Direct translation of the dependency bundles used by upstream's normal
  # installer. Arch-only packages such as pacman-contrib are intentionally
  # omitted; every available NixOS equivalent is exposed both system-wide and
  # in the inir.service PATH.
  inirRuntimePackages = with pkgs; [
    bash
    bc
    coreutils
    curl
    findutils
    gawk
    git
    glib
    gnugrep
    gnused
    jq
    procps
    inirPython
    ripgrep
    rsync
    systemd
    wget
    xdg-utils

    awww
    cava
    cliphist
    ddcutil
    easyeffects
    ffmpeg
    fish
    fuzzel
    go
    gowall
    grim
    gum
    imagemagick
    kitty
    libnotify
    libqalculate
    mission-center
    mpv
    networkmanager
    playerctl
    pavucontrol
    slurp
    socat
    songrec
    swayidle
    swaylock
    swappy
    tesseract
    translate-shell
    upower
    uv
    wf-recorder
    wireplumber
    wl-clipboard
    wlsunset
    wtype
    xwayland-satellite
    ydotool
  ]
  ++ optionalTop "brightnessctl"
  ++ optionalTop "geoclue2"
  ++ optionalTop "hyprpicker"
  ++ optionalKde "breeze-icons"
  ++ optionalKde "kconfig"
  ++ optionalKde "kdialog"
  ++ optionalKde "kirigami"
  ++ optionalKde "plasma-integration"
  ++ optionalKde "syntax-highlighting"
  ++ optionalKde "xembedsniproxy"
  ++ optionalTop "darkly"
  # qt6ct was moved out of the top-level package set. Referring to pkgs.qt6ct
  # now intentionally throws a renamed-attribute error during Nix evaluation.
  ++ [ pkgs.qt6Packages.qt6ct ];

  upstreamInirPackage = inputs.inir.packages.${system}.default;

  # The upstream package exposes the exact runtime closure used to build its
  # bundled Quickshell. QML plugins are ABI-sensitive, so Kirigami and Qt must
  # come from this package set rather than from the host system's nixpkgs.
  upstreamInirRuntimePackages = upstreamInirPackage.passthru.runtimeDependencies or [ ];
  inirQuickshell = lib.findFirst
    (package: (package.pname or "") == "quickshell")
    pkgs.quickshell
    upstreamInirRuntimePackages;
  # Current nixpkgs exposes Kirigami as an empty wrapper derivation whose actual
  # QML payload lives in passthru.unwrapped. Include that payload and propagated
  # dependencies such as qqc2-desktop-style when constructing the QML runtime.
  expandQmlPackage = package:
    [ package ]
    ++ lib.optional (package ? unwrapped) package.unwrapped
    ++ (package.propagatedBuildInputs or [ ]);
  upstreamInirQmlPackages = lib.concatMap expandQmlPackage upstreamInirRuntimePackages;
  hasQtPath = path: package: builtins.pathExists "${package}/${path}";
  inirQmlPackages = lib.filter (package:
    hasQtPath "lib/qt-6/qml" package || hasQtPath "lib/qt6/qml" package
  ) upstreamInirQmlPackages;
  inirQtPluginPackages = lib.filter (package:
    hasQtPath "lib/qt-6/plugins" package || hasQtPath "lib/qt6/plugins" package
  ) upstreamInirQmlPackages;

  inirQmlPath = lib.concatStringsSep ":" [
    (lib.makeSearchPath "lib/qt-6/qml" inirQmlPackages)
    (lib.makeSearchPath "lib/qt6/qml" inirQmlPackages)
  ];
  inirQtPluginPath = lib.concatStringsSep ":" [
    (lib.makeSearchPath "lib/qt-6/plugins" inirQtPluginPackages)
    (lib.makeSearchPath "lib/qt6/plugins" inirQtPluginPackages)
  ];

  inirPackage = upstreamInirPackage.overrideAttrs (oldAttrs: {
    postPatch = (oldAttrs.postPatch or "") + ''
      bash ${./customize-inir-runtime.sh} ${pkgs.python3}/bin/python3

      sed -i '1c\#!${pkgs.python3}/bin/python3' \
        scripts/hyprland/get_keybinds.py \
        scripts/colors/generate_colors_material.py

      sed -i '/property string accentColor: ""/a\                    property string mode: "dark" // Shell color mode' \
        modules/common/Config.qml
      sed -i 's/"accentColor": ""/"accentColor": "",\n            "mode": "dark"/' \
        defaults/config.json
      sed -i '/function setDarkMode(dark: bool): void {/a\        Config.setNestedValue("appearance.palette.mode", dark ? "dark" : "light")' \
        services/MaterialThemeLoader.qml
      sed -i '/const paletteType = Config.options?.appearance?.palette?.type ?? "auto"/a\            const paletteMode = Config.options?.appearance?.palette?.mode ?? "dark"' \
        services/ThemeService.qml
      sed -i '/command.push("--type", paletteType)/a\            if (paletteMode === "dark" || paletteMode === "light")\n                command.push("--mode", paletteMode)' \
        services/ThemeService.qml
      sed -i 's#"/usr/bin/gsettings"#"gsettings"#g' \
        services/IconThemeService.qml
      sed -i '/''${font_name:+fixed=/iTerminalApplication=kitty -1' \
        scripts/colors/apply-gtk-theme.sh
    '';

    postInstall = (oldAttrs.postInstall or "") + ''
      runtime="$out/share/quickshell/inir"

      # Upstream's setup installer copies the root QML entry points, while the
      # flake's runtime-root-files list currently omits them.
      for root_file in ./*.qml ./qmldir; do
        [ -f "$root_file" ] || continue
        install -Dm644 "$root_file" "$runtime/$(basename "$root_file")"
      done

      mv "$runtime/scripts/inir" "$runtime/scripts/.inir-launcher"
      cat > "$runtime/scripts/inir" <<EOF
#!${pkgs.bash}/bin/bash
export PATH="${inirQuickshell}/bin:\$PATH"

if [ "\''${1:-}" = "settings" ] || [ "\''${1:-}" = "open" ]; then
  exec ${inirQuickshell}/bin/qs -p "$runtime" ipc call settings open
fi

case "\''${1:-}" in
  run|start|restart|repair|settings-window|waffle-settings-window|welcome|test-local)
    export QML_IMPORT_PATH="$runtime/qml:${inirQmlPath}"
    export QML2_IMPORT_PATH="$runtime/qml:${inirQmlPath}"
    export QT_PLUGIN_PATH="${inirQtPluginPath}"
    ;;
esac

exec "$runtime/scripts/.inir-launcher" "\$@"
EOF
      chmod +x "$runtime/scripts/inir" "$runtime/scripts/.inir-launcher"

      # Apply the same /usr/bin portability rewrite that upstream applies to
      # QML files copied earlier in its installPhase.
      find "$runtime" -maxdepth 1 -type f \
        \( -name '*.qml' -o -name '*.js' \) \
        -exec sed -i 's#/usr/bin/##g' {} +

      # Link each top-level org.kde module as a complete tree. Linking nested
      # qmldir directories first creates real parent directories and prevents
      # the root Kirigami module, which owns its qmldir, from being linked.
      qml_root="$runtime/qml"
      mkdir -p "$qml_root/org/kde"

      for dependency in ${lib.escapeShellArgs (map toString upstreamInirQmlPackages)}; do
        while IFS= read -r qmldir; do
          module_dir="$(dirname "$qmldir")"
          case "$module_dir" in
            */qml/org/kde/*)
              qml_prefix="''${module_dir%%/org/kde/*}"
              module_tail="''${module_dir#*/qml/org/kde/}"
              module_name="''${module_tail%%/*}"
              ;;
            *) continue ;;
          esac

          [ -n "$module_name" ] || continue
          source="$qml_prefix/org/kde/$module_name"
          target="$qml_root/org/kde/$module_name"

          if [ ! -e "$target" ] && [ -d "$source" ]; then
            ln -s "$source" "$target"
            echo "Bundled QML module: org/kde/$module_name <- $source"
          fi
        done < <(
          find -L "$dependency" -type f \
            -path '*/qml/org/kde/*/qmldir' \
            -print 2>/dev/null || true
        )
      done

      # Fail at build time instead of shipping a runtime that can only enter a
      # systemd restart loop. Print useful diagnostics when Kirigami is absent.
      if [ ! -f "$qml_root/org/kde/kirigami/qmldir" ]; then
        echo "ERROR: org.kde.kirigami was not found in the expanded upstream QML packages" >&2
        printf '  %s\n' ${lib.escapeShellArgs (map toString upstreamInirQmlPackages)} >&2
        find "$qml_root" -maxdepth 5 -print >&2 || true
        exit 1
      fi

      test -f "$runtime/shell.qml"
      test -f "$runtime/settings.qml"
      test -f "$runtime/defaults/config.json"
      test -d "$runtime/modules"
      test -d "$runtime/services"
      test -x "$out/bin/inir"
    '';

    postFixup = (oldAttrs.postFixup or "") + ''
      # The full QML/plugin search path is needed when starting a shell process,
      # but it makes every short-lived `qs --version` and `qs ipc call` client
      # pay a very large Qt startup cost. Scope it to commands that actually
      # launch QML; keep status, IPC targets, terminal and close-window lean.
      mv "$out/bin/inir" "$out/bin/.inir-launcher"
      cat > "$out/bin/inir" <<EOF
#!${pkgs.bash}/bin/bash
export INIR_VENV="${inirVenv}"
export ILLOGICAL_IMPULSE_VIRTUAL_ENV="${inirVenv}"

case "\''${1:-}" in
  run|start|restart|repair|settings-window|waffle-settings-window|welcome|test-local)
    export QML_IMPORT_PATH="$out/share/quickshell/inir/qml:${inirQmlPath}"
    export QML2_IMPORT_PATH="$out/share/quickshell/inir/qml:${inirQmlPath}"
    export QT_PLUGIN_PATH="${inirQtPluginPath}"
    ;;
  *)
    unset QML_IMPORT_PATH QML2_IMPORT_PATH QT_PLUGIN_PATH
    ;;
esac

exec "$out/bin/.inir-launcher" "\$@"
EOF
      chmod +x "$out/bin/inir"
    '';
  });

  inirBundledQmlPath = "${inirPackage}/share/quickshell/inir/qml";
  inirFullQmlPath = "${inirBundledQmlPath}:${inirQmlPath}";
in
{
  programs.niri.enable = true;

  # iNiR provides the session's Polkit interface.  niri-flake otherwise starts
  # a separate KDE agent, which takes precedence over the shell dialog.
  systemd.user.services.niri-flake-polkit.enable = false;

  # Official upstream NixOS integration: package, user unit and
  # niri.service.wants/inir.service compositor wiring.
  programs.inir = {
    enable = true;
    package = inirPackage;
    service.compositor = "niri";
    extraPackages =
      [ config.programs.niri.package ]
      ++ upstreamInirRuntimePackages
      ++ inirRuntimePackages;
  };

  # The unit receives the bundled module root first, followed by the full
  # ABI-matched upstream Qt paths.
  systemd.user.services.inir.serviceConfig.Environment = [
    "QML_IMPORT_PATH=${inirFullQmlPath}"
    "QML2_IMPORT_PATH=${inirFullQmlPath}"
    "QT_PLUGIN_PATH=${inirQtPluginPath}"
    "INIR_VENV=${inirVenv}"
    "ILLOGICAL_IMPULSE_VIRTUAL_ENV=${inirVenv}"
  ];

  environment.sessionVariables = {
    INIR_VENV = "${inirVenv}";
    ILLOGICAL_IMPULSE_VIRTUAL_ENV = "${inirVenv}";
  };

  environment.systemPackages = inirRuntimePackages;
}
