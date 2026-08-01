---
name: simple
description: Reformat the answer (or the referenced/previous content) into very short, jargon-free, passive-voice nested bullet points. Invoke with /simple.
---

# /simple — plain-words fact list

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

## Language

- Use no technical jargon.
  - Replace every term that assumes specialist knowledge with everyday words.
  - Where a term has no everyday equivalent, describe what the thing does instead of naming it.
- Do not name files, folders, functions, variables, settings, commands, or tools.
  - Describe the thing by its effect instead (for example, "the page that lists the videos").
  - Do not put anything in backticks or code formatting.
- Write every fact in the passive voice.
  - Example: "the video is uploaded", not "the system uploads the video".
  - Name the actor only when the fact is meaningless without it.
- Keep every bullet very short.
  - Aim for under ten words.
  - State one fact per bullet.
  - Use no subordinate clauses: start a new bullet instead.
- Never trade accuracy for shortness.
  - Keep exact amounts, times, and names of real-world things.
  - Keep the exact outcome, even where extra words are needed.
  - A shorter bullet that is vaguer is wrong.
- Be specific and factual.
- Do not ask questions.
- Do not add recommendations or opinions unless explicitly requested.

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
