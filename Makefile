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
# Install golang
install-go:
	scripts/install-go.sh
# Install python
install-python:
	scripts/install-python.sh
# Install ruby
install-ruby:
	scripts/install-ruby.sh
# Install nodejs
install-nodejs:
	scripts/install-nodejs.sh
