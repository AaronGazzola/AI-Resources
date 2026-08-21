---
name: tasks
description: List the open work for this repo's project, taking a Linear ticket, an OpenSpec change, or the pair of them as one task, grouped code complete then in progress then todo then backlog, categorised inside each group and ordered most to least pressing. Stops without a list if the Linear MCP is not connected or the project for this repo cannot be confirmed. Invoke with /tasks.
---

# /tasks — the open work, grouped and ordered

Read the open tickets in Linear and the OpenSpec changes in the repo, treat them
as one body of work, and print an ordered list of what is open. Nothing is
written anywhere: no ticket is created, moved, commented on or closed, no spec
file is edited, and no branch is created. This skill only reads.

The list answers one question: *what is open, how far along is it, and what
should be picked up first?* Every line earns its place by helping the user
choose. A line that only proves a ticket exists is not enough on its own.

## What counts as a task

A task is a piece of work, not a record of one. Its record may be a Linear
ticket, an OpenSpec change, or both.

- **Both** is the usual case, and the ideal one. One task, one line, carrying the
  ticket identifier and the change id together.
- **A ticket with no change** is a task. Most of the backlog is this.
- **A change with no ticket** is equally a task, listed exactly like the others
  and identified by its change id. An active change is work in flight whether or
  not anybody made a ticket for it, and leaving it out of the list is how it gets
  forgotten.

Never report a change as missing from the list and then omit it. The absence of
a ticket is a note on the line, not a reason to demote the work to a footnote.

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

Pull the description of every `started` issue, of every issue matched to a
change, and of any issue whose title is too vague to describe in one clause. Do
not pull every description in the backlog; the title plus labels is enough for a
backlog line.

### OpenSpec — `openspec.enabled`

```bash
npx openspec list
```

For each active change, read `openspec/changes/<id>/tasks.md`, and `proposal.md`
where the change id alone does not say what the work is.

- Count checked and total task boxes.
- Note the single next unchecked task, in the user's terms rather than the file's.
- Read the text of each unchecked box, not just the count. A box annotated in the
  file as not done, deferred, or impossible without something outside the code is
  not remaining work; it is a governance loose end, and it goes to **Open items**.
- Spot-check the code behind any change that reports itself complete or nearly
  complete: open one or two files named in its last tasks and confirm the work
  exists. A checked box over code that does not exist, and an unchecked box over
  code that does, are both drift, and both go to **Open items**.

Read `openspec/changes/archive/` only to resolve a ticket that claims a change
which is no longer active.

### Git — cheap context only

```bash
git branch -a --sort=-committerdate --format='%(refname:short) %(committerdate:short)'
```

Used for one thing: deciding whether a task has code started against it. A branch
named for a change id, or a ticket identifier in recent commit subjects, counts
as started even where the ticket sits in Todo.

## 3. Pair tickets with changes

Pair in this order, and stop at the first pairing that holds:

1. The ticket names the change id, or the change's `proposal.md` names the ticket
   identifier.
2. A branch exists named for the change id, and its commits name the ticket.
3. The ticket and the change describe the same work, judged by reading both.

A judged pairing is marked as such on the line, because a wrong pairing sends the
user to the wrong file. Where a pairing is uncertain, say so in three words
rather than asserting it.

Beware a change that names a ticket only to defer something into it. A ticket
holding what a change explicitly excludes is not that change's ticket, and the
line says which relation applies.

Anything left unpaired on either side stays in the list as a task in its own
right. Unpaired is a note, never a reason to omit.

## 4. Group

Four groups, in this order. **Code complete** is the new top group and outranks
whatever state the ticket happens to sit in.

- **Code complete** — every task whose code is finished but whose change is not
  archived, or whose ticket is not closed. A change with all boxes checked
  belongs here, and so does one whose only unchecked boxes are the validate step
  and work that cannot be done in code.
- **In progress** — state type `started`, which includes In Review and any
  renamed equivalent.
- **Todo** — state type `unstarted`.
- **Backlog** — state types `backlog` and `triage`.

Where a task has both records and they disagree, **the more advanced of the two
decides the group**, and the line says the other is behind. A written change at 0
of N against a ticket still in Backlog is Todo, and the line notes the ticket has
not been moved.

