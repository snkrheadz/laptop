# dump current apps to Brewfile
brew-bundle-dump:
	brew bundle dump --force --file=Brewfile
# Import from Brewfile
brew-bundle:
	brew bundle --file=Brewfile