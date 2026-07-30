class DownloadOrganizer < Formula
  desc "Automatically organize your Downloads folder by file type"
  homepage "https://github.com/FajarAdiSetyawan/macOS-Download-Organizer"
  url "https://github.com/FajarAdiSetyawan/macOS-Download-Organizer/archive/refs/tags/v1.1.0.tar.gz"
  sha256 "ca3fc4e1dbf3c3d150d729c09ea71f34c3cd65790e35b48a37473107d4757d4c"
  license "MIT"
  version "1.1.0"

  depends_on xcode: ["14.0", :build]
  depends_on macos: :sonoma

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"

    bin.install ".build/release/download-organizer"

    (bin/"download-organizer-install").write <<~EOS
      #!/bin/bash
      set -euo pipefail

      LABEL="com.downloadorganizer.agent"
      CONFIG_DIR="$HOME/.download-organizer"
      PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
      BINARY="#{bin}/download-organizer"

      echo "[INFO] Installing Download Organizer..."

      mkdir -p "$CONFIG_DIR/logs"
      mkdir -p "$HOME/Library/LaunchAgents"
      mkdir -p "$HOME/Downloads"

      if [ ! -f "$CONFIG_DIR/config.json" ]; then
        cat > "$CONFIG_DIR/config.json" <<'JSON'
{
  "enabled": true,
  "watchFolder": "~/Downloads",
  "delay": 3,
  "notifications": false,
  "autoCreateFolders": true,
  "duplicateStrategy": "rename",
  "history": true
}
JSON
      fi

      if [ ! -f "$CONFIG_DIR/rules.json" ]; then
        cat > "$CONFIG_DIR/rules.json" <<'JSON'
{
  "Installers": ["dmg", "pkg", "exe", "msi", "appimage", "deb", "rpm"],
  "Torrents": ["torrent", "magnet"],
  "Android": ["apk", "aab", "xapk"],
  "iOS": ["ipa", "mobileprovision"],
  "3D Models": ["obj", "fbx", "stl", "dae", "3ds", "gltf", "glb", "usdz"],
  "Subtitles": ["srt", "sub", "ass", "ssa", "vtt"],
  "Databases": ["db", "sqlite", "sqlite3", "mdb", "accdb", "sql", "dbf"],
  "Virtual Machines": ["ova", "ovf", "vdi", "vmdk", "vhd", "vhdx", "qcow2"]
}
JSON
      fi

      for folder in Images Videos Audio Documents PDF Archives Applications Books Fonts Code Design Others; do
        mkdir -p "$HOME/Downloads/$folder"
      done

      cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>

    <key>ProgramArguments</key>
    <array>
        <string>$BINARY</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
        <key>Crashed</key>
        <true/>
    </dict>

    <key>StandardOutPath</key>
    <string>$CONFIG_DIR/logs/stdout.log</string>

    <key>StandardErrorPath</key>
    <string>$CONFIG_DIR/logs/stderr.log</string>

    <key>WorkingDirectory</key>
    <string>$CONFIG_DIR</string>

    <key>ProcessType</key>
    <string>Background</string>

    <key>ThrottleInterval</key>
    <integer>10</integer>

    <key>ExitTimeOut</key>
    <integer>10</integer>

    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
</dict>
</plist>
PLIST

      launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
      pkill -9 download-organizer 2>/dev/null || true
      sleep 1

      launchctl bootstrap "gui/$(id -u)" "$PLIST"
      launchctl kickstart -k "gui/$(id -u)/$LABEL"

      echo "[INFO] Download Organizer installed and started."
      echo "[INFO] Config: $CONFIG_DIR/config.json"
      echo "[INFO] Rules:  $CONFIG_DIR/rules.json"
      echo "[INFO] Logs:   $CONFIG_DIR/logs/"
    EOS

    (bin/"download-organizer-uninstall").write <<~EOS
      #!/bin/bash
      set -euo pipefail

      LABEL="com.downloadorganizer.agent"
      PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

      launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
      pkill -9 download-organizer 2>/dev/null || true
      rm -f "$PLIST"

      echo "[INFO] Download Organizer LaunchAgent removed."
      echo "[INFO] Config/history preserved at ~/.download-organizer"
    EOS

    (bin/"download-organizer-restart").write <<~EOS
      #!/bin/bash
      set -euo pipefail

      LABEL="com.downloadorganizer.agent"
      PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

      if [ ! -f "$PLIST" ]; then
        echo "[ERROR] LaunchAgent plist not found. Run: download-organizer-install"
        exit 1
      fi

      launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
      pkill -9 download-organizer 2>/dev/null || true
      sleep 1

      launchctl bootstrap "gui/$(id -u)" "$PLIST"
      launchctl kickstart -k "gui/$(id -u)/$LABEL"

      echo "[INFO] Download Organizer restarted."
    EOS

    chmod 0755, bin/"download-organizer-install"
    chmod 0755, bin/"download-organizer-uninstall"
    chmod 0755, bin/"download-organizer-restart"
  end

  def post_install
    system "#{bin}/download-organizer-install"
  end

  def caveats
    <<~EOS
      Download Organizer is installed and runs as a LaunchAgent.

      Useful commands:
        download-organizer-install
        download-organizer-restart
        download-organizer-uninstall
        download-organizer --stats
        download-organizer --undo-last

      Config:
        ~/.download-organizer/config.json

      Rules:
        ~/.download-organizer/rules.json

      Logs:
        tail -f ~/.download-organizer/logs/download-organizer.log

      Service status:
        launchctl print gui/$(id -u)/com.downloadorganizer.agent
    EOS
  end

  test do
    system "#{bin}/download-organizer", "--stats"
  end
end