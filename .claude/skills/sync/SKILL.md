---
name: sync
description: Pull the latest git state and sync it against Linear, OpenSpec, the roadmap docs, Supabase and the shared skills repo, then report in /simple format on branches, tickets, specs and roadmap position, ending with next steps. Hard-fails if git, the Linear MCP or the Supabase MCP is unreachable. Invoke with /sync.
---

# /sync — project state sync + next-steps report

Gather the live state of git, Linear, OpenSpec, the roadmap docs, Supabase and
the shared skills repo, cross-reference all of them against the actual code, and
produce one short report that ends with the next steps.

Only three writes are permitted, and no other: a fast-forward `git pull`, a
fast-forward `git pull` inside the shared skills clone, and copying a newer
skill file from the shared skills repo into this repo. Nothing is ever written
to Linear, OpenSpec, Supabase, Vercel or any deployment.

Every command in this skill authenticates with credentials that already exist:
the user's SSH key for git, and already-connected MCP servers for Linear and
Supabase. No command here can open a browser, print a device code, or wait on an
OAuth callback. Do not add one.

## 0. Load config

Read `.claude/sync.config.json` at the repo root.

- If it does **not** exist, do not guess. Tell the user the skill is not yet
  configured for this project, offer to scaffold one from
  `sync.config.example.json` (in this skill folder), then stop.
- Skip any integration where `enabled` is `false` or absent — do not call its
  tools, and note it in one line at the end of the report as "not configured".
- `mainBranch` is the trunk (default `main`); `project` is the name used in the
  heading.

## 1. Access gate — fail loudly, never report partially

Before gathering, confirm the three **required** sources are reachable:

| Source | Check |
| --- | --- |
| git | `git rev-parse --is-inside-work-tree` and `git fetch` both succeed |
| Linear MCP | `list_teams` (or `list_projects`) returns the configured team/project |
| Supabase MCP | `list_projects` returns `supabase.projectRef` |

If any required source is unreachable — an MCP server not connected, no network,
`projectRef` absent from the account the MCP is connected to — **stop**. Report
exactly which source failed and the one-off command or connector setup the user
must do themselves. **Do not produce the report from partial data**, and do not
substitute inference for a source you could not read.

There is no fallback path for Supabase. The Supabase MCP must be connected. Do
not substitute the Supabase CLI, and do not report a database section built from
migration files alone.

## 2. Gather (run independent reads in parallel)

### Git — `git.enabled`

```bash
git pull --ff-only            # pull the latest; report if it cannot fast-forward
git fetch --all --prune
git status -sb
git branch -a -vv --sort=-committerdate
git log --oneline --date=short --format='%h %ad %d %s' -15
```

Remotes are SSH and authenticate with the user's SSH key. A prompt for a
username or password means the remote is misconfigured as `https://`; report
that rather than answering it.

Capture:
- Current branch; clean or dirty (list uncommitted/untracked paths).
- Ahead/behind vs upstream for the current branch.
- **Which branch holds the most recent commit** (local and remote), with its
  date and subject.
- Branches merged into `mainBranch` (deletable) vs. unmerged with unique work.
- Whether `mainBranch` is behind any feature branch.

### Deployment — `vercel.enabled`

Vercel deploys on push, through its GitHub integration: a push to `mainBranch`
deploys to production, and a push to any other branch deploys a preview. Nothing
is deployed by hand.

Deployment state is therefore derived entirely from git, with no API call, no
CLI and no token:

- Unpushed commits on `mainBranch` are production changes that have not
  deployed. Flag them.
- Unpushed commits on the current feature branch have no preview yet. Flag them
  in one line.

Do not invoke the `vercel` CLI and do not invoke the `gh` CLI. Neither is needed:
`vercel ls` starts a device-login flow, and `gh` uses its own OAuth token rather
than the SSH key.

### Shared skills repo — `skills.enabled`

The skills in this repo are copies of the skills in the shared skills repo named
by `skills.repo`. Keep the two in step.

```bash
# clone once per run, into a scratch dir, over SSH
git clone --depth 50 <skills.repo.ssh> <scratch>/skills-repo
```

Compare every skill folder under `skills.path` (default `.claude/skills`) on
both sides. Compare file **content ignoring line endings** — this repo stores
CRLF and the shared repo stores LF, so a naive byte comparison reports every
file as different:

