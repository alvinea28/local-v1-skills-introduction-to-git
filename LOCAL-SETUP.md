# Local setup

This is a **local-first** copy of the GitHub introduction *Introduction to Git* exercise. The original relies on a GitHub Codespace that installs a background monitor; this version runs that monitor on your own machine instead.

## How Mona sees your work

Mona has no way to watch your computer. Every step in the workflow in `.github/workflows/` listens for a [`repository_dispatch`](https://docs.github.com/en/actions/reference/events-that-trigger-workflows#repository_dispatch) event:

| Step | Event type | Fired by |
| --- | --- | --- |
| 1 | `git-config-changed` | `.exercise-monitor/watch-git-config.ps1` |
| 2 | `post-commit` | `.githooks/post-commit` |
| 3 | `post-checkout` | `.githooks/post-checkout` |
| 4 | `post-commit` | `.githooks/post-commit` |
| 5 | `post-merge` | `.githooks/post-merge` |
| 6 | `issue_comment` | automatic, after Step 5 |

All of them call `.exercise-monitor/send-event.ps1`, which posts the event through the GitHub CLI to progress the next activity.

The watcher also reports repository-level config changes (for example when setup sets
`core.hooksPath`). Step 1's workflow ignores those, so no result is posted until you actually
change your **global** identity.

## Prerequisites

- [Git](https://git-scm.com) 2.30 or newer
- [GitHub CLI](https://cli.github.com), authenticated with the `repo` scope:

  ```powershell
  gh auth login
  ```

- PowerShell 5.1 (built into Windows) or [PowerShell 7+](https://aka.ms/powershell) on macOS/Linux

## Install

Clone the repository, open the folder in Visual Studio Code, and the **Start Activity** task runs automatically (click **Allow** if VS Code asks about automatic tasks).

If you prefer to run it yourself, or you are not using VS Code:

```powershell
.\start-activity.ps1
```

This one command:

1. Checks that Git and the authenticated GitHub CLI are available.
2. Copies the sample game from `.exercise-assets/game/src` into `./src` as **untracked** files.
3. Sets `core.hooksPath` to `.githooks`, enabling the `post-commit`, `post-checkout`, and `post-merge` events.
4. Starts `watch-git-config.ps1` hidden in the background so the `git-config-changed` event (Step 1) fires automatically.

## Simulating a brand new repository

Step 2 asks you to run `git init`, `git add src/*`, and make an *Initial commit*. In a clone
those commands would do nothing, because Git already tracks every file.

To keep the exercise realistic, the pristine game is stored in `.exercise-assets/game/src`
and `start-activity.ps1` copies it to `./src`, which is **not tracked and not ignored**.
You therefore see genuine untracked files and create a genuine first commit.

Two harmless differences remain from the Codespace version:

- `git init` prints *"Reinitialized existing Git repository"* instead of *"Initialized"*. It does
  not touch your history, remotes, or config.
- `git status` shows untracked files instead of *"No commits yet"*, because this clone already
  has the exercise's own history. That history is a single commit, so `git log` stays readable
  once you start adding your own.

The game documentation you write in Step 2 is `README.md` at the top level. This repository
deliberately ships **without** a `README.md`: the exercise deletes the welcome page it generates
at startup, so the name is free for you to create. If your editor ever offers `README-1.md`,
it means a `README.md` still exists - delete it and create the file again.

To start Step 2 over, delete `./src` and `README.md`, then re-run `.\start-activity.ps1`.

Stop the background watcher when you are done:

```powershell
.\stop-activity.ps1
```

## Sending an event manually

If a hook doesn't fire, or you want to re-check a step, call the sender directly:

```powershell
.\.exercise-monitor\send-event.ps1 -Event git-config-changed -ConfigType global
.\.exercise-monitor\send-event.ps1 -Event post-commit
.\.exercise-monitor\send-event.ps1 -Event post-merge
.\.exercise-monitor\send-event.ps1 -Event post-checkout -PreviousHead <sha> -NewHead <sha>
```

## Notes and gotchas

- `repository_dispatch` only triggers workflows on the **default branch**, so the workflow files must exist on `main`. Do your exercise work on branches as instructed - the events still route to the `main` copies of the workflows.
- Each step workflow posts the next `.github/steps/N-step.md` as a comment on the exercise issue. Nothing is written back to your working files, so you never need to `git pull` mid-exercise.
- The repository starts with a single commit. When the exercise begins, Step 0 rewrites `main` back to that commit to drop the automated welcome-page commit. Clone **after** the exercise issue appears so you get the final history.
- Hooks are not copied by `git clone` in a usable state. If you clone this repo somewhere else, run `.\start-activity.ps1` there.
- Uninstall at any time with `.\stop-activity.ps1` followed by `git config --unset core.hooksPath`.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `gh: command not found` | Install the GitHub CLI and restart the terminal, then re-run `.\start-activity.ps1` |
| `HTTP 404` from `gh api` | Your token lacks the `repo` scope - run `gh auth refresh -s repo` |
| Hook doesn't run on commit | Confirm `git config core.hooksPath` returns `.githooks`; if not, run `.\start-activity.ps1` |
| VS Code didn't run the task | Run **Terminal > Run Task > Start Activity**, or `.\start-activity.ps1` |
| Workflow ran but failed the check | Read the step results comment on the exercise issue - the payload didn't meet the step's requirement (commit count, keyword, branch, etc.) |
| `git add src/*` finds nothing | `./src` is missing - run `.\start-activity.ps1` to deliver it |
| Editor creates `README-1.md` | A `README.md` already exists - delete it, then create the file again |
| Step 2 fails even though your commit messages look right | Old copies of `.exercise-monitor/send-event.ps1` sent every commit message as `null` under Windows PowerShell 5.1. Pull the latest version of this repository. |
