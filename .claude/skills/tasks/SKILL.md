---
name: tasks
description: List the open Linear tickets for this repo's project, grouped in progress then todo then backlog, each ordered most to least pressing, with the matching OpenSpec change and its real progress against the code. Stops without a list if the Linear MCP is not connected or the project for this repo cannot be confirmed. Invoke with /tasks.
---

# /tasks — the open work, grouped and ordered

Read the open tickets in Linear and the OpenSpec changes in the repo, match them
to each other, and print one ordered list of what is open. Nothing is written
anywhere: no ticket is created, moved, commented on or closed, no spec file is
edited, and no branch is created. This skill only reads.

The list answers one question: *what is open, how far along is it, and what
should be picked up first?* Every line earns its place by helping the user
choose. A line that only proves a ticket exists is not enough on its own.

## 0. Load config

Read `.claude/sync.config.json` at the repo root, the same file `/sync` uses.

- `integrations.linear.workspace`, `.team` and `.project` name the one project
  this repo maps to.
- `integrations.openspec.enabled` decides whether specs are read at all.

Where the file does not exist, or `integrations.linear.enabled` is not `true`,
**stop**. Say the skill is not configured for this project, name the file that is
missing or the flag that is off, and offer to scaffold it from the `/sync`
skill's `sync.config.example.json`. Do not guess a team or project name from the
repository name, the git remote, or a ticket identifier seen elsewhere in the
conversation.

## 1. Access gate — confirm the project, or stop

The whole point of this gate is that a list built from the wrong project is
worse than no list. Run all four checks before anything is gathered, and stop at
the first one that fails.

| Check | Call | Stop when |
| --- | --- | --- |
| Linear reachable | `list_teams` | the call errors, or the MCP server is not connected |
| Team exists | `list_teams` | no team matches `linear.team` |
| Project exists | `list_projects` scoped to that team | no project matches `linear.project` |
| Project is unambiguous | same result | more than one project matches the name |

On any stop, print a single short block and nothing else:

- What failed, in one line, naming the team or project that could not be
  confirmed.
- The one action that fixes it, done by the user:
  - Not connected → connect the Linear MCP server with `/mcp` in an interactive
    session.
  - Team or project not found → correct `linear.team` / `linear.project` in
    `.claude/sync.config.json`, or say which project this repo maps to.
  - Ambiguous → name which of the matching projects is the right one.

**Never produce a partial list.** Do not fall back to an unscoped `list_issues`,
do not substitute a team-wide query for a project-scoped one, and do not build
the list from OpenSpec alone when Linear is unreachable. The absence of the list
is the signal.

This skill cannot authorize anything itself. Do not ask the user for a token, an
API key, an authorization code or a callback URL, and do not attempt an OAuth
flow.

## 2. Gather

Run the reads in parallel.

### Linear — scoped to the confirmed project

`list_issues` for the confirmed team and project, for every state whose type is
`started`, `unstarted`, `backlog` or `triage`. Do not filter by state name:
workspaces rename these, and a renamed state silently vanishing from the list is
exactly the failure this avoids. Call `list_issue_statuses` for the team and map
each returned state to its type.

Capture per issue: identifier, title, state and state type, priority, labels,
assignee presence, whether the description or a comment names an OpenSpec change
or a branch, and whether the issue names another issue as a blocker or a parent.

Pull the description of every `started` issue, and of any issue whose title is
too vague to describe in one clause. Do not pull every description in the
backlog; the title plus labels is enough for a backlog line.

### OpenSpec — `openspec.enabled`

```bash
npx openspec list
```

For each active change, read `openspec/changes/<id>/tasks.md`, and `proposal.md`
where the change id alone does not say what the work is.

- Count checked and total task boxes.
- Note the single next unchecked task, in the user's terms rather than the file's.
- Spot-check the code for any change that maps to a `started` ticket: open one or
  two files named in the first unchecked task and confirm the work really is
  outstanding. A box left unchecked over code that already exists is drift, and
  it is reported under **Mismatches**, never silently counted as remaining work.

Read `openspec/changes/archive/` only to resolve a ticket that claims a change
which is no longer active.

### Git — cheap context only

```bash
git branch -a --sort=-committerdate --format='%(refname:short) %(committerdate:short)'
```

Used for one thing: deciding whether a ticket has code started against it. A
branch named for a change id, or a ticket identifier in recent commit subjects,
counts as started even where the ticket sits in Todo.