```bash
diff -q --strip-trailing-cr <shared-file> <local-file>
```

For each file whose content genuinely differs, decide which side is newer, then
act on that:

```bash
git status --porcelain -- <path>     # uncommitted local edit?
git log -1 --format=%cI -- <path>    # otherwise, last-commit date
```

A local file with uncommitted changes is **always** treated as the newer side,
whatever the commit dates say, because the local edit has not been committed yet
and its commit date is therefore stale. Never overwrite an uncommitted local
edit.

- Shared repo newer → **copy the shared version over the local one**, and report
  the skill name and both dates. This is a permitted write.
- Local repo newer → **do not push**. Report the skill name, both dates, and a
  one-line summary of what differs, then ask the user whether the local version
  should be pushed to the shared repo.
- A skill present in the shared repo and missing here → copy it in, and report it.
- Dates equal but content differs → report as a conflict and ask; never guess.

Only skills that exist on **both** sides are compared and reported. A skill that
exists here and not in the shared repo is out of scope: it is not compared, not
pushed, and not mentioned in the report at all.

Never push to the shared repo without the user saying so in the current
conversation.

### OpenSpec — `openspec.enabled`

```bash
npx openspec list
```

For **each active change**, read `openspec/changes/<name>/tasks.md` (plus
`proposal.md` / `design.md` if present) and classify it by checking the code, not
the checkboxes:

- **Code-complete, needs verification** — every task that can be done in code is
  done; only testing/live confirmation remains. → the archive candidate. Name the
  exact verification step required.
- **In progress** — remaining tasks describe code that does not exist yet. → name
  the single next actionable task.
- **Stale / drifted** — unchecked boxes describe code that already exists (or was
  built differently elsewhere). → flag for reconciliation; never blindly
  re-implement (this is the process-poisoning vector in `CLAUDE.md`).
- **Blocked on a human** — an unchecked box that cannot be finished in code. →
  recommend moving it to Linear and removing the box.

Spot-check the files named in unchecked tasks to decide which bucket applies.

### Linear — `linear.enabled`

Scope every query to `linear.team` + `linear.project` from config.

- `list_issues` for states In Progress, Todo, and In Review, ordered by priority.
- For each: identifier, title, state, priority, labels (phase labels matter), and
  whether it maps to an active OpenSpec change or a git branch.
- Separate three groups explicitly:
  - **In progress needing verification only** — the code exists; the ticket is
    open because it has not been tested/confirmed. Say what test closes it.
  - **In progress with code still to write.**
  - **Backlog ideas** — never build straight from these; per governance a backlog
    item must first be promoted into a new OpenSpec change.

### Code cross-reference

For every spec/ticket claimed to be code-complete, verify against the repo:
locate the files, functions or migrations it names and confirm they exist and
behave as described. A checked box or a "Done" ticket with no matching code is a
finding, and so is finished code sitting under an open ticket.

### Database — `supabase.enabled`

Through the Supabase MCP only: `list_migrations` and `list_tables` for parity
against the migration files in `supabase/migrations`, `get_advisors` for security
and performance, `list_branches`. Use `execute_sql` for **read-only** sanity
checks only when a spec or ticket depends on live data (a row count, a flag's
value, whether a backfill ran), and only when the answer changes the report's
conclusion.

Flag: migration files not applied to the remote project, remote migrations
missing from the repo, and any security or performance advisor.

### Roadmap docs

Read the paths listed in `docs.roadmap`. If the config lists none, search
`docs/**/*roadmap*`, `ROADMAP.md`, and any doc `CLAUDE.md` names as canonical.

- `git log -1 --date=short -- <file>` for last-touched date, compared against the
  dates of recent feature commits.
- Check whether items marked "planned"/"next" are already shipped in code, and
  whether shipped work is missing from the doc.
- Verdict per doc: **current** or **stale**, naming the specific lines that are
  wrong.
- Then one line stating where the project actually stands: which phase is done,
  which is in flight, what the next milestone is.

### Optional integrations

Run only when enabled, and give each one line in the report unless it is red:
Doppler (`doppler configs`, `doppler secrets --only-names` — names only, never
values; flag if the locally selected config differs from `doppler.config`),
Sentry (unresolved issues from the last 48h by event count), Trigger.dev (recent
run statuses; flag failed or stuck).

