---
name: explain-diff
description: Produce a rich, self-contained HTML explanation of a code change, diff, branch, or PR — with background, intuition, a code walkthrough, and an interactive quiz. Use when the user says "explain this diff", "explain this PR", "explain this branch", "walk me through this change", or "/explain-diff".
user-invocable: true
allowed-tools: Bash(git:*), Bash(gh:*), Read, Grep, Glob, Write
---

# Explain Diff

Build a rich, engaging HTML explanation of a code change so a reader can genuinely understand it — not just skim the diff. The output is one self-contained HTML file the user opens in a browser.

## 1. Resolve what to explain

Figure out the target from the invocation:

- An argument that looks like a PR (URL or number) → `gh pr diff <n>` for the diff and `gh pr view <n>` for title/description.
- An argument that looks like a branch or ref → `git diff <base>...<ref>` (use the merge-base with the default branch as `<base>`).
- No argument → explain the current working change: `git diff HEAD` (include staged with `git diff HEAD`). If that is empty, fall back to the last commit: `git show HEAD`.
- If ambiguous, ask which change to explain rather than guessing.

Read the actual changed files (not just the diff hunks) with Read/Grep so you understand the surrounding system, not only the lines that moved. Trace one level into the functions the change calls or that call it.

## 2. Write the explanation

Write with the clarity and flow of Martin Kleppmann: engaging, in a classic expository style, with smooth transitions between ideas. Explain, don't just enumerate. The reader should come away understanding *why* the change is shaped the way it is.

Structure the page into these sections, each with a header, and put a table of contents at the top that links to them:

- **Background** — Explain the existing system the change touches. Give deep enough background that a newcomer to this codebase can follow, plus the narrower background specifically relevant to this change. Set up the problem before showing the solution.
- **Intuition** — Convey the core idea. Lead with concrete toy-data examples and figures/diagrams before generalizing. This is where the reader should have the "aha."
- **Code** — A high-level walkthrough of the changes, grouped so related edits are explained together rather than file-by-file in diff order. Show the key code, explain what it does and why.
- **Quiz** — Exactly five medium-difficulty multiple-choice questions that check real understanding of the change (not trivia). Each question has clickable options; clicking gives immediate correct/incorrect feedback with a short explanation. The goal is to help the reader confirm they actually understood.

## 3. Diagrams and formatting rules

- **No ASCII diagrams.** Use HTML/CSS designs and lists instead.
- Reuse a small number of diagram *families* rather than inventing a new visual style per figure. Good families: simplified UI mockups, and system/data-flow diagrams that carry concrete example data through them. Consistency helps the reader.
- Use **callout boxes** to highlight key concepts, definitions, and edge cases.
- Code must be in `<pre>` tags. Any custom div that holds code or preformatted text must set `white-space: pre` or `white-space: pre-wrap`, or the whitespace collapses.

## 4. Output

- Produce **one self-contained HTML file**: all CSS and JS inlined, no external dependencies or CDN links. It must open correctly from `file://`.
- Single long scrolling page with section headers and the table of contents. Basic responsive styling so it reads on a laptop or phone.
- The quiz interactivity is plain inline JavaScript (click a choice → mark right/wrong → reveal explanation).
- Save it **outside the repo** in `/tmp`, with a filename that starts with today's date: `/tmp/YYYY-MM-DD-explain-<short-slug>.html` (get the date with `date +%Y-%m-%d`; derive the slug from the PR/branch/change).
- After writing, tell the user the full path and offer to open it (`open <path>` on macOS).
