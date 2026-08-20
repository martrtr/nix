{
  lib,
  pkgs,
  ...
}:
let
  # Native Linux production stack for REAPER. Keep everything in Nix so a
  # rebuild restores the same synths, samplers and effects without manual VST
  # installers or Wine.
  audioPlugins = with pkgs; [
    # Main synth and experimental modular environment.
    surge-xt
    cardinal

    # Breakcore / IDM drums and break slicing.
    ninjas2
    drumkv1
    geonkick

    # Sample-library players: practical native alternatives to Kontakt for
    # DecentSampler and SFZ libraries.
    decent-sampler
    sfizz-ui

    # Mixing and sound-design effects.
    lsp-plugins
    wolf-shaper
    chow-tape-model
    airwindows-lv2
  ];

  pluginRoots = lib.concatStringsSep " " (map toString audioPlugins);

  # Yamaha C5, 16 velocity layers. SFZ is loaded directly in sfizz from REAPER.
  salamanderGrandPiano = pkgs.stdenvNoCC.mkDerivation {
    pname = "salamander-grand-piano";
    version = "2020-06-02";

    src = pkgs.fetchurl {
      url = "https://freepats.zenvoid.org/Piano/SalamanderGrandPiano/SalamanderGrandPiano-SFZ+FLAC-V3+20200602.tar.gz";
      hash = "sha256-t3YOFoSUzwlTROIXsK8BP8RJrQM6u73xxlIRzxHcA4s=";
    };

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -R ./* "$out/"
      runHook postInstall
    '';
  };

  # Official Kasane Teto OpenUtau Japanese integrated library.
  kasaneTeto = pkgs.stdenvNoCC.mkDerivation {
    pname = "openutau-singer-kasane-teto";
    version = "2024-03-23";

    src = pkgs.fetchzip {
      url = "https://kasaneteto.jp/ongendl/index.cgi/extra/TETO-OUset240323.zip";
      hash = "sha256-4kGitQsi/44RAcNHGxdkE/s1KdZhpjKRuAv9CgQCbnI=";
      stripRoot = false;
    };

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -R "$src/重音テト OU用日本語統合ライブラリー/." "$out/"
      runHook postInstall
    '';
  };
in
{
  home.packages = audioPlugins ++ [ pkgs.openutau ];

  # REAPER scans these conventional per-user directories on Linux. Link only
  # individual plugin bundles/files, leaving any manually installed plugins
  # untouched. Existing Nix-managed symlinks are refreshed on every activation.
  home.activation.linkReaperAudioPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    for plugin_root in ${pluginRoots}; do
      for format in vst vst3 lv2 clap; do
        source_dir="$plugin_root/lib/$format"
        target_dir="$HOME/.$format"

        [ -d "$source_dir" ] || continue
        ${pkgs.coreutils}/bin/mkdir -p "$target_dir"

        for plugin in "$source_dir"/*; do
          [ -e "$plugin" ] || continue
          name="$(${pkgs.coreutils}/bin/basename "$plugin")"
          destination="$target_dir/$name"

          # Never replace a real file/directory belonging to a manual install.
          if [ ! -e "$destination" ] || [ -L "$destination" ]; then
            ${pkgs.coreutils}/bin/ln -sfn "$plugin" "$destination"
          fi
        done
      done
    done
  '';

  # Keep the sample library at a human-friendly location as well as in the Nix
  # store; sfizz can open the .sfz file from this directory.
  home.file."Music/Instruments/SalamanderGrandPiano".source = salamanderGrandPiano;

  # OpenUtau discovers singers below XDG_DATA_HOME/OpenUtau/Singers.
  xdg.dataFile."OpenUtau/Singers/重音テト OU用日本語統合ライブラリー".source = kasaneTeto;
}
