# HironCraft project preferences

- After completing requested implementation changes and passing the relevant
  checks, commit the task's changes and push them to the configured GitHub
  remote immediately. The user requested this as the default workflow; do not
  ask for separate push confirmation each time.
- A later user instruction to keep work local or not publish overrides this
  default. Do not include unrelated changes, force-push, or overwrite remote
  history. If publication is blocked, explain the blocker.
- This preference concerns source commits, not creating GitHub releases,
  publishing unrelated artifacts, or sending in-game messages.
- Build every released version with scripts/Build.ps1 (default output: the
  dist folder inside the addon folder), verify it with
  scripts/TestReleaseArchive.ps1, and give the user the archive's full path.
  Never place the archive in the addon's root: the build copies the root and
  the archive would end up inside the next one.
