# Repository Settings

This document describes the current repository configuration for PairReader.

## Repository Info

- **Name**: pairreader
- **Owner**: sfnsys710
- **Visibility**: Public
- **License**: MIT
- **Default Branch**: main

---

## Merge Settings

- **Merge commits**: ❌ Disabled
- **Squash merge**: ❌ Disabled
- **Rebase merge**: ✅ Enabled (only allowed method)
- **Auto-delete branches**: ✅ Enabled

**Why rebase**: Maintains clean, linear git history while preserving individual commits.

---

## Branch Protection (main)

**Protection Method**: Repository Ruleset (modern approach)

### Required Status Checks
- `pre-commit` - Pre-commit hooks validation
- `pytest` - Unit tests must pass
- **Strict mode**: ✅ Enabled (branches must be up-to-date)

### Pull Request Requirements
- **Required reviews**: 1 approval required
- **Code owner review**: ✅ Required (see `.github/CODEOWNERS`)
- **Last push approval**: ✅ Required (last person who pushed cannot approve)
- **Dismiss stale reviews**: ✅ Enabled (re-review after new pushes)
- **Admin bypass**: ✅ Enabled (repository admins can bypass all rules)

### Branch Rules
- **Required linear history**: ✅ Enabled (no merge commits)
- **Force pushes**: ❌ Blocked (non-fast-forward prevented)
- **Branch deletion**: ❌ Blocked
- **Branch creation**: ❌ Blocked (main branch only)
- **Direct updates**: ❌ Blocked (must use PRs)

### Allowed Merge Methods
- **Merge commits**: ✅ Allowed
- **Squash merge**: ✅ Allowed
- **Rebase merge**: ✅ Allowed

---

## Security Settings

### Active
- **Secret scanning**: ✅ Enabled
- **Push protection**: ✅ Enabled

### Disabled (Recommended to Enable)
- **Dependabot alerts**: ❌ Disabled
- **Dependabot security updates**: ❌ Disabled
- **CodeQL scanning**: ❌ Not configured

---

## Environments

### gcp-dev
- **Protection rules**: None
- **Branch policy**: None
- **Secrets**: `SA` (Google Cloud service account key)

---

## Access

- **Collaborators**: sfnsys710 (Admin)
- **Teams**: None
- **Code owners**: Defined in `.github/CODEOWNERS`

---

**Key points**:
- Cannot push directly to main (must use PRs)
- CI must pass before merge (`pre-commit` + `pytest`)
- Requires 1 approval from code owner (defined in `.github/CODEOWNERS`)
- Last person who pushed cannot approve their own PR
- **Repository admins can bypass all rules** (for flexibility on solo projects)
- Protection enforced via repository ruleset (ID: 8656916)

---

## Future TODOs

### Security Improvements
- [ ] Enable Dependabot vulnerability alerts
- [ ] Enable Dependabot security updates
- [ ] Add CodeQL workflow for security scanning
- [ ] Migrate to Workload Identity Federation (remove service account key)

### CI/CD Enhancements
- [ ] Pin GitHub Actions to commit SHAs
- [ ] Add container image scanning (Trivy/Grype)
- [ ] Restrict allowed actions to verified only

---

**Last Updated**: 2025-10-19

## Changelog

### 2025-10-19
- **Migrated to Repository Rulesets**: Removed classic branch protection in favor of modern repository ruleset
- **Added PR requirements**: Now requires 1 code owner approval + last push approval
- **Consolidated protections**: All branch rules now managed via single ruleset (ID: 8656916)
- **Fixed overlapping rules**: Eliminated duplicate settings between classic protection and ruleset
- **Removed branch lock**: Previous setup had `lock_branch: true` which was overly restrictive
- **Added admin bypass**: Repository admins (actor_id: 5, RepositoryRole) can bypass all ruleset rules for solo project flexibility
