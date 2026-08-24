#!/usr/bin/env bash
#
# Uninstall script for windots
# Reverts softlinks, restores .old backups, and resets git hooks.
#

set -e

DRY_RUN=false
REMOVE_ENV=false

for arg in "$@"; do
    case $arg in
        --dry-run|-d)
            DRY_RUN=true
            shift
            ;;
        --remove-env)
            REMOVE_ENV=true
            shift
            ;;
    esac
done

echo "=== Uninstalling Windows Dotfiles (windots) ==="
if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN MODE ENABLED - No changes will be made]"
fi

# List of softlinks to check and remove
LINKS=(
    "$HOME/.config/git/config"
    "$HOME/.config/git/.gitignore"
    "$HOME/.config/git/.gitattributes"
    "$HOME/.config/git/.gitmessage"
    "$HOME/.mambarc"
    "$HOME/.condarc"
    "$HOME/.wslconfig"
    "$HOME/.gnupg/gpg.conf"
    "$HOME/.gnupg/common.conf"
    "$HOME/.config/R/.Rprofile"
    "$HOME/.Rprofile"
)

echo ""
echo "Removing managed softlinks and restoring backups..."

for link in "${LINKS[@]}"; do
    if [ -L "$link" ] || [ -f "$link" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "[DryRun] Would remove link: $link"
        else
            rm -f "$link"
            echo "Removed link: $link"
        fi
    fi

    backup="${link}.old"
    if [ -f "$backup" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "[DryRun] Would restore backup: $backup -> $link"
        else
            mv "$backup" "$link"
            echo "Restored backup: $backup -> $link"
        fi
    fi
done

# Reset Git hooks path if within git repository
if [ -d ".git" ]; then
    current_hooks=$(git config --get core.hooksPath 2>/dev/null || true)
    if [ "$current_hooks" = ".githooks" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "[DryRun] Would reset git config core.hooksPath"
        else
            git config --unset core.hooksPath || true
            echo "Reset git config core.hooksPath"
        fi
    fi
fi

# Optional remove conda/mamba/micromamba environment
if [ "$REMOVE_ENV" = true ]; then
    MAMBA_CMD=""
    if command -v mamba >/dev/null 2>&1; then
        MAMBA_CMD="mamba"
    elif command -v micromamba >/dev/null 2>&1; then
        MAMBA_CMD="micromamba"
    fi

    if [ -n "$MAMBA_CMD" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "[DryRun] Would remove $MAMBA_CMD environment 'R'"
        else
            $MAMBA_CMD env remove -n R -y || true
            echo "Removed $MAMBA_CMD environment 'R'"
        fi
    fi
fi

echo ""
echo "Uninstallation completed successfully."
