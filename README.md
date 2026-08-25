# Windows Dotfiles (`windots`)

> [!IMPORTANT]
> Dotfiles repository intended for personal Windows 10/11 workstation setup. Feel free to use and adapt these configurations for your own workflow.

This repository manages automated setup, configuration files, and software installation for Windows 10/11, PowerShell, Visual Studio Code, Git, Windows Terminal, WSL, GnuPG, PowerToys, Micromamba, and R (with Radian and Rdots integration).

---

## Setup & Usage

### 🚀 Quick Start (Fresh Machine - No Git Required)
On a brand new Windows 10/11 installation, run this one-liner in PowerShell (as Administrator):

```powershell
irm https://raw.githubusercontent.com/andreassag/windots/main/install.ps1 | iex
```

> [!NOTE]
> The bootstrapper automatically downloads the repository archive, installs package managers and dependencies (Winget, Git, PowerShell 7, Windows Terminal, GnuPG, Mamba, VS Code), and executes `setup.ps1`.

---

### Manual Setup (With Git)

#### 1. Clone the repository
```powershell
git clone https://github.com/andreassag/windots.git "$HOME\repo\windots"
Set-Location "$HOME\repo\windots"
```

#### 2. Preview changes (Dry Run)
You can safely test the setup without modifying your system or requiring elevation:
```powershell
.\setup.ps1 -DryRun
```

#### 3. Run full setup (Run as Administrator)
Launch an elevated PowerShell 5.1 or PowerShell 7 session and run:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope Process -Force
.\setup.ps1
```

#### 4. Run specific components
You can selectively configure individual tools or modules:
```powershell
.\setup.ps1 -Components git,powershell,terminal,mamba
```

---

## Uninstallation

To revert symlinks and restore your original `.old` configuration files:

```powershell
# Windows PowerShell / pwsh:
.\uninstall.ps1

# Preview uninstallation without making changes:
.\uninstall.ps1 -DryRun

# Revert symlinks and remove the provisioned 'R' environment:
.\uninstall.ps1 -RemoveEnvironments
```

Or via Bash (WSL / Git Bash):
```bash
bash uninstall.sh
```

---

## Directory Structure

| Directory / File | Description |
| :--- | :--- |
| [`.githooks/`](.githooks/) | Git pre-commit hooks for syntax, JSON, and softlink validation |
| [`.github/`](.github/) | GitHub Actions CI/CD workflows, Dependabot config, and automerge workflow |
| [`.vscode/`](.vscode/) | Workspace settings and recommended extensions |
| [`git/`](git/) | Git configuration (`config`, `gitconfig`, `.gitignore`, `.gitmessage`, `.gitattributes`) |
| [`gpg/`](gpg/) | GnuPG configuration (`gpg.conf`, `common.conf`) |
| [`mamba/`](mamba/) | Mamba / Micromamba setup, `.mambarc`, R environment (with Radian), and Rdots integration |
| [`powershell/`](powershell/) | PowerShell profile (`profile.ps1`) and module setup |
| [`powertoys/`](powertoys/) | Microsoft PowerToys setup |
| [`scripts/`](scripts/) | Shared helper functions (`common.ps1`, `automerge.ps1`) |
| [`terminal/`](terminal/) | Windows Terminal profiles, Git path injection, and R (radian) profile (`settings.json`) |
| [`vscode/`](vscode/) | VS Code user settings and extension installations |
| [`windows/`](windows/) | Windows 10/11 preferences, privacy, and cleanup |
| [`wsl/`](wsl/) | Windows Subsystem for Linux global settings (`.wslconfig`) |
| [`install.ps1`](install.ps1) | Standalone zero-dependency bootstrapper and dependency installer |
| [`setup.ps1`](setup.ps1) | Main setup orchestrator |
| [`uninstall.ps1`](uninstall.ps1) | PowerShell uninstallation and backup restoration script |
| [`uninstall.sh`](uninstall.sh) | Cross-platform Bash uninstallation script |

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
- [randy3k/radian](https://github.com/randy3k/radian) - 21st century interactive R console.
