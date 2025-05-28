# NerdFonts

This is a PowerShell module for installing NerdFonts on your system. This module and repository does not contain the fonts themselves,
but rather a way to install them on your system.

🎉 Kudos to owner of NerdFonts, @ryanoasis and the rest of the NerdFonts community! 🎉
For any issues with the fonts themselves, please refer to the [NerdFonts](https://github.com/ryanoasis/nerd-fonts/) repository.
All donations on this repository will go to the NerdFonts project.

## Prerequisites

This module depends on the [Fonts](https://psmodule.io/Fonts) module to manage fonts on the system.

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

### Using with DSC (Desired State Configuration)

This module includes a class-based DSCv2 resource that can be used to declaratively install NerdFonts.

```powershell
# Install a specific NerdFont using DSC
NerdFont 'InstallHackFont' {
    Name = 'Hack'
    Ensure = 'Present'
    Scope = 'CurrentUser'
}

# Install all NerdFonts for all users
NerdFont 'InstallAllNerdFonts' {
    All = $true
    Ensure = 'Present'
    Scope = 'AllUsers'
}
```

For more details on the DSC resource, see the [DSC documentation](/src/dsc/README.md).

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
