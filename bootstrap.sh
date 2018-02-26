#!/bin/sh

SWIFT=4.0.2

set -e

error() {
  echo "$@"
  exit 1
}

which curl >/dev/null 2>&1 || error "curl is required"
which git >/dev/null 2>&1 || error "git is required"

if which swift >/dev/null 2>&1 && swift --version | grep -q 'swift-4'; then
  echo "*****Using already-installed Swift (at `which swift`)*****"
  already_installed=1
else
  echo '*****Downloading latest Swift*****'
  echo 'Checking Ubuntu version...'

  if which lsb_release >/dev/null 2>&1; then
    ubuntu="`lsb_release -rs` 2>&1"
  else
    echo "WARNING: You are not using Ubuntu. Try installing Swift from your distro's package manager \
before running this script."
    ubuntu="<none>"
    [ -f /etc/arch-release ] && echo "(For Arch, try installing swift-bin.)" ||:
  fi

  if [ "$ubuntu" != "14.04" ] && [ "$ubuntu" != "16.04" ] && [ "$ubuntu" != "16.10" ]; then
    echo "WARNING: No binaries available for Ubuntu $ubuntu; defaulting to 16.10"
    ubuntu=16.10
  fi

  ubuntu_nd="`echo $ubuntu | tr -d '.'`"

  tmp="`mktemp -d`"
  cd "$tmp"

  echo "Downloading Swift $SWIFT to $tmp..."

  echo https://swift.org/builds/swift-$SWIFT-release/ubuntu$ubuntu_nd/swift-$SWIFT-RELEASE-ubuntu$ubuntu.tar.gz
  curl -Lo swift.tgz https://swift.org/builds/swift-$SWIFT-release/ubuntu$ubuntu_nd/swift-$SWIFT-RELEASE/swift-$SWIFT-RELEASE-ubuntu$ubuntu.tar.gz
  echo 'Extracting Swift...'
  tar xf swift.tgz --strip 1
  export "PATH=$PATH:$tmp/usr/bin"
fi

echo '*****Downloading and Building swiftix*****'

echo 'Downloading swiftix...'
mkdir -p ~/.swiftix
cd ~/.swiftix
rm -rf source
git clone https://github.com/kirbyfan64/swiftix.git source

echo 'Building and installing swiftix to ~/.swiftix...'

cd source
chmod +x swiftix-update
./swiftix-update

ln -sf ~/.swiftix/source/swiftix-update ~/.swiftix/bin/swiftix-update

echo 'Adding ~/.swiftix/bin and ~/.swiftix/active/bin to your PATH...'

for file in ~/.bashrc ~/.zshrc; do
  [ -f "$file" ] || continue
  echo '# Added by Swiftix' >> "$file"
  echo 'export PATH="$PATH:$HOME/.swiftix/bin:$HOME/.swiftix/active/bin"' >> "$file"
done

if [ -z "$already_installed" ]; then
  echo 'Cleaning up...'
  rm -rf "$tmp"
fi

echo 'Done! Try restarting your terminal to see your new PATH take effect.'