## 3. Report

Write the whole report in **`/simple` format** — read
`.claude/skills/simple/SKILL.md` and follow it exactly. In particular: bold
one-line section titles that are not list items, bulleted facts only, no prose
paragraphs, no numbered lists, passive voice, no pronouns as subjects, every tool
and service named directly by its own name, no file paths or commit hashes, no
em-dashes, dates as D-Mon-YYYY.

The report answers three questions and nothing else: where things stand right
now, which loose ends are open, and where work resumes. Hold to these limits:

- **Present state only.** Report what is true at this moment. Never report what
  was fetched, pulled, deleted, copied or checked during the run. An action taken
  this run appears only where the action left a loose end.
- **Green is silent.** A healthy optional integration is not mentioned at all. A
  section with genuinely nothing open gets one bullet saying so, and no more.
- At most 6 top-level bullets under any one section title.
- One fact per bullet, under fifteen words. Nest the detail rather than extending
  the bullet.
- Where more than 6 items share a state, give the count and what distinguishes
  the group, never the list.

**Source-anchored nesting.** Every finding is filed under the artefact that owns
it, and the artefact leads the line:

- A ticket bullet begins with the identifier, then the title, then the state.
  Everything known about that ticket is nested beneath.
  - `AZ-218 — Locomotion CPG against planted feet. Todo, High.`
- A spec bullet begins with the change name, then the task count, then the
  bucket. The next action and any human-blocked task are nested beneath.
- A roadmap bullet begins with a link to the document, then current or stale. The
  specific wrong lines are nested beneath.
- A database bullet begins with the table, policy or function at fault.
- A branch bullet begins with the branch name.

Nested detail is where specificity lives. A nested bullet names the exact test,
the exact task number, the exact policy, the exact line. Vague nesting is worse
than no nesting.

Sections, in this order, each with a bold one-line title:

- **Blockers** — anything red, each filed under the artefact that is stuck. Omit
  the whole section when nothing is red.
- **Branches** — the trunk first, then any branch holding unmerged work.
  - Under the trunk: clean or dirty, ahead or behind, and whether production is
    carrying undeployed commits.
  - Under a feature branch: its newest commit date and what the branch holds.
  - A branch with nothing unmerged is not listed.
- **Specs** — one bullet per active OpenSpec change, source-anchored as above.
  - Nested: the single next actionable task, by number.
  - Nested: each task blocked on a human, by number, naming the decision needed.
- **Tickets** — grouped by what the ticket needs, with the groups as labelled
  top-level bullets and the tickets nested beneath by identifier.
  - Needs verification only, with the exact test that closes each ticket.
  - Needs code still.
  - Drifted, where the ticket no longer describes the live direction.
  - Backlog is given as a count only, never enumerated.
- **Database** — one bullet per fault, anchored on the table, policy or function.
  Advisories of the same kind are collapsed into one bullet with a count.
- **Skills** — only genuine drift against the shared skills repo. One bullet when
  none is found.
- **Roadmap** — one bullet per document, then one bullet stating where the
  project actually stands.
- **Loose ends** — everything open that is not already a next step: an unchecked
  task that belongs in Linear, a stale document, an undeployed commit, a ticket
  whose title has drifted. Omit when empty.
- **Next steps** — at most 5 bullets, in priority order, one action each,
  beginning with the ticket, spec or branch, then the verb: build, test, verify,
  archive, reconcile, push.
- **Suggested next batch** — a shortlist of at most 4 tickets recommended for the
  next block of work, each with one nested line saying why that ticket is ready
  and what it unblocks. Backlog tickets appear here only with a note that
  promotion into a new OpenSpec change comes first.

Priority order for next steps: unblock anything red first; then verify and
archive work that is already code-complete; then finish an in-progress spec; then
reconcile a stale spec or roadmap; and only then start new work promoted from a
backlog item.

## Installing into a new project

1. Copy this `sync/` folder into the project's `.claude/skills/`.
2. Copy `sync.config.example.json` to `.claude/sync.config.json` and fill in the
   identifiers, enabling only the integrations that project uses.
3. Keep `.claude/sync.config.json` in the project repo; updating the skill later
   never touches it.
4. `/sync` reads `.claude/skills/simple/SKILL.md` for its output format — install
   the `simple` skill alongside it.