Where a task has only a change, the change decides: every box checked is Code
complete, some boxes checked is In progress, no boxes checked is Todo.

## 5. Categorise inside a group

Inside each group, tasks sit under a category parent. Use only these categories,
in this order, and **omit any category with no tasks in it**:

- **Security** — a hole, a bypassed authorization boundary, an exposed secret or
  an exposed personal detail.
- **Bugs** — behaviour already wrong in shipped code, data loss included.
- **Foundations** — work that other listed tasks cannot start without.
- **Operations** — installing, migrating, backfilling or repairing something that
  runs, where no feature code is written.
- **Features** — new behaviour.
- **Verification** — confirming behaviour that already exists, usually on a real
  broadcast or against production.

A task belongs to exactly one category. Where two fit, the earlier category in
the list wins, because that is the more pressing reading of the same work.

An empty category is omitted, and so is an entire empty group. Nothing is ever
reported as empty: no section title is printed over a line saying it holds
nothing, and no group is announced in order to say it is quiet. A group the
reader cannot see is a group with nothing in it, and that reads faster than a
sentence saying so.

## 6. Order

Order the categories as listed above. Inside a category, order by the first rule
that applies:

1. **Live harm** — a security hole, a data-loss risk, or a bug affecting
   production or a running broadcast.
2. **Blocks other listed work** — the foundation a later task in this list cannot
   start without. Where two block, the one blocking more of the list goes higher.
3. **Priority** — Linear's Urgent above High above Medium above Low.
4. **Nearly finished** — a change with most of its boxes checked, ahead of one
   barely begun, because closing it frees the branch and the spec.
5. **Everything else** — order by judgement, and be willing to defend the choice.

Judgement overrides the ladder where the ladder is obviously wrong, and the
override is stated on the line in a few words.

## 7. Report

### A task is two levels

One top-level bullet naming the task and saying what it is, then nested bullets
carrying every detail. Nothing sits on the top line except the name and the
sentence.

**The top line** is the identifiers, a colon, and one sentence of plain words.

- The identifiers are the ticket, the change id, or both joined by a slash.
- The sentence says what would change if the work were done. It describes the
  work, rather than repeating a title that names a feature without saying what
  it does.
- The sentence stands alone. A reader who stops after it knows what the task is.
- Nothing else goes here. No count, no caveat, no "not started", no reason for
  its placement.

**The nested bullets** carry one fact each, in this order, and only where they
apply:

- Progress: what exists in code and what does not, with the change's
  checked-of-total count where a change is paired. "Not started" where nothing
  exists.
- The closing check, for a **Code complete** task, written as described below.
- What the task blocks, naming the blocked tasks.
- Anything that would otherwise surprise the reader: a ticket left in a state
  that contradicts its change, a pairing that was judged rather than declared, a
  placement that needs its reason given.

Keep every bullet to one line. A bullet needing a second clause is two bullets.
Never nest a third level under a task.

### Shape

- **Security:**
  - **AZ-272**: Stop user-facing Server Actions from running with the key that
    bypasses row-level security.
    - Roughly 170 call sites are affected, so authorization currently rests on
      hand-written checks rather than on database policy.
    - Not started.
- **Features:**
  - **AZ-275 / `add-chatters-panel`**: Add a standing list of who is in the
    broadcast, with each person's figures and recall notes, for the second
    monitor beside OBS.
    - Spec at 0 of 24, fully written and ready to build.
    - The ticket has not been moved off Backlog.

Rejected:

- A top line carrying a count, a progress clause or a caveat. Those are nested.
- "**AZ-171**: Fix worker bug." Names nothing specific.
- A category parent with nothing under it.
- A line carrying labels, dates, assignee, priority number or a URL.

### Name a thing and say what it is, every time

The reader is scanning a list, not holding the project in their head. An
identifier they have to look up, or a word only this codebase uses, stops them.

- **Never name a ticket, a change or a numbered task by its identifier alone.**
  Every reference carries what it is, in a few words in parentheses: "AZ-277
  (adding test seams to the command path)", "task 4.1 (the charge-order test)".
