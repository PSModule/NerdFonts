# NerdFonts

NerdFonts is a PowerShell module for downloading and installing [Nerd Fonts](https://www.nerdfonts.com/) on Windows, macOS, and Linux. The module installs the fonts on your system; it does not bundle the fonts themselves.

🎉 Kudos to @ryanoasis and the Nerd Fonts community! 🎉 For issues with the fonts themselves, see the [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts/) repository. All donations on this repository go to the Nerd Fonts project.

## Prerequisites

- Cross-platform: supports the latest LTS version of [PowerShell](https://learn.microsoft.com/powershell/scripting/overview) on Windows, Linux, and macOS (not Windows PowerShell).
- Depends on the [Fonts](https://psmodule.io/Fonts) module for system font management. It is installed automatically with this module.

## Installation

Install the module from the PowerShell Gallery:

```powershell
Install-PSResource -Name NerdFonts
Import-Module -Name NerdFonts
```

## Usage

Install a Nerd Font for the current user (the name supports tab completion):

```powershell
Install-NerdFont -Name 'FiraCode'
```

Install every Nerd Font, or limit an install to a single variant such as the monospace family:

```powershell
Install-NerdFont -All
Install-NerdFont -Name 'FiraCode' -Variant Mono
```

Install for all users (requires an elevated session), and uninstall through the Fonts module:

```powershell
Install-NerdFont -Name 'FiraCode' -Scope AllUsers
Uninstall-Font -Name 'FiraCode*'
```

## Behavior and caching

- Already-installed fonts are skipped unless you pass `-Force`. Downloaded archives are cached per Nerd Fonts release, so repeated installs do not re-download the same ZIP.
- Cache locations: `%LOCALAPPDATA%/PSModule/NerdFonts/cache` on Windows, and `$HOME/.cache/PSModule/NerdFonts` on macOS and Linux.
- Font files do not embed a Nerd Fonts version, so there is no version check. Reinstall with `-Force` to get the version bundled with the module (`-Force` also bypasses the archive cache). To pick up newer font releases, update the module first with `Update-PSResource -Name NerdFonts`.

## Documentation

Documentation is published at [psmodule.io/NerdFonts](https://psmodule.io/NerdFonts/).

Use PowerShell help and command discovery for module details:

```powershell
Get-Command -Module NerdFonts
Get-Help -Name Install-NerdFont -Examples
```

## Links

- Nerd Fonts: [GitHub](https://github.com/ryanoasis/nerd-fonts) | [Web](https://www.nerdfonts.com/)
