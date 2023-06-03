#!/bin/bash
if [ "$(uname)" != "Darwin" ] ; then
	echo "init.sh is designed for macOS"
	exit 1
fi

# Exit if xcode-select is not installed
if ! which -s xcode-select; then
  echo 'Install XCode first'
  exit 1
fi

# Install xcode command line tools
xcode-select --install > /dev/null

# Install brew if not installed
if ! which -s brew; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" > /dev/null
fi
