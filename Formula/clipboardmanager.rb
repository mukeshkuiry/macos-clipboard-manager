class Clipboardmanager < Formula
  desc "Sleek, minimalist, zero-permission native macOS clipboard manager"
  homepage "https://github.com/mukesh-kuirky/macos-clipboard-manager"
  url "https://github.com/mukesh-kuirky/macos-clipboard-manager/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000" # Placeholder for release tarball
  head "https://github.com/mukesh-kuirky/macos-clipboard-manager.git", branch: "main"

  depends_on :xcode => ["12.0", :build]

  def install
    # Compile the Swift code on-the-fly with optimizations
    system "swiftc", "-sdk", MacOS.sdk_path, "-O", "ClipboardManager.swift", "-o", "ClipboardManager"
    
    # Install the compiled binary into Homebrew's binary path
    bin.install "ClipboardManager"
  end

  # Setup the background daemon Launch Agent using Homebrew's modern Service block
  service do
    run [opt_bin/"ClipboardManager"]
    keep_alive true
    process_type :interactive
  end

  test do
    # Simple check to ensure the compiled binary exists
    assert_predicate bin/"ClipboardManager", :exist?
  end
end
