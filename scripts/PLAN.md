# kiro-sandbox: Plan

## Status

- [x] `kiro-sandbox.sh` — launcher script (adapted from claude-sandbox.sh)
- [x] `Dockerfile.kiro` — container image with kiro-cli
- [x] Fix: unbound variable for empty arrays (`env_vars`, `args`)
- [x] Fix: install URL → `https://cli.kiro.dev/install`
- [x] Fix: add `unzip` dependency to Dockerfile
- [x] Build image successfully
- [x] Verify `kiro-cli --help` runs inside container
- [x] **Pass through kiro credentials from `$HOME`**
  - **Solution**: Mount `~/.local/share/kiro-cli` to `/custom/xdg-data/kiro-cli` and set `XDG_DATA_HOME=/custom/xdg-data`
  - Root-level mount bypasses home directory permission issues (700 on `/local/home/andglenn`)
  - Database at `~/.local/share/kiro-cli/data.sqlite3` is now accessible
- [x] Verify `kiro-cli whoami` shows authenticated session

## Remaining

- [ ] Verify interactive `kiro-cli chat` session works end-to-end
  - Currently shows "No such file or directory" error
  - May need additional mounts or environment setup

## Key Learnings

1. **Docker mount permissions**: When home directory has 700 permissions, Docker can't mount subdirectories even when running as the same UID/GID. Solution: mount to root-level paths.

2. **kiro-cli data location**: Uses XDG Base Directory spec:
   - Database: `$XDG_DATA_HOME/kiro-cli/data.sqlite3` (defaults to `~/.local/share/kiro-cli/data.sqlite3`)
   - Config: `~/.kiro/` directory

3. **Authentication**: kiro-cli uses AWS IAM Identity Center (SSO). Auth state is stored in the SQLite database, not in separate token files.

## Files

| File | Purpose |
|------|---------|
| `kiro-sandbox.sh` | Launcher — builds image on first run, mounts volumes, runs container |
| `Dockerfile.kiro` | Ubuntu 22.04 + kiro-cli via official installer |
| `PLAN.md` | This file |

## Usage

```bash
./kiro-sandbox.sh              # no AWS creds
./kiro-sandbox.sh --aws        # forward AWS creds
./kiro-sandbox.sh whoami       # verify authentication
./kiro-sandbox.sh chat         # interactive chat (needs debugging)
```
