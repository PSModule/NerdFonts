# Font Data Updater

This directory contains scripts for automating the maintenance of the NerdFonts module.

## Update-FontsData.ps1

This script automatically updates the `src/FontsData.json` file with the latest font metadata from the
[ryanoasis/nerd-fonts](https://github.com/ryanoasis/nerd-fonts) repository.

### Features

- **Automatic Updates**: Runs daily via GitHub Actions to fetch the latest font data
- **PR Supersedence**: Automatically closes older update pull requests when a new update is created
- **Clean Repository**: Ensures only the most recent update PR remains open

### How It Works

1. **Scheduled Execution**: The script runs daily at midnight UTC via the `Update-FontsData` workflow
2. **Data Fetching**: Retrieves the latest font release metadata from the NerdFonts repository
3. **Change Detection**: Compares new data with existing `FontsData.json`
4. **PR Creation**: If changes are detected:
   - Creates a new branch named `auto-update-YYYYMMDD-HHmmss`
   - Commits the updated `FontsData.json`
   - Opens a pull request with title `Auto-Update YYYYMMDD-HHmmss`
5. **PR Supersedence**: After creating a new PR, the script:
   - Searches for existing open PRs with titles matching `Auto-Update*` (excluding the newly created PR)
   - Closes each superseded PR with a comment referencing the new PR number
   - Deletes the branches associated with superseded PRs
   - Ensures only the latest update PR remains open

### PR Lifecycle Management

The font data updater implements PR supersedence similar to Dependabot. When a new update PR is created:

- The script first creates the new PR
- Then checks for existing open `Auto-Update*` PRs (excluding the newly created one)
- Each existing PR receives a comment referencing the new PR number:

  ```text
  This PR has been superseded by #[NEW_PR_NUMBER] and will be closed automatically.

  The font data has been updated in the newer PR. Please refer to #[NEW_PR_NUMBER] for the most current changes.
  ```

- All superseded PRs are automatically closed
- Branches for closed PRs are deleted

This means there is no need for a separate cleanup workflow on merge — by the time a PR is merged,
it is already the only open Auto-Update PR.

### Workflow

#### Update-FontsData.yml

Handles the scheduled updates, PR creation, and supersedence:

- **Trigger**: Daily at midnight UTC, or manual via `workflow_dispatch`
- **Authentication**: Uses GitHub App credentials for API access

### Manual Execution

You can manually trigger an update using the GitHub Actions UI:

1. Go to the **Actions** tab in the repository
2. Select the **Update-FontsData** workflow
3. Click **Run workflow**
4. Select the branch and click **Run workflow**

### Configuration

The supersedence behavior is built into the script and requires no additional configuration. The message
posted when closing superseded PRs can be customized by modifying `scripts/Update-FontsData.ps1`.

### Development

To test changes to the update script:

1. Create a feature branch
2. Modify `scripts/Update-FontsData.ps1`
3. Push the branch
4. Manually trigger the workflow on your feature branch
5. The script will detect it's running on a feature branch and update the existing branch instead of
   creating a new PR

### Troubleshooting

- **No updates available**: If the NerdFonts release contains the same data, no PR will be created
- **Authentication errors**: Ensure the GitHub App credentials are correctly configured
