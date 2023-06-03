# dump current apps to Brewfile
brew-bundle-dump:
	brew bundle dump --force --file=Brewfile
# Import from Brewfile
brew-bundle:
	brew bundle --file=Brewfile
# Setup laptop
setup: init link brew-bundle
# Init laptop
init:
	scripts/init.sh
# Link dotfiles
link:
	scripts/link.sh
