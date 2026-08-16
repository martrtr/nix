{
  config,
  inputs,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  # These are defaults only. The activation merge uses the existing user JSON
  # as the right-hand side, so every explicit user value wins.
  inirThemeIntegrationDefaults = pkgs.writeText "inir-theme-integration-defaults.json" (builtins.toJSON {
    appearance.palette.mode = "dark";
    appearance.wallpaperTheming = {
      enableAppsAndShell = true;
      enableQtApps = true;
      enableTerminal = true;
      enableVesktop = true;
      enableChrome = true;
      enableVSCode = true;
      enableSteam = true;
      enablePearDesktop = true;
      terminals.kitty = true;
      vscodeEditors.codium = true;
    };
  });

  inirPackage = osConfig.programs.inir.package;
  inirRuntime = "${inirPackage}/share/quickshell/inir";
  inirRuntimeDependencies = inirPackage.passthru.runtimeDependencies or [ ];
  inirQuickshell = lib.findFirst
    (package: (package.pname or "") == "quickshell")
    pkgs.quickshell
    inirRuntimeDependencies;
  inirCli = pkgs.writeShellApplication {
    name = "inir";
    runtimeInputs = [
      pkgs.systemd
      inirQuickshell
    ];
    text = ''
      runtime="${inirRuntime}"
      export INIR_RUNTIME_DIR="$runtime"
      export INIR_SYSTEM_RUNTIME_DIR="$runtime"
      export INIR_FALLBACK_SYSTEM_RUNTIME_DIR="$runtime"

      if [ "''${1:-}" = "settings" ]; then
        exec ${inirQuickshell}/bin/qs -p "$runtime" ipc call settings open
      fi

      exec ${inirPackage}/bin/inir "$@"
    '';
  };
in
{
  imports = [ inputs.inir.homeModules.inir ];

  # The NixOS module is the sole owner of the package and inir.service. Home
  # Manager only supplies a deterministic CLI wrapper and mutable user config.
  # In particular, do not recreate ~/.config/quickshell/inir: the service uses
  # the store path as its runtime root.
  programs.inir.enable = false;
  home.packages = [ inirCli ];

  assertions = [
    {
      assertion = !(config.systemd.user.services ? inir);
      message = "inir.service is owned by the NixOS iNiR module, not Home Manager.";
    }
  ];

  home.activation.removeLegacyInirRuntimeSymlink = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    runtime_link="${config.xdg.configHome}/quickshell/inir"
    if [ -L "$runtime_link" ]; then
      ${pkgs.coreutils}/bin/rm -f "$runtime_link"
    fi
  '';

  # Keep the complete user config mutable. On a fresh install copy defaults once;
  # on existing systems add only missing integration keys and preserve every
  # explicit setting. Store a content-addressed backup before any merge.
  home.activation.prepareMutableInirConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    config_dir_new="${config.xdg.configHome}/inir"
    config_dir_legacy="${config.xdg.configHome}/illogical-impulse"
    if [ -d "$config_dir_legacy" ] && [ ! -L "$config_dir_legacy" ]; then
      config_dir="$config_dir_legacy"
    else
      config_dir="$config_dir_new"
    fi
    config_file="$config_dir/config.json"
    backup_dir="${config.home.homeDirectory}/.local/state/inir/config-backups"

    ${pkgs.coreutils}/bin/mkdir -p "$config_dir" "$backup_dir"

    if [ ! -e "$config_file" ]; then
      ${pkgs.coreutils}/bin/cp \
        "${osConfig.programs.inir.package}/share/quickshell/inir/defaults/config.json" \
        "$config_file"
      ${pkgs.coreutils}/bin/chmod u+w "$config_file"
    fi

    if ${pkgs.jq}/bin/jq empty "$config_file" >/dev/null 2>&1; then
      hash="$(${pkgs.coreutils}/bin/sha256sum "$config_file" | ${pkgs.coreutils}/bin/cut -d' ' -f1)"
      backup="$backup_dir/config-$hash.json"
      if [ ! -e "$backup" ]; then
        ${pkgs.coreutils}/bin/cp "$config_file" "$backup"
      fi

      tmp="$(${pkgs.coreutils}/bin/mktemp "$config_dir/config.json.XXXXXX")"
      if ${pkgs.jq}/bin/jq \
        --slurpfile defaults "${inirThemeIntegrationDefaults}" \
        '$defaults[0] * .' \
        "$config_file" > "$tmp"
      then
        ${pkgs.coreutils}/bin/chmod --reference="$config_file" "$tmp"
        if ! ${pkgs.diffutils}/bin/cmp -s "$config_file" "$tmp"; then
          ${pkgs.coreutils}/bin/mv "$tmp" "$config_file"
        else
          ${pkgs.coreutils}/bin/rm -f "$tmp"
        fi
      else
        ${pkgs.coreutils}/bin/rm -f "$tmp"
      fi
    fi
  '';

  # `inir doctor` targets the mutable repository installer. On NixOS its
  # generated files can shadow the wrapped launcher and point shells at a
  # nonexistent mutable virtual environment. Remove only its own files/blocks.
  home.activation.removeDoctorInirFiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    launcher="${config.home.homeDirectory}/.local/bin/inir"
    if [ -f "$launcher" ] && [ ! -L "$launcher" ] \
      && ${pkgs.gnugrep}/bin/grep -q 'Usage: inir' "$launcher" \
      && ${pkgs.gnugrep}/bin/grep -q 'cleanup-orphans' "$launcher"
    then
      ${pkgs.coreutils}/bin/rm -f "$launcher"
    fi

    fish_env="${config.xdg.configHome}/fish/conf.d/inir-env.fish"
    if [ -f "$fish_env" ] \
      && ${pkgs.gnugrep}/bin/grep -q 'auto-generated by doctor' "$fish_env"
    then
      ${pkgs.coreutils}/bin/rm -f "$fish_env"
    fi

    for profile in \
      "${config.home.homeDirectory}/.bashrc" \
      "${config.home.homeDirectory}/.zshrc"
    do
      if [ -f "$profile" ] && [ -w "$profile" ] \
        && ${pkgs.gnugrep}/bin/grep -q '^# iNiR environment$' "$profile" \
        && ${pkgs.gnugrep}/bin/grep -q '^# end iNiR$' "$profile"
      then
        ${pkgs.gnused}/bin/sed -i \
          '/^# iNiR environment$/,/^# end iNiR$/d' "$profile"
      fi
    done
  '';
}
