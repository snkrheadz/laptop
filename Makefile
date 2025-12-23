# Install dotfiles (full setup)
install:
	./install.sh

# Rollback to previous configuration
rollback:
	./rollback.sh

# Dump current Homebrew packages to Brewfile
brew-dump:
	brew bundle dump --force --file=Brewfile

# Install Homebrew packages from Brewfile
brew-install:
	brew bundle --file=Brewfile

# Run auto-sync manually
sync:
	./scripts/auto-sync.sh

# Run security checks
security-check:
	gitleaks detect --source=. --no-git
	pre-commit run --all-files

# Setup pre-commit hooks
setup-hooks:
	pre-commit install

# Show help
help:
	@echo "Available commands:"
	@echo "  make install        - Full installation (backup, symlinks, brew, security)"
	@echo "  make rollback       - Rollback to previous configuration"
	@echo "  make brew-dump      - Dump current Homebrew packages to Brewfile"
	@echo "  make brew-install   - Install packages from Brewfile"
	@echo "  make sync           - Run auto-sync manually"
	@echo "  make security-check - Run gitleaks and pre-commit checks"
	@echo "  make setup-hooks    - Install pre-commit hooks"

.PHONY: install rollback brew-dump brew-install sync security-check setup-hooks help
