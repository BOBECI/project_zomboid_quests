# Project setup & workflow

**Companion to PROJECT-OVERVIEW.md · v0.1**

This document describes *how the project is worked on* — where things live, who contributes what, and how we avoid stepping on each other. It does not describe the mod itself; that's the overview doc.

---

## 1. Team

Three people, three different jobs.

| Who | Role | Touches |
|---|---|---|
| Mehmet Ali | Software engineer — owns the entire logic layer | Lua, quest engine, loader, state handling, repo structure, review |
| Friend 2 | Story writer | Quest files only, in plain Markdown |
| Friend 3 | Story writer | Quest files only, in plain Markdown |

**Hard constraint:** the two writers are not developers. They should never need to open a Lua file, and never need to write YAML, JSON, or XML. Anything they touch must look and feel like writing a document. All engine logic is Mehmet Ali's — the writers supply content, nothing else.

## 2. Where the project lives

**GitHub is the source of truth.** Not a shared Claude project — project sharing requires a Team or Enterprise plan, and we don't need it. Instead:

- The repo holds everything: Lua, docs, quest content, templates.
- Each of the three works with their **own** Claude account against the same repo.
- Consistency comes from files committed in the repo, not from a shared workspace.

This is the better arrangement anyway. The repo is versioned, reviewable, and outlives any one tool.

### `CLAUDE.md` at repo root

A `CLAUDE.md` lives at the root so all three of our Claude sessions pick up the same conventions automatically — folder layout, naming rules, how quest data is shaped, house style. Version-controlled alongside the code, so when conventions change, everyone's assistant learns it on the next pull.

*Not yet written — to be drafted when we start the build.*

## 3. Avoiding conflicts

The main risk with three contributors is merge conflicts. The principle that prevents it:

> **One quest = one file. Shared files stay thin.**

- Each quest gets its own file, e.g. `rosewood_water_run.md`. Two people writing two quests never touch the same file, so Git has nothing to fight about.
- The only shared file is a **small registry** listing quest filenames. Short, append-only, rarely edited — conflicts there are trivial to resolve.
- Everything substantive — dialogue, note text, objectives, location — lives inside the quest's own file.

Git conflicts only happen when two people edit the same lines. Structure the content so that can't happen and the problem disappears.

## 4. How writers contribute

Writers work in a `stories/` folder. One Markdown file per quest, filled in from a template.

The template is **plain Markdown with headings** — no syntax that can be broken by a typo. It reads like a form in a normal document:

- Quest name
- Where it happens
- Who the NPC is
- What the note says
- The objective steps
- Dialogue lines

Writers fill in prose under each heading. That's the whole job. No brackets, no indentation rules, no quoting.

On the engineering side, a **loader** parses these Markdown files into the quest data the mod consumes. If a writer makes a mistake, the loader reports it in plain language rather than failing cryptically.

*Template and writer's guide not yet written — to be produced at build time, generated from the quest structure once it's settled, so the fields match what the engine actually needs.*

## 5. Proposed repo layout

Sketch, to be firmed up when the build starts:

```
/
├── CLAUDE.md              conventions for all Claude sessions
├── PROJECT-OVERVIEW.md    what the mod is
├── PROJECT-SETUP.md       this file
├── docs/
│   └── WRITERS-GUIDE.md   how to write a quest file (todo)
├── stories/
│   ├── _TEMPLATE.md       the form writers copy (todo)
│   └── rosewood_*.md      one file per quest
└── mod/
    ├── media/lua/         the actual mod code
    └── ...                Build 42 mod structure
```

## 6. Distribution during development

The mod runs from the local `mods` folder — no Workshop upload needed. For playtesting, everyone needs the files: zip the mod folder and share it, or have the other two pull the repo. Workshop only matters for public release and auto-updates.

## 7. Next steps

1. Create the GitHub repo and push the two docs.
2. Draft `CLAUDE.md` with conventions.
3. Build the technical skeleton with dummy content (see overview, section 5).
4. Once the quest data shape is settled, generate `_TEMPLATE.md` and the writer's guide from it.
5. Hand the template to the writers and start the three Rosewood quests.
