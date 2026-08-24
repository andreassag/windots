# Windows Dotfiles (`windots`)

> [!IMPORTANT]
> Dotfiles repository intended for personal Windows 10/11 workstation setup. Feel free to use and adapt these configurations for your own workflow.

This repository manages automated setup, configuration files, and software installation for Windows 10/11, PowerShell, Visual Studio Code, Git, Windows Terminal, WSL, GnuPG, PowerToys, and Conda.

---

## Setup & Usage

### 1. Clone the repository
```powershell
git clone https://github.com/andreassag/windots.git "$HOME\repo\windots"
Set-Location "$HOME\repo\windots"
```

### 2. Preview changes (Dry Run)
You can safely test the setup without modifying your system or requiring elevation:
```powershell
.\setup.ps1 -DryRun
```

### 3. Run full setup (Run as Administrator)
Launch an elevated PowerShell 5.1 or PowerShell 7 session and run:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope Process -Force
.\setup.ps1
```

### 4. Run specific components
You can selectively configure individual tools or modules:
```powershell
.\setup.ps1 -Components git,powershell,terminal
```

---

## Directory Structure

| Directory / File | Description |
| :--- | :--- |
| [`.githooks/`](.githooks/) | Git pre-commit hooks for syntax and linting checks |
| [`.github/workflows/`](.github/workflows/) | GitHub Actions CI/CD workflows |
| [`.vscode/`](.vscode/) | Workspace settings and recommended extensions |
| [`conda/`](conda/) | Miniconda configuration (`.condarc`) |
| [`git/`](git/) | Git configuration (`config`, `gitconfig`, `.gitignore`, `.gitmessage`, `.gitattributes`) |
| [`gpg/`](gpg/) | GnuPG configuration (`gpg.conf`, `common.conf`) |
| [`powershell/`](powershell/) | PowerShell profile (`profile.ps1`) and module setup |
| [`powertoys/`](powertoys/) | Microsoft PowerToys setup |
| [`scripts/`](scripts/) | Shared helper functions (`common.ps1`) |
| [`terminal/`](terminal/) | Windows Terminal profiles and keybindings (`settings.json`) |
| [`vscode/`](vscode/) | VS Code user settings and extension installations |
| [`windows/`](windows/) | Windows 10/11 preferences, privacy, and cleanup |
| [`wsl/`](wsl/) | Windows Subsystem for Linux global settings (`.wslconfig`) |
| [`setup.ps1`](setup.ps1) | Main setup orchestrator |

---

## Development & Testing

This repository includes pre-commit hooks to ensure script syntax and configuration integrity before any commit:

```powershell
# Manually run pre-commit validation:
& .\.githooks\pre-commit.ps1
```

Checks performed:
- PowerShell AST Syntax Parsing (`.ps1`, `.psm1`, `.psd1`)
- Strict JSON Syntax Validation
- Softlink Target File Existence
- `PSScriptAnalyzer` Rules & Best Practices

---

## Authors

- **Andreas Sagen** - Maintainer ([@andreassag](https://github.com/andreassag))

---

## License

This project is licensed under the `Unlicense`. For details, see [LICENSE](LICENSE).

## Acknowledgments

- [jimbrig/jimsdots](https://github.com/jimbrig/jimsdots) - inspiration for repository structure.
- [jayharris/dotfiles-windows](https://github.com/jayharris/dotfiles-windows) - reference implementations and settings.
