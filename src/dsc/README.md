# NerdFonts DSC Resources

This folder contains DSC (Desired State Configuration) resources for the NerdFonts module.

## Available Resources

### NerdFont

The `NerdFont` resource allows you to install Nerd Fonts in a declarative way using DSC.

#### Properties

| Property | Type   | Description | Required |
|----------|--------|-------------|----------|
| Name     | string | Name of the NerdFont to install | Yes (if All is not specified) |
| All      | bool   | Whether to install all Nerd Fonts | No (default: false) |
| Ensure   | string | Whether the font should be present or absent | No (default: 'Present') |
| Scope    | string | Scope to install the font in ('CurrentUser' or 'AllUsers') | No (default: 'CurrentUser') |
| Force    | bool   | Whether to force the installation | No (default: false) |

#### Examples

```powershell
# Install a specific NerdFont
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

## Notes

- The NerdFont resource does not currently support uninstalling fonts (Ensure = 'Absent'). A warning will be displayed if you attempt to uninstall fonts using this resource.
- Installing fonts in the 'AllUsers' scope requires administrator privileges.