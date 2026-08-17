{ lib, ... }:
{
  # This KDL setting is represented by a flag node without arguments.
  programs.niri.settings.debug.honor-xdg-activation-with-invalid-serial = lib.mkForce [ ];

  # Keep the replacement proxy GUI on the same workspace previously used for
  # Throne. This is appended separately so the main Niri layout stays readable.
  programs.niri.settings.window-rules = lib.mkAfter [
    {
      matches = [
        { app-id = "^io\\.github\\.clash-verge-rev\\.clash-verge-rev$"; }
      ];
      open-on-workspace = "8";
    }
  ];
}
