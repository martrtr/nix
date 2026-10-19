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
        video: DNxHR SQ for normal 8-bit sources, HQX for 10-bit sources
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

              pix_fmt="$(ffprobe -v error -select_streams v:0 \
                -show_entries stream=pix_fmt -of default=nw=1:nk=1 "$src" | head -n 1)"

              case "$pix_fmt" in
                *10*|*12*)
                  profile="dnxhr_hqx"
                  out_pix_fmt="yuv422p10le"
                  ;;
                *)
                  profile="dnxhr_sq"
                  out_pix_fmt="yuv422p"
                  ;;
              esac

              echo "==> $src"
              echo "    source pixel format: $pix_fmt"
              echo "    DNxHR profile: $profile"
              echo "    -> $out"
              ffmpeg -hide_banner -y -i "$src" \
                -map 0:v:0 -map '0:a?' -map_metadata 0 \
                -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" \
                -r "$fps" -fps_mode cfr \
                -c:v dnxhd -profile:v "$profile" -pix_fmt "$out_pix_fmt" \
                -c:a pcm_s24le -ar 48000 \
                "$out"
            done
    '';
  };

  resolveLauncher = pkgs.writeShellApplication {
    name = "davinci-resolve-nixos";
    runtimeInputs = [
      davinciResolve
      pkgs.coreutils
      pkgs.xdotool
      pkgs.xprop
    ];
    text = ''
      export QT_QPA_PLATFORM=xcb

      # xwayland-satellite >= 0.8.2 can misclassify Resolve's Project Manager
      # as a popup of Resolve's short-lived 1x1 placeholder window. Once that
      # parent is destroyed the dialog remains mapped in X11 but has no Wayland
      # toplevel, so Niri cannot show it. Reclassify only that Resolve window.
      (
        for _ in $(seq 1 240); do
          sleep 0.25
          for win in $(xdotool search --name '^Project Manager$' 2>/dev/null || true); do
            if xprop -id "$win" WM_CLASS 2>/dev/null | grep -q '"resolve"' \
              && xprop -id "$win" WM_TRANSIENT_FOR 2>/dev/null | grep -q 'window id'; then
              xprop -id "$win" -remove WM_TRANSIENT_FOR >/dev/null 2>&1 || true
              xdotool windowunmap "$win" >/dev/null 2>&1 || true
              sleep 0.1
              xdotool windowmap "$win" >/dev/null 2>&1 || true
              exit 0
            fi
          done
        done
      ) &

      exec davinci-resolve "$@"
    '';
  };

  resolveDolphinImport = pkgs.writeShellApplication {
    name = "resolve-dolphin-import";
    runtimeInputs = with pkgs; [
      coreutils
      ffmpeg
      libnotify
      xdotool
    ];
    text = ''
      set -euo pipefail

      if [ "$#" -eq 0 ]; then
        exec davinci-resolve-nixos
      fi

      cache="$HOME/.cache/DaVinciResolve/resolve-ingest"
      mkdir -p "$cache"

      if ! pgrep -f '/bin/resolve' >/dev/null 2>&1; then
        notify-send "DaVinci Resolve" "Запускаю Resolve перед импортом…"
        davinci-resolve-nixos >/dev/null 2>&1 &
        for _ in $(seq 1 60); do
          if xdotool search --onlyvisible --class resolve >/dev/null 2>&1; then
            break
          fi
          sleep 1
        done
      fi

      window="$(xdotool search --onlyvisible --name '^DaVinci Resolve' 2>/dev/null | tail -n 1 || true)"
      if [ -z "$window" ]; then
        window="$(xdotool search --onlyvisible --class resolve 2>/dev/null | tail -n 1 || true)"
      fi
      if [ -z "$window" ]; then
        notify-send "DaVinci Resolve" "Основное окно Resolve не найдено."
        exit 1
      fi

      import_file() {
        local file="$1"
        local dialog=""
        local i

        xdotool windowactivate --sync "$window" >/dev/null 2>&1 || true
        sleep 0.2
        xdotool key --window "$window" ctrl+i

        for i in $(seq 1 50); do
          dialog="$(xdotool search --onlyvisible --name '^Import Media$' 2>/dev/null | tail -n 1 || true)"
          [ -n "$dialog" ] && break
          sleep 0.1
        done

        if [ -z "$dialog" ]; then
          notify-send "DaVinci Resolve" "Не открылось окно Import Media для: $(basename "$file")"
          return 1
        fi

        xdotool windowactivate --sync "$dialog" >/dev/null 2>&1 || true
        xdotool type --window "$dialog" --delay 1 --clearmodifiers "$file"
        sleep 0.15
        xdotool key --window "$dialog" Return

        for i in $(seq 1 100); do
          if ! xdotool search --onlyvisible --name '^Import Media$' >/dev/null 2>&1; then
            return 0
          fi
          sleep 0.1
        done

        notify-send "DaVinci Resolve" "Resolve не подтвердил импорт: $(basename "$file")"
        return 1
      }

      imported=0

      for src in "$@"; do
        [ -f "$src" ] || continue
        base="$(basename "$src")"
        stem="''${base%.*}"

        has_video="$(ffprobe -v error -select_streams v:0 -show_entries stream=index -of csv=p=0 "$src" | head -n 1 || true)"
        has_audio="$(ffprobe -v error -select_streams a:0 -show_entries stream=index -of csv=p=0 "$src" | head -n 1 || true)"

        if [ -n "$has_video" ]; then
          out="$cache/''${stem}_dnxhr.mov"
          if [ ! -f "$out" ] || [ "$src" -nt "$out" ]; then
            notify-send "DaVinci Resolve" "Перекодирование видео: $base"
            RESOLVE_INGEST_DIR="$cache" resolve-ingest "$src"
          else
            notify-send "DaVinci Resolve" "Использую готовый DNxHR: $base"
          fi
          [ -f "$out" ] || { notify-send "DaVinci Resolve" "DNxHR-файл не создан: $base"; exit 1; }
          import_file "$out"
          imported=$((imported + 1))
          continue
        fi

        if [ -n "$has_audio" ]; then
          codec="$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$src" | head -n 1 || true)"
          ext="''${base##*.}"
          ext="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"

          case "$codec:$ext" in
            pcm_s16le:wav|pcm_s24le:wav|pcm_s32le:wav|pcm_f32le:wav|pcm_s16be:aif|pcm_s16be:aiff|pcm_s24be:aif|pcm_s24be:aiff)
              out="$src"
              ;;
            *)
              out="$cache/''${stem}_pcm24.wav"
              notify-send "DaVinci Resolve" "Подготовка аудио: $base"
              ffmpeg -hide_banner -loglevel error -y -i "$src" -vn -c:a pcm_s24le -ar 48000 "$out"
              ;;
          esac
          import_file "$out"
          imported=$((imported + 1))
          continue
        fi

        import_file "$src"
        imported=$((imported + 1))
      done

      notify-send "DaVinci Resolve" "Импорт подтверждён для $imported файл(ов)."
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

  xdg.dataFile."DaVinciResolve/Fusion/Scripts/Utility/Import Any Video.py" = {
    source = ./resolve-import-any-video.py;
    executable = true;
  };

  xdg.dataFile."DaVinciResolve/Fusion/Scripts/Utility/Import Any Video.lua".source =
    ./resolve-import-any-video.lua;

  xdg.dataFile."DaVinciResolve/Fusion/Scripts/Utility/Send to REAPER.lua".source =
    ./resolve-send-to-reaper.lua;

  # Override the upstream desktop file so normal app-menu launch always uses the NixOS/XWayland wrapper.
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

  # Separate Open With handler for media files. This keeps app-menu launch independent from import.
  xdg.dataFile."applications/davinci-resolve-import.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Version=1.5
    Name=DaVinci Resolve — Import into current project
    Comment=Transcode if needed and import media into the currently open Resolve project
    Exec=resolve-dolphin-import %F
    Icon=davinci-resolve
    Terminal=false
    NoDisplay=true
    MimeType=video/*;audio/*;image/*;
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
