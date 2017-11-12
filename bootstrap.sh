#!/bin/sh

SWIFT=4.0.2

set -e

error() {
  echo "$@"
  exit 1
}

which curl 2>&1 || error "curl is required"
which git 2>&1 || error "git is required"

echo 'Checking Ubuntu version...'
ubuntu="`lsb_release -rs`"

if [ "$ubuntu" != "14.04" ] && [ "$ubuntu" != "16.04" ] && [ "$ubuntu" != "16.10" ]; then
  echo "WARNING: No binaries available for Ubuntu $ubuntu version; defaulting to 16.10"
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

echo 'Cleaning up...'
rm -rf "$tmp"

echo 'Adding ~/.swiftix/bin and ~/.swiftix/active/bin to your PATH...'
echo '# Added by Swiftix' >> ~/.bashrc
echo 'export PATH="$PATH:$HOME/.swiftix/bin:$HOME/.swiftix/active/bin"' >> ~/.bashrc
