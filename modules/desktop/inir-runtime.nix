{ config, ... }:
let
  runtime = "${config.programs.inir.package}/share/quickshell/inir";
in
{
  # The upstream launcher otherwise prefers a stale mutable payload in
  # ~/.config/quickshell/inir for interactive commands, while the systemd unit
  # runs the Nix-store payload. Keep CLI hotkeys and the service on one runtime.
  environment.sessionVariables = {
    INIR_RUNTIME_DIR = runtime;
    INIR_SYSTEM_RUNTIME_DIR = runtime;
    INIR_FALLBACK_SYSTEM_RUNTIME_DIR = runtime;
  };

  systemd.user.services.inir.serviceConfig.Environment = [
    "INIR_RUNTIME_DIR=${runtime}"
    "INIR_SYSTEM_RUNTIME_DIR=${runtime}"
    "INIR_FALLBACK_SYSTEM_RUNTIME_DIR=${runtime}"
  ];
}
