# NerdFonts

This is a PowerShell module for installing NerdFonts on your system. This module and repository does not contain the fonts themselves,
but rather a way to install them on your system.

🎉 Kudos to owner of NerdFonts, @ryanoasis and the rest of the NerdFonts community! 🎉
For any issues with the fonts themselves, please refer to the [NerdFonts](https://github.com/ryanoasis/nerd-fonts/) repository.
All donations on this repository will go to the NerdFonts project.

## Prerequisites

- This module is cross-platform and supports the latest LTS version of [PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/overview) on Windows, Linux, and macOS. This is not to be confused with Windows PowerShell. Install PowerShell by following the [official installation guide](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell).
- This module depends on the [Fonts](https://psmodule.io/Fonts) module to manage fonts on the system. This will be installed automatically when installing the module.

## Installation

To install the module simply run the following command in a PowerShell terminal.

```powershell
Install-PSResource -Name NerdFonts
Import-Module -Name NerdFonts
```

## Usage

### Install a NerdFont

To install a NerdFont on the system you can use the following command.

```powershell
Install-NerdFont -Name 'FiraCode' # Tab completion works on name
```

To download the font from the NerdFonts repository and install it on the system, run the following command.

```powershell
Install-NerdFont -Name 'FiraCode' -Scope AllUsers #Tab completion works on Scope too
```

### Install all NerdFonts

To install all NerdFonts on the system you can use the following command.

This will download and install all NerdFonts to the current user.
```powershell
Install-NerdFont -All
```

To install all NerdFonts on the system for all users, run the following command.
This requires the shell to run in an elevated context (sudo or run as administrator).

```powershell
Install-NerdFont -All -Scope AllUsers
```

### Check if a NerdFont is installed

The [Fonts](https://psmodule.io/Fonts) module is installed automatically as a dependency and provides the
[`Get-Font`](https://psmodule.io/Fonts/Functions/Get-Font/) command for querying installed fonts on the system.

To check if a specific NerdFont is installed for the current user:

```powershell
Get-Font -Name 'FiraCode*'
```

To check across all users on the system:

```powershell
Get-Font -Name 'FiraCode*' -Scope AllUsers
```

If the command returns results, the font is installed. If it returns nothing, the font is not installed in that scope.

### Update an installed NerdFont

Individual font files do not embed a NerdFonts release version, so there is no direct way to check whether an installed
NerdFont is outdated. To ensure you have the version bundled with the module, reinstall the font using the `-Force` parameter:

```powershell
Install-NerdFont -Name 'FiraCode' -Force
```

If the font was originally installed for all users, update it with the matching scope (requires elevated privileges):

```powershell
Install-NerdFont -Name 'FiraCode' -Force -Scope AllUsers
```

This re-downloads and installs the font version bundled with your installed NerdFonts module, overwriting any existing
files. To pick up newer font releases, update the NerdFonts module first (`Update-Module -Name NerdFonts`).

### Uninstall a NerdFont

To uninstall a NerdFont, use the [`Uninstall-Font`](https://psmodule.io/Fonts/Functions/Uninstall-Font/) command
from the [Fonts](https://psmodule.io/Fonts) module (installed automatically as a dependency).

To uninstall a NerdFont from the current user:

```powershell
Uninstall-Font -Name 'FiraCode*' # Tab completion works on name
```

To uninstall a NerdFont for all users (requires elevated privileges):

```powershell
Uninstall-Font -Name 'FiraCode*' -Scope AllUsers
```

## Contributing

Coder or not, you can contribute to the project! We welcome all contributions.

### For Users

If you don't code, you still sit on valuable information that can make this project even better. If you experience that the
product does unexpected things, throw errors or is missing functionality, you can help by submitting bugs and feature requests.
Please see the issues tab on this project and submit a new issue that matches your needs.

### For Developers

If you do code, we'd love to have your contributions. Please read the [Contribution guidelines](CONTRIBUTING.md) for more information.
You can either help by picking up an existing issue or submit a new one if you have an idea for a new feature or improvement.

## Links

- NerdFonts | [GitHub](https://github.com/ryanoasis/nerd-fonts) | [Web](https://www.nerdfonts.com/)
