{ pkgs, ... }:
let
  davinciResolve = pkgs.callPackage ../../pkgs/davinci-resolve.nix { };

  resolveIngest = pkgs.writeShellApplication {
    name = "resolve-ingest";
    runtimeInputs = with pkgs; [
      coreutils
      ffmpeg
    ];
    text = ''
            set -euo pipefail

            if [ "$#" -eq 0 ]; then
              cat >&2 <<'EOF'
      Usage: resolve-ingest FILE [FILE ...]

      Transcodes footage to a Resolve-on-Linux friendly intermediate:
        video: DNxHR HQX, 10-bit 4:2:2
        audio: PCM 24-bit, 48 kHz
        container: QuickTime MOV

      Output directory defaults to ./resolve-ingest.
      Override it with RESOLVE_INGEST_DIR=/path/to/dir.
      EOF
              exit 2
            fi

            outdir="''${RESOLVE_INGEST_DIR:-$PWD/resolve-ingest}"
            mkdir -p "$outdir"

            for src in "$@"; do
              if [ ! -f "$src" ]; then
                echo "resolve-ingest: not a file: $src" >&2
                continue
              fi

              base="$(basename "$src")"
              stem="''${base%.*}"
              out="$outdir/''${stem}_dnxhr.mov"

              fps="$(ffprobe -v error -select_streams v:0 \
                -show_entries stream=avg_frame_rate -of default=nw=1:nk=1 "$src" | head -n 1)"
              if [ -z "$fps" ] || [ "$fps" = "0/0" ]; then
                fps="30"
              fi

              echo "==> $src"
              echo "    -> $out"
              ffmpeg -hide_banner -y -i "$src" \
                -map 0:v:0 -map '0:a?' -map_metadata 0 \
                -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" \
                -r "$fps" -fps_mode cfr \
                -c:v dnxhd -profile:v dnxhr_hqx -pix_fmt yuv422p10le \
                -c:a pcm_s24le -ar 48000 \
                "$out"
            done
    '';
  };

  resolveLauncher = pkgs.writeShellApplication {
    name = "davinci-resolve-nixos";
    runtimeInputs = [ davinciResolve ];
    text = ''
      export QT_QPA_PLATFORM=xcb
      exec davinci-resolve "$@"
    '';
  };

  resolveDolphinImport = pkgs.writeShellApplication {
    name = "resolve-dolphin-import";
    runtimeInputs = with pkgs; [
      coreutils
      libnotify
      xdotool
    ];
    text = ''
      set -euo pipefail

      if [ "$#" -eq 0 ]; then
        exit 0
      fi

      cache="$HOME/.cache/DaVinciResolve/resolve-ingest"
      mkdir -p "$cache"

      if ! pgrep -f '/bin/resolve' >/dev/null 2>&1; then
        notify-send "DaVinci Resolve" "Сначала открой проект в DaVinci Resolve."
        exit 1
      fi

      window="$(xdotool search --onlyvisible --class resolve 2>/dev/null | tail -n 1 || true)"
      if [ -z "$window" ]; then
        notify-send "DaVinci Resolve" "Окно Resolve не найдено. Запусти DaVinci через меню программ."
        exit 1
      fi

      for src in "$@"; do
        [ -f "$src" ] || continue
        RESOLVE_INGEST_DIR="$cache" resolve-ingest "$src"
        base="$(basename "$src")"
        stem="''${base%.*}"
        out="$cache/''${stem}_dnxhr.mov"
        [ -f "$out" ] || continue

        xdotool windowactivate --sync "$window"
        sleep 0.4
        xdotool key --window "$window" ctrl+i
        sleep 0.7
        xdotool type --delay 1 --clearmodifiers "$out"
        sleep 0.2
        xdotool key Return
        sleep 0.8
      done

      notify-send "DaVinci Resolve" "Видео перекодировано и отправлено в текущий проект."
    '';
  };
in
{
  home.packages = [
    davinciResolve
    resolveIngest
    resolveLauncher
    resolveDolphinImport
  ];

  systemd.user.services.resolvelink = {
    Unit = {
      Description = "ResolveLink bridge for DaVinci Resolve and REAPER";
      After = [ "network.target" ];
    };
    Service = {
      Type = "simple";
      WorkingDirectory = "/home/mart/.local/share/ResolveLink";
      ExecStart = "${pkgs.nodejs}/bin/node /home/mart/.local/share/ResolveLink/server/index.js";
      Restart = "on-failure";
      RestartSec = 2;
      TimeoutStopSec = 3;
    };
    Install.WantedBy = [ "default.target" ];
  };

  xdg.dataFile."DaVinciResolve/Fusion/Scripts/Utility/Import Any Video.py".source =
    ./resolve-import-any-video.py;

  # Override the upstream desktop file so every launcher uses the NixOS/XWayland wrapper.
  xdg.dataFile."applications/davinci-resolve.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Version=1.5
    Name=DaVinci Resolve
    GenericName=Video Editor
    Comment=DaVinci Resolve 21 via XWayland for Niri/NixOS
    Exec=davinci-resolve-nixos %U
    Icon=davinci-resolve
    Terminal=false
    StartupWMClass=resolve
    Categories=AudioVideo;AudioVideoEditing;Video;Graphics;
  '';

  # Hide the old duplicate custom launcher from application menus.
  xdg.dataFile."applications/davinci-resolve-nixos.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=DaVinci Resolve (NixOS wrapper)
    Exec=davinci-resolve-nixos %U
    NoDisplay=true
  '';

  # Dolphin right-click action: transcode unsupported codecs and import into open Resolve.
  xdg.dataFile."kio/servicemenus/davinci-import.desktop" = {
    executable = true;
    text = ''
      [Desktop Entry]
      Type=Service
      MimeType=video/*;audio/*;
      X-KDE-ServiceTypes=KonqPopupMenu/Plugin
      Actions=ImportToDaVinci;
      X-KDE-Priority=TopLevel

      [Desktop Action ImportToDaVinci]
      Name=Открыть в DaVinci (перекодировать и импортировать)
      Icon=davinci-resolve
      Exec=resolve-dolphin-import %F
    '';
  };
}
