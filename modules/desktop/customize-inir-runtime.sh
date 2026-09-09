#!/usr/bin/env bash
set -euo pipefail

python="$1"

substituteInPlace() {
  local file="$1"
  shift
  local replacement=0

  while [ "$#" -gt 0 ]; do
    [ "$1" = "--replace-fail" ]
    local old="$2"
    local new="$3"
    shift 3
    replacement=$((replacement + 1))

    "$python" - "$file" "$old" "$new" "$replacement" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
old = sys.argv[2]
new = sys.argv[3]
replacement = sys.argv[4]
text = path.read_text()

if old not in text:
    # iNiR changes its visual/theme implementation frequently.  A stale
    # cosmetic tweak must not make the whole NixOS generation unbuildable;
    # retain upstream's current implementation and make the skipped tweak
    # visible in the build log instead.
    print(f"warning: replacement {replacement} was not found in {path}; keeping upstream implementation", file=sys.stderr)
    raise SystemExit(0)

path.write_text(text.replace(old, new))
PY
  done
}

substituteInPlace shell.qml \
  --replace-fail '            } else if (Config.options?.settingsUi?.overlayMode ?? false) {
                // ii overlay mode — toggle inline panel
                GlobalStates.settingsOverlayOpen = !GlobalStates.settingsOverlayOpen
            } else {
                // ii window mode (default) — launch separate process
                Quickshell.execDetached([Quickshell.shellPath("scripts/inir"),
                    "settings-window"])
            }' '            } else {
                GlobalStates.settingsOverlayOpen = !GlobalStates.settingsOverlayOpen
            }' \
  --replace-fail '    // Settings overlay panel (loaded only when overlay mode is enabled).
    // overlayStyle picks the chrome; two sibling loaders instead of a
    // conditional `component:` so only the selected one is ever constructed.
    // Any unrecognised style falls back to the nav rail.
    LazyLoader {
        active: Config.ready && (Config.options?.settingsUi?.overlayMode ?? false)
            && (Config.options?.settingsUi?.overlayStyle ?? "rail") !== "focus"
        component: SettingsOverlay {}
    }

    LazyLoader {
        active: Config.ready && (Config.options?.settingsUi?.overlayMode ?? false)
            && (Config.options?.settingsUi?.overlayStyle ?? "rail") === "focus"
        component: SettingsFocus {}
    }' '    // Keep the customized inline settings panel available for every ii
    // layout, irrespective of upstream overlay-mode/style preferences.
    LazyLoader {
        active: Config.ready && (Config.options?.panelFamily ?? "ii") !== "waffle"
        component: SettingsOverlay {}
    }

    LazyLoader {
        active: false
        component: SettingsFocus {}
    }'

substituteInPlace modules/bar/BarContent.qml \
  --replace-fail '                action: () => {
                    Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "settings"])
                },' '                action: () => {
                    GlobalStates.settingsOverlayOpen = !GlobalStates.settingsOverlayOpen
                },'

substituteInPlace modules/sidebarLeft/widgets/GlanceHeader.qml \
  --replace-fail '                        const isWaffle = (Config.options?.panelFamily === "waffle" && Config.options?.waffles?.settings?.useMaterialStyle !== true);
                        const settingsPath = isWaffle ? Quickshell.shellPath("waffleSettings.qml") : Quickshell.shellPath("settings.qml");
                        const pageIndex = isWaffle ? 6 : 5; // Modules (Waffle) vs Interface (ii)
                        const section = isWaffle ? Translation.tr("Widgets Panel") : Translation.tr("Widgets");

                        Quickshell.execDetached(["/usr/bin/env", "QS_SETTINGS_PAGE=" + pageIndex, "QS_SETTINGS_SECTION=" + section, Quickshell.shellPath("scripts/inir"), isWaffle ? "waffle-settings-window" : "settings-window"]);' '                        const isWaffle = (Config.options?.panelFamily === "waffle" && Config.options?.waffles?.settings?.useMaterialStyle !== true);
                        if (isWaffle) {
                            const pageIndex = 6;
                            const section = Translation.tr("Widgets Panel");
                            Quickshell.execDetached(["/usr/bin/env", "QS_SETTINGS_PAGE=" + pageIndex, "QS_SETTINGS_SECTION=" + section, Quickshell.shellPath("scripts/inir"), "waffle-settings-window"]);
                        } else {
                            GlobalStates.settingsOverlayOpen = true;
                        }'

