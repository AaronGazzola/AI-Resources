---
name: simple
description: Reformat the answer (or the referenced/previous content) into very short, precise, passive-voice nested bullet points. Invoke with /simple.
---

# /simple — precise fact list

When invoked, present the response as a nested unordered (bulleted) list, following every rule below. If an argument or a previous message is referenced, apply this format to that content; otherwise apply it to the answer being given.

## Structure

- Extract the core facts out of their conceptual/narrative context.
  - Strip framing, transitions, hedging, and commentary.
  - Keep only the facts.
- Use an unordered (bulleted) list for the facts. Do not write prose paragraphs.
  - Never use an ordered (numbered) list, even for steps in a sequence.
  - Put steps in order as ordinary bullets instead.
- Start each section with a one-line title on its own line.
  - The title is not a list item: do not begin a section with a bullet.
  - Format the entire title in bold (the whole line, not select words within it).
  - The bullets beneath the title expand on it.
- Reserve bold titles for top-level, parallel groups. If a group is conceptually part of another titled group, do not give it its own title: make it a labelled top-level list item under the parent, with its facts nested beneath it.
- Nest at most 3 levels deep (child, grandchild, great-grandchild).
- Never pack multiple distinct items into one bullet.
  - If a bullet would list several things in one line, split them into separate nested items.
  - Put them under a child bullet that names the group.
  - Example: instead of "three speeds: slow, medium, fast", write a child bullet "Three speeds:" with three nested items: "Slow", "Medium", "Fast".
  - Split this way even when only two things are listed.

## Precision

Precision outranks brevity and outranks plainness. A bullet that is short but vague is wrong.

- Name the specific thing. Do not describe it in the abstract.
  - Name routes, files, tables, columns, commands, tickets, branches, and functions where they are the subject.
  - Write `/studio/timeline/[streamId]`, not "the timeline page".
  - Write "the `az-206-stream-timeline-backfill` branch has no commits", not "nothing has been saved".
  - Write "AZ-210", not "a ticket about chat timing".
- Use the real term when the real term is exact.
  - Established vocabulary is allowed: commit, branch, migration, index, route, table, column, query, deploy.
  - Product and tool names are allowed: git, Linear, OpenSpec, Supabase, YouTube, Doppler.
  - Backticks are allowed for identifiers, paths, commands, and routes.
- Ban vague filler. Every one of these is a defect:
  - Empty abstractions: "the main line of code", "the system", "the pipeline", "things".
  - Unquantified judgements: "judged good", "works well", "mostly done", "cleaned up".
  - Origin-free phrasing: "created from nothing", "sorted out", "handled".
- Replace a judgement with the evidence behind it.
  - Write "never opened in a browser; needs manual verification", not "not yet judged good".
  - Write "47 unit tests pass; the Playwright spec has never been run", not "tested".
- State what an unfinished item requires, not merely that it is unfinished.
  - Name the blocking action: manual browser check, live stream, owner decision, external key.
- Where a count, size, date, or identifier is known, give it.

## Relevance

- Include a fact only when it bears on the current state or the current change.
- Mention prior versions, deleted code, or earlier attempts only when one of these holds:
  - The old version was used as the basis for the new one.
  - The old version's code was reused.
  - The old version's behaviour constrains the new one.
  - The old version still exists somewhere and must be dealt with.
- Where prior work is mentioned, state which of the above applies.
- Do not report history as context or colour.

## Language

- Write every fact in the passive voice.
  - Example: "the video is uploaded", not "the system uploads the video".
  - Name the actor only when the fact is meaningless without it.
- Keep every bullet short.
  - Aim for under fifteen words.
  - State one fact per bullet.
  - Use no subordinate clauses: start a new bullet instead.
- Explain a term the reader is unlikely to know, in a nested bullet, once.
  - Do not substitute a vaguer word for it.
- Be specific and factual.
- Do not ask questions.
- Do not add recommendations or opinions unless explicitly requested.
  - Where they are requested, mark them as a nested bullet beginning "Recommended:".

## Visual aids

- Default to bulleted lists. Add a visual aid only where it shows the idea better than a list would.
  - Use a diagram for a pathway that splits into branches.
  - Use a table where several things are compared on the same points.
- Render every table as an ASCII table inside a fenced code block. Do not use Markdown pipe-table syntax.
  - Draw the borders with the "+", "-", and "|" characters.
  - Pad each cell so the column borders line up vertically.
- Do not add a visual aid that merely repeats a list.

## Formatting constraints

- Use bold only for the one-line section titles (the whole title line). Do not bold any text inside the bullets.
- Do not use em-dashes.
- Do not use "~" as an "approximately" prefix.
  - Two "~" on the same line render the text between them as strikethrough.
  - Write "about" instead.
- Dates use the format D-Mon-YYYY (for example, 2-Feb-2026).
- State a number inline with its label (for example, "2-Feb-2026: 51"), not as its own nested sub-item.
