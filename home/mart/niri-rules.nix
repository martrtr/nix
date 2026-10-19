{ lib, ... }:
{
  # This KDL setting is represented by a flag node without arguments.
  programs.niri.settings.debug.honor-xdg-activation-with-invalid-serial = lib.mkForce [ ];
}