- **Never use an internal term without saying what it means in the same
  sentence.** Words like seam, sink, ladder, rung, settle and phase are jargon to
  a reader coming back after a week. Either say the plain thing, or say the term
  and then what it means.
- **Say what the reader would do about it**, not only what is true. Where
  something needs checking, name the command to run or the screen to look at.
- **Say whether something is actually done.** "Marked not done" and "not done"
  are different claims, and a reader cannot act until the line says which.

### Code complete names its closing check

Every task in the **Code complete** group carries a nested bullet the other
groups do not: **what has to pass before the change is archived and the ticket
closed.** Without it the group is a list of things nobody knows how to finish.

Name the actual check, never "verify it works":

- A test file or command to run, written exactly as it would be typed.
- An app check, named as the screen and the thing to look for.
- An on-stream or production confirmation, named as the moment to watch.
- The validate-and-archive step, where it is genuinely all that remains.

Where the closing check cannot be done in code, say which ticket holds it, and
where no ticket holds it, say a ticket is needed. Governance says non-code work
leaves the change, and this group is where that gets noticed.

### Sections

Use only these, in this order. **Omit any section with nothing in it**, without
comment.

- **Code complete** — finished code awaiting its closing check.
- **In progress**
- **Todo**
- **Backlog** — at most 12 tasks in total across its categories. Where more
  exist, cut the least pressing and end the section with one line giving the
  number not shown.
- **Open items** — at most 4 inconsistencies between Linear, OpenSpec and the
  code that no task above already resolves.

Close with a single line offering the detail held in context. That line is not a
section and carries no bullet.

### Open items, answer first

This section is where a reader gets confused, because each item is a small
process fault with a history. Write it as a Minto pyramid: **the top line is the
conclusion and what to do about it**, and the nested bullets exist only to
support that.

- The top line states what is wrong or what is owed, in plain words, and it is
  true on its own.
- Nested bullets carry, in this order and only where they apply: what is actually
  the case in the code, why it ended up that way, and the exact thing to run,
  look at or decide.
- The reader must never have to ask "is this done or not?" after reading it. Say
  which.
- Every identifier in this section carries what it is, by the rule above. This
  section breaks that rule more than any other, so check it twice.

What belongs here: a ticket naming a change that is archived or absent, an
unchecked box over code that already exists, a box that cannot be finished in
code and is still sitting in an active change, two tickets claiming the same
work, a ticket whose title says shipped while it sits open.

A change with no ticket is **not** an open item. It is a task, and it is listed
as one.

Worked item:

- **The credit-spending change is finished and can be archived, once its one
  unwritable test is moved to a ticket.**
  - The feature works: a priced command charges credits once, after the enabled,
    cooldown and per-stream-limit checks and before the command runs.
  - The unchecked box asks for a unit test proving a refused command charges
    nothing, and that test cannot be written, because the whole decision happens
    inside one function that reads the database at every step with no place to
    substitute a fake.
  - Confirm it by hand instead: run `!tts` twice in a preview session and check
    the balance in `!me` moves once, not twice.
  - Then remove the box, run `openspec validate --strict`, and archive.

### Format

Follow the `/simple` format: read `.claude/skills/simple/SKILL.md` and apply it,
with the exceptions below.

- Bold one-line section titles that are not themselves list items.
- Category parents are bold and end with a colon.
- Bulleted facts only: no prose paragraphs, no numbered lists, no tables.
- Passive voice, no pronouns as standing subjects, one fact per bullet.
- No em-dashes; dates, where one is unavoidable, written as D-Mon-YYYY.

Four rules of `/simple` are overridden here:

- Ticket identifiers and OpenSpec change ids are required, because the user opens
  them.
- The list is an enumeration by design, and is not collapsed into a synthesis.
- Category parents are labels, which `/simple` forbids. The category does
  structural work, and the meaning sits on the task lines beneath it.
- There is no opening answer line above the first section. The first group is the
  answer.

## Installing into a new project

1. Copy this `tasks/` folder into the project's `.claude/skills/`.
2. Ensure `.claude/sync.config.json` exists with the `linear` integration enabled
   and its team and project filled in; `/tasks` and `/sync` share it.
3. Install the `simple` skill alongside it, since the output format is read from
   `.claude/skills/simple/SKILL.md`.