substituteInPlace modules/common/functions/ShellExec.qml \
  --replace-fail '                    exec "$systemd_run" --user --quiet --collect --same-dir --scope \
                        --description="$desc" -- "$@"' '                    exec "$systemd_run" --user --quiet --collect --same-dir \
                        --description="$desc" -- "$@"' \
  --replace-fail '                exec "$systemd_run" --user --quiet --collect --same-dir --scope -- "$@"' '                exec "$systemd_run" --user --quiet --collect --same-dir -- "$@"'

substituteInPlace scripts/colors/apply-gtk-theme.sh \
  --replace-fail 'enable_apps_shell="true"
enable_qt_apps="true"
if [[ -f "$SHELL_CONFIG_FILE" ]] && command -v jq &>/dev/null; then
    enable_apps_shell=$(jq -r '"'"'.appearance.wallpaperTheming.enableAppsAndShell // true'"'"' "$SHELL_CONFIG_FILE")
    enable_qt_apps=$(jq -r '"'"'.appearance.wallpaperTheming.enableQtApps // true'"'"' "$SHELL_CONFIG_FILE")
fi' 'enable_apps_shell="true"
enable_qt_apps="true"
color_mode=""
if [[ -f "$SHELL_CONFIG_FILE" ]] && command -v jq &>/dev/null; then
    enable_apps_shell=$(jq -r '"'"'.appearance.wallpaperTheming.enableAppsAndShell // true'"'"' "$SHELL_CONFIG_FILE")
    enable_qt_apps=$(jq -r '"'"'.appearance.wallpaperTheming.enableQtApps // true'"'"' "$SHELL_CONFIG_FILE")
    color_mode=$(jq -r '"'"'.appearance.palette.mode // empty'"'"' "$SHELL_CONFIG_FILE")
fi

case "$color_mode" in
    dark) gsettings set org.gnome.desktop.interface color-scheme prefer-dark || true ;;
    light) gsettings set org.gnome.desktop.interface color-scheme prefer-light || true ;;
esac' \
  --replace-fail 'BackgroundAlternate=${ROW_ACTIVE_BG}
BackgroundNormal=${ROW_ACTIVE_HOVER_BG}
DecorationFocus=${PRIMARY}
DecorationHover=${ROW_ACTIVE_HOVER_BG}
ForegroundActive=${ROW_SELECTED_FG}
ForegroundInactive=${FG_INACTIVE}
ForegroundLink=${ROW_SELECTED_FG}
ForegroundNegative=${ROW_SELECTED_FG}
ForegroundNeutral=${ROW_SELECTED_FG}
ForegroundNormal=${ROW_SELECTED_FG}
ForegroundPositive=${ROW_SELECTED_FG}
ForegroundVisited=${ROW_SELECTED_FG}' 'BackgroundAlternate=${ROW_ACTIVE_BG}
BackgroundNormal=${PRIMARY}
DecorationFocus=${PRIMARY}
DecorationHover=${PRIMARY}
ForegroundActive=${ON_PRIMARY}
ForegroundInactive=${ON_PRIMARY}
ForegroundLink=${ON_PRIMARY}
ForegroundNegative=${ON_PRIMARY}
ForegroundNeutral=${ON_PRIMARY}
ForegroundNormal=${ON_PRIMARY}
ForegroundPositive=${ON_PRIMARY}
ForegroundVisited=${ON_PRIMARY}' \
  --replace-fail '    local selection_bg_rgb=$(blend_rgb_percent "$SURFACE_CONTAINER_HIGH" "$PRIMARY" 18)
    local selection_bg_alt_rgb=$(blend_rgb_percent "$SURFACE_CONTAINER" "$PRIMARY" 14)
    local selection_hover_rgb=$(blend_rgb_percent "$SURFACE_CONTAINER_HIGH" "$PRIMARY" 28)' '    local selection_bg_rgb=$(hex_to_rgb "$PRIMARY")
    local selection_bg_alt_rgb=$(blend_rgb_percent "$SURFACE_CONTAINER" "$PRIMARY" 14)
    local selection_hover_rgb=$(hex_to_rgb "$PRIMARY")' \
  --replace-fail 'ForegroundActive=${fg_rgb}
ForegroundInactive=${fg_inactive_rgb}
ForegroundLink=${fg_rgb}
ForegroundNegative=${fg_rgb}
ForegroundNeutral=${fg_rgb}
ForegroundNormal=${fg_rgb}
ForegroundPositive=${fg_rgb}
ForegroundVisited=${fg_rgb}

[Colors:Header]' 'ForegroundActive=${on_primary_rgb}
ForegroundInactive=${on_primary_rgb}
ForegroundLink=${on_primary_rgb}
ForegroundNegative=${on_primary_rgb}
ForegroundNeutral=${on_primary_rgb}
ForegroundNormal=${on_primary_rgb}
ForegroundPositive=${on_primary_rgb}
ForegroundVisited=${on_primary_rgb}

[Colors:Header]' \
  --replace-fail '    generate_kdeglobals > "$KDEGLOBALS"' '    kdeglobals_dir=$(dirname "$KDEGLOBALS")
    mkdir -p "$kdeglobals_dir"
    kdeglobals_tmp=$(mktemp "$kdeglobals_dir/.kdeglobals.XXXXXX")
    generate_kdeglobals > "$kdeglobals_tmp"
    mv "$kdeglobals_tmp" "$KDEGLOBALS"' \
  --replace-fail '    # Generate Darkly color scheme for Qt style
    mkdir -p "$(dirname "$DARKLY_COLORS")"
    generate_darkly_colors > "$DARKLY_COLORS"' '    # Generate Darkly color scheme for Qt style

    darkly_dir=$(dirname "$DARKLY_COLORS")
    mkdir -p "$darkly_dir"
    darkly_tmp=$(mktemp "$darkly_dir/.Darkly.colors.XXXXXX")
    generate_darkly_colors > "$darkly_tmp"
    mv "$darkly_tmp" "$DARKLY_COLORS"' \
  --replace-fail '[General]
ColorScheme=Darkly
Name=Darkly
shadeSortColumn=true' '[General]
ColorScheme=Darkly
Name=Darkly
TerminalApplication=kitty -1
shadeSortColumn=true' \
  --replace-fail 'nautilus -q 2>/dev/null &' 'nautilus -q 2>/dev/null &

# xdg-desktop-portal-kde caches KConfig on startup. Restarting only the portal
# host does not recreate this backend, so end its stale instance after a new
# palette is in place.
pkill -u "$(id -u)" -x xdg-desktop-portal-kde 2>/dev/null || true
systemctl --user restart xdg-desktop-portal.service 2>/dev/null || true'

sed -i \
  '/gsettings get/s/")$/" || true)/' \
  scripts/colors/apply-gtk-theme.sh

substituteInPlace services/FontSyncService.qml \
  --replace-fail '            "/usr/bin/kwriteconfig6",' '            "true",'

substituteInPlace services/IconThemeService.qml \
  --replace-fail '        id: kdeGlobalsUpdateProc
        property string themeName: ""
        property bool skipRestart: false
        command: [
            "/usr/bin/python3",
            "-c",
            `
import configparser' '        id: kdeGlobalsUpdateProc
        property string themeName: ""
        property bool skipRestart: false
        command: [
            "true",
            "-c",
            `
import configparser' \
  --replace-fail '            "/usr/bin/kwriteconfig6",' '            "true",'
