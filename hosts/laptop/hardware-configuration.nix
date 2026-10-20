{ ... }:
{
  # SAFETY: generated on the actual laptop by laptop/bootstrap.sh.
  # Never install from this placeholder: it has no real filesystem UUIDs.
  assertions = [{
    assertion = false;
    message = "Mechrevo laptop: replace hosts/laptop/hardware-configuration.nix using laptop/bootstrap.sh on the INSTALLED NixOS system.";
  }];
}
