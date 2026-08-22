---
name: install-worktree-deps
description: Install node dependencies inside a git worktree without spiking the CPU or writing into the main checkout. Use this INSTEAD of running npm install, pnpm install, yarn install or bun install whenever the working directory is a git worktree rather than the main checkout - including when an install fails, when a dependency is added or changed, when node_modules is missing or stale, and when a linked node_modules must be replaced with a real one. Also use it when an install appears to have timed out. Invoke with /install-worktree-deps.
---

# /install-worktree-deps — install into a worktree, safely

A bare `npm install` run by an agent inside a git worktree takes the machine
down. Run this instead. It is the same install, started so that it cannot be
duplicated, cannot escape the worktree, and cannot saturate the processor.

## Run this

From inside the worktree:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>/worktree-install.ps1"
```

`<skill-dir>` is the directory this file is in. The command returns in under a
second — that is correct and expected, because the install runs detached. Then
poll for the result:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>/worktree-install.ps1" -Status
```

Keep polling until the status reads `finished, exit 0` or `FAILED`. Do not
start a second install while one is running; the script refuses anyway.

Useful switches: `-Cores <n>` to change how much of the processor the install
may use (default 6, always clamped to leave two cores free), `-Force` to stop a
running install and start over, `-Root <path>` to target a worktree other than
the current directory.

## Never do these

- **Never run a bare install in a worktree.** Not `npm install`, not
  `pnpm install`, not `yarn install`, not `bun install`, not with any flag.
- **Never install into the main checkout.** The script refuses. A project's
  main checkout is often serving something — a dev server, a worker — and
  reinstalling under it is the owner's decision, taken at a moment of their
  choosing.
- **Never re-run a command that reported a timeout** without first checking
  whether it is still running. See below.
- **Never install through a linked `node_modules`.** The script removes the
  link first. Removing it by hand and then installing is not the same thing,
  because the ordering guard is what protects the main checkout.

## Why each guard exists

An agent that understands these will not route around them.

**A command that outlives its timeout is abandoned, not stopped.** This was
measured on Windows: a command reported to the agent as timed out after two
minutes was still running, still accumulating processor time, eight minutes
later. A full install takes longer than a typical two-minute tool timeout, so
an install always looks like it failed. The agent retries, and now two installs
are unpacking into the same folder and competing for the same download cache.
Retry again and there are three. That is the CPU spike. A person waits for the
one install they started, which is why installing by hand never shows the
fault. Starting the install detached and polling for a recorded exit code
removes the false failure, and therefore removes the retry.

**A junction is invisible to a package manager.** Where a worktree shares
dependencies with the main checkout through a Windows junction, the file APIs
npm uses resolve through it without knowing it is there. A file written to
`node_modules` in a worktree was confirmed to appear in the main checkout. An
install through that junction rewrites and prunes the dependencies of whatever
the main checkout is running. The script deletes the junction first, then
verifies the main checkout's dependencies are still intact before continuing.

**Nothing else bounds an install.** At normal priority across every core, an
install competes with everything else on the machine. The script pins the
install to a few cores at idle priority, and does so in the child process
before the package manager starts, because a Windows process inherits priority
and core pinning from its parent at creation. Every process the install spawns
is therefore covered.

## When no install is needed at all

Where a project shares dependencies with the main checkout, a new worktree
needs a link, not an install:

```powershell
New-Item -ItemType Junction -Path node_modules -Target "<main-checkout>\node_modules"
```

That is instant and costs no disk. Reach for this skill only when the change
adds or alters a dependency, or when the linked dependencies do not match what
the worktree needs.

## Reading the result

The status output ends in one of three states:

- `finished, exit 0` — the install worked, and the log reports how many
  packages arrived.
- `FAILED, exit <n>` — the log tail is printed with deprecation warnings
  stripped. Fix the cause; do not simply re-run.
- `running` — still going. Poll again rather than starting another.

Logs live outside the repository, under the system temp directory in
`worktree-install/<worktree-name>-<hash>/`, so no project needs a gitignore
entry. The status output prints the exact path.

## Limits

Windows only: the scripts are PowerShell and depend on Windows junctions,
process priority classes and processor affinity. On macOS or Linux the same
reasoning holds, but the mechanism would be a symlink check plus `nice` and
`taskset`, which is not built here.

The package manager is chosen from the lockfile present: pnpm, yarn and bun are
recognised, and npm is the default.
