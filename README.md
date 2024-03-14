# NerdFonts

A PowerShell module to manage NerdFonts.

Kudos to owner of NerdFonts, @ryanoasis!

# NerdFonts

This is a PowerShell module for installing NerdFonts on your system.

## Prerequisites

This module currently only supports Windows operating systems.
This module also depends on the [Fonts](https://psmodule.io/Fonts) module to manage fonts on the system.

## Installation

To install the module simply run the following command in a PowerShell terminal.

```powershell
Install-PSResource -Name NerdFonts
Import-Module -Name NerdFonts
```

## Usage

You can use this module to install NerdFonts on your system.

### Install a NerdFont

To install a NerdFont on the system you can use the following command.

```powershell
Install-NerdFont -Name 'FiraCode'
```

To download the font from the NerdFonts repository and install it on the system, run the following command.

```powershell
Install-NerdFont -Name 'FiraCode' -Scope AllUsers
```

### Install all NerdFonts

To install all NerdFonts on the system you can use the following command.

```powershell
Install-NerdFont -All -Scope AllUsers
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
