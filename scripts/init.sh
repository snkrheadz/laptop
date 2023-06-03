#!/bin/bash
if [ "$(uname)" != "Darwin" ] ; then
	echo "init.sh is designed for macOS"
	exit 1
fi

# Install xcode command line tools
xcode-select --install > /dev/null

# Install brew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" > /dev/null