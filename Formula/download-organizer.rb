class DownloadOrganizer < Formula
  desc "Automatically organize your Downloads folder by file type"
  homepage "https://github.com/fajaradisetyawan/download-organizer"
  url "https://github.com/fajaradisetyawan/download-organizer/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "6d593b0afecc43080714925fad0db8fdda94c3c88b56125cc1abb3f17e6faeb0"
  license "MIT"
  version "1.0.0"

  depends_on xcode: ["14.0", :build]
  depends_on :macos => :sonoma

  def install
    # Build from source
    system "swift", "build", "-c", "release", "--disable-sandbox"

    # Install binary
    bin.install ".build/release/download-organizer"

    # Install scripts
    libexec.install "install.sh", "uninstall.sh", "restart.sh"
    libexec.install "scripts"

    # Create wrapper script
    (bin/"download-organizer-install").write <<~EOS
      #!/bin/bash
      #{libexec}/install.sh
    EOS

    (bin/"download-organizer-uninstall").write <<~EOS
      #!/bin/bash
      #{libexec}/uninstall.sh
    EOS

    (bin/"download-organizer-restart").write <<~EOS
      #!/bin/bash
      #{libexec}/restart.sh
    EOS

    chmod 0755, bin/"download-organizer-install"
    chmod 0755, bin/"download-organizer-uninstall"
    chmod 0755, bin/"download-organizer-restart"
  end

  def post_install
    # Create config directory
    config_dir = "#{ENV["HOME"]}/.download-organizer"
    system "mkdir", "-p", config_dir
    system "mkdir", "-p", "#{config_dir}/logs"

    # Create default config if not exists
    config_file = "#{config_dir}/config.json"
    unless File.exist?(config_file)
      File.write(config_file, <<~JSON)
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
    end

    # Create default rules if not exists
    rules_file = "#{config_dir}/rules.json"
    unless File.exist?(rules_file)
      File.write(rules_file, <<~JSON)
        {
          "Installers": ["dmg", "pkg", "exe", "msi"],
          "Torrents": ["torrent", "magnet"],
          "Android": ["apk", "aab"],
          "iOS": ["ipa"]
        }
      JSON
    end

    # Create category folders
    downloads = "#{ENV["HOME"]}/Downloads"
    %w[Images Videos Audio Documents PDF Archives Applications Books Fonts Code Design Others].each do |folder|
      system "mkdir", "-p", "#{downloads}/#{folder}"
    end

    # Install LaunchAgent
    plist_file = "#{ENV["HOME"]}/Library/LaunchAgents/com.downloadorganizer.agent.plist"
    File.write(plist_file, <<~PLIST)
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
          <key>Label</key>
          <string>com.downloadorganizer.agent</string>
          <key>ProgramArguments</key>
          <array>
              <string>#{bin}/download-organizer</string>
          </array>
          <key>RunAtLoad</key>
          <true/>
          <key>KeepAlive</key>
          <dict>
              <key>SuccessfulExit</key>
              <false/>
          </dict>
          <key>StandardOutPath</key>
          <string>#{config_dir}/logs/stdout.log</string>
          <key>StandardErrorPath</key>
          <string>#{config_dir}/logs/stderr.log</string>
          <key>WorkingDirectory</key>
          <string>#{config_dir}</string>
          <key>ThrottleInterval</key>
          <integer>10</integer>
      </dict>
      </plist>
    PLIST

    # Load LaunchAgent
    system "launchctl", "bootout", "gui/#{Process.uid}/com.downloadorganizer.agent"
    system "launchctl", "bootstrap", "gui/#{Process.uid}", plist_file

    ohai "Download Organizer installed successfully!"
    ohai "Service is now running in the background."
    ohai ""
    ohai "Configuration: ~/.download-organizer/config.json"
    ohai "Custom rules: ~/.download-organizer/rules.json"
    ohai "Logs: ~/.download-organizer/logs/"
    ohai ""
    ohai "Commands:"
    ohai "  download-organizer --undo-last    # Undo last move"
    ohai "  download-organizer --stats         # View statistics"
    ohai "  download-organizer-restart         # Restart service"
    ohai "  download-organizer-uninstall       # Uninstall service"
  end

  def caveats
    <<~EOS
      Download Organizer is now running as a background service.
      Your Downloads folder will be organized automatically.

      To check service status:
        launchctl list | grep downloadorganizer

      To view logs:
        tail -f ~/.download-organizer/logs/download-organizer.log

      To uninstall the service:
        download-organizer-uninstall
        brew uninstall download-organizer
    EOS
  end

  test do
    system "#{bin}/download-organizer", "--help"
  end
end