## 3. Match tickets to specs

Match in this order, and stop at the first match that holds:

1. The ticket names the change id, or the change's `proposal.md` names the ticket
   identifier.
2. A branch exists named for the change id, and its commits name the ticket.
3. The ticket and the change describe the same work, judged by reading both.

A judged match is marked as such on the line, because a wrong match sends the
user to the wrong file. Where a match is uncertain, say so in three words rather
than asserting it.

Everything unmatched on either side is a mismatch, and is reported in its own
short section rather than being padded into the list.

## 4. Order

Group first, then order inside each group. Groups run: **In progress** (state
type `started`, which includes In Review and any renamed equivalent), then
**Todo** (`unstarted`), then **Backlog** (`backlog` and `triage`).

Inside a group, order by the first rule that applies:

1. **Live harm** — a security hole, a data-loss risk, or a bug affecting
   production or a running broadcast.
2. **Blocks other listed work** — the foundation a later ticket in this list
   cannot start without. Where two foundational tickets exist, the one blocking
   more of the list goes higher.
3. **Priority** — Linear's Urgent above High above Medium above Low.
4. **Nearly finished** — a change with most of its boxes checked, ahead of one
   barely begun, because closing it frees the branch and the spec.
5. **Everything else** — order by judgement, and be willing to defend the choice.

Judgement overrides the ladder where the ladder is obviously wrong, and the
override is stated on the line in a few words. A Medium-priority migration that
three High-priority tickets sit on top of goes first, and the line says why.

## 5. Report

### The list

One bullet per ticket. Nothing nested under a ticket except a blocking relation.

Each bullet carries three things, in this order and nothing else:

- The identifier in bold, then what the work actually is, in one clause of plain
  words. Say what the ticket means rather than repeating a title that names a
  feature without describing it.
- The progress, in one clause: what exists in code, and what does not. Where an
  OpenSpec change matches, give the change id and its checked-of-total count.
  Where nothing is started, the progress clause is the single word "not started".
- Where the ticket blocks another on the list, one nested bullet naming what it
  blocks. This is the only nesting allowed.

Give the reason for an unusual placement in three or four words inside the same
bullet, never as its own line.

Worked lines:

- Accepted: "**AZ-124** Overlay stack, one program instead of four browser
  sources. Spec `add-overlay-stack` at 9 of 14; the compositor and the scene
  switch exist, the hotkey layer does not."
- Accepted: "**AZ-171** Broadcast settle runs twice on a restarted worker, double
  charging the ticket. Not started, placed first as a live billing bug."
- Rejected: "**AZ-171** Fix worker bug. In progress." — names nothing specific
  and gives no progress.
- Rejected: a line carrying labels, dates, assignee, priority number or a URL.

### Sections

Use only these, in this order. Omit any with nothing to say.

- **In progress** — every `started` ticket. Where the group is empty, say so in
  one line, because an empty in-progress group is itself the answer.
- **Todo**
- **Backlog** — at most 12 bullets. Where more exist, cut the least pressing and
  end the section with one line giving the number not shown.
- **Mismatches** — at most 4 bullets, each one loose end between Linear and
  OpenSpec: an active change with no ticket, a ticket naming a change that is
  archived or absent, or an unchecked task over code that already exists. Each
  line states what is inconsistent and what closes it.

Close with a single line offering the detail held in context. That line is not a
section and carries no bullet.

### Format

Follow the `/simple` format: read `.claude/skills/simple/SKILL.md` and apply it,
with the exceptions below.

- Bold one-line section titles that are not themselves list items.
- Bulleted facts only: no prose paragraphs, no numbered lists, no tables.
- Passive voice, no pronouns as standing subjects, one ticket per bullet.
- No em-dashes; dates, where one is unavoidable, written as D-Mon-YYYY.

Three rules of `/simple` are overridden here:

- Ticket identifiers and OpenSpec change ids are required on every line, because
  the user opens them.
- The list is an enumeration by design, and is not collapsed into a synthesis.
- There is no opening answer line above the first section. The first group is the
  answer.

## Installing into a new project

1. Copy this `tasks/` folder into the project's `.claude/skills/`.
2. Ensure `.claude/sync.config.json` exists with the `linear` integration enabled
   and its team and project filled in; `/tasks` and `/sync` share it.
3. Install the `simple` skill alongside it, since the output format is read from
   `.claude/skills/simple/SKILL.md`.
