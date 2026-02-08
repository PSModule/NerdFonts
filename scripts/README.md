# Font Data Updater

This directory contains the automated font data updater script that keeps the NerdFonts module synchronized with the latest fonts from the [ryanoasis/nerd-fonts](https://github.com/ryanoasis/nerd-fonts) repository.

## Update-FontsData.ps1

The `Update-FontsData.ps1` script is automatically run on a daily schedule via GitHub Actions. It performs the following tasks:

1. **Fetch Latest Fonts**: Retrieves the latest font release metadata from the NerdFonts repository
2. **Update Font Data**: Updates the `src/FontsData.json` file with the latest font information
3. **Create/Update PR**: Creates a pull request with the changes or updates an existing branch
4. **PR Supersedence**: Automatically closes older, superseded font update PRs

## PR Supersedence Behavior

Similar to Dependabot's PR lifecycle management, the updater implements automatic PR supersedence:

### When Creating a New PR

When the updater creates a new font data update PR:
- It searches for existing open PRs with "Auto-Update" in the title
- Automatically closes those older PRs with a comment: "This PR has been superseded by a newer font data update."
- Creates the new PR with the latest changes

### When Updating an Existing Branch

When the updater pushes changes to an existing update branch:
- It searches for other open font update PRs
- Closes them with a comment indicating which branch supersedes them
- Updates the existing branch with the latest changes

### Benefits

This approach:
- Keeps the repository tidy by removing outdated update PRs
- Prevents confusion about which PR should be reviewed/merged
- Streamlines the review and merge process
- Mirrors the familiar behavior of Dependabot

## Workflow

The updater runs via the `.github/workflows/Update-FontsData.yml` workflow:
- **Schedule**: Daily at midnight UTC
- **Manual**: Can be triggered via workflow_dispatch
- **Authentication**: Uses GitHub App credentials for enhanced permissions

## Customization

The supersedence message can be modified by editing the `$supersedenceMessage` variable in the script.
