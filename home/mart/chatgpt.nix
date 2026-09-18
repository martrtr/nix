{ pkgs }:
let
  patchDeps = with pkgs; [
    stdenv.cc.cc.lib
    glib
    gtk3
    gdk-pixbuf
    nss
    nspr
    atk
    at-spi2-atk
    at-spi2-core
    cups
    dbus
    expat
    libdrm
    mesa
    alsa-lib
    systemd
    libusb1
    libxkbcommon
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxrender
    libxscrnsaver
    libxtst
    pango
    cairo
    libgbm
    libglvnd
    vulkan-loader
  ];
  # Do not place Qt 5 and Qt 6 together in buildInputs: each installs a setup
  # hook which correctly rejects a mixed build environment.  The upstream
  # Electron bundle intentionally ships shims for both ABIs, so expose them
  # only at runtime through the launcher instead.
  runtimeDeps = patchDeps ++ (with pkgs; [ qt5.qtbase qt6.qtbase ]);
in
pkgs.stdenv.mkDerivation {
  pname = "chatgpt-desktop";
  version = "26.903.71938";

  # Official Linux preview package.  Pin the download: `latest` changes over
  # time, so an update must intentionally replace this hash.
  src = pkgs.fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb";
    hash = "sha256-E/Rt9zsG324T6edQsvPImphYY3QeqCXS01b1JVn1Wr0=";
  };

  nativeBuildInputs = [
    pkgs.dpkg
    pkgs.autoPatchelfHook
    pkgs.wrapGAppsHook3
    pkgs.makeWrapper
  ];

  buildInputs = patchDeps;

  # The archive also carries optional Node add-ons built for musl Linux.
  # ChatGPT selects the glibc variants on NixOS, so no musl loader is needed.
  autoPatchelfIgnoreMissingDeps = [
    "libc.musl-x86_64.so.1"
    "libQt5Core.so.5"
    "libQt5Gui.so.5"
    "libQt5Widgets.so.5"
    "libQt6Core.so.6"
    "libQt6Gui.so.6"
    "libQt6Widgets.so.6"
  ];

  unpackPhase = ''
    dpkg-deb -x $src .
  '';

  installPhase = ''
    mkdir -p $out/bin $out/share
    cp -r usr/lib $out/lib
    cp -r usr/share/* $out/share/

    if [ -d "$out/share/applications" ]; then
      for file in $out/share/applications/*.desktop; do
        substituteInPlace "$file" \
          --replace "/usr/bin/chatgpt" "$out/bin/chatgpt" || true
      done
    fi

    makeWrapper $out/lib/chatgpt/ChatGPT $out/bin/chatgpt \
      --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath runtimeDeps}"
  '';
}
