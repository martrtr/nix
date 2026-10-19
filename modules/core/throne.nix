{
  programs.throne = {
    enable = true;
    # Use NixOS capability wrappers for TUN instead of an upstream setuid core.
    tunMode.enable = true;
  };
}
