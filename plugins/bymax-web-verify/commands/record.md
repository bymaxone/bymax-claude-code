---
description: 'Record a UI flow as a video artifact for human reviewers — a ticket or PR reviewer asking "can I see it work", a multi-step flow where screenshots cannot show the interaction, a demo for a manager. Drives the flow with the project''s own Playwright setup, forces video on for just that run (test.use, no config edits), slows actions to human-followable pacing (slowMo 1000-1500ms with the timeout resized to match), then post-processes: trims the blank first-paint lead-in and verifies the first frame, gates pacing with ffprobe, and lands the file in the project''s artifact convention with a plain-text step-by-step walkthrough derived from the spec that actually ran. Optional: --mp4 (universally previewable H.264 copy), --headed (watch live), --keep-spec (keep a throwaway spec as permanent coverage). Complements /bymax-web-verify:verify (screenshots) — one extra artifact, not a replacement. Triggers: "record a video of this flow", "video evidence", "record the flow", "gravar um video do fluxo", "video do teste", "/bymax-web-verify:record".'
argument-hint: "[flow-description] [--mp4] [--headed] [--keep-spec]"
---

# /bymax-web-verify:record — record a UI flow as reviewable video evidence

Screenshot tools cannot show *interaction* — a reviewer watching a multi-step flow
needs to see each click land. Playwright can record video; this command uses the
**project's own Playwright setup**, forces recording on for a single run, and turns
the raw capture into something a human can actually follow. The deliverable is
three things together: the video, the walkthrough text (Step 7), and a PASS/FAIL
report — a silent screen recording alone is not a deliverable.

**When NOT to use:** the flow is trivial to screenshot (use
`/bymax-web-verify:verify`); the change is API-only (no UI to film); the project
has no Playwright and adding it is out of scope — say so and stop, never bolt a
new E2E stack onto a repo to produce one video.

## Step 0 — Discover the project's setup (read, don't assume)

1. **Playwright config** — find `playwright.config.(ts|js|mjs)`. Read from it:
   `testDir` (where specs live), `outputDir` (scratch for artifacts), the current
   `video` setting, and the `projects` list — specifically whether a `setup`
   project injects `storageState` (stored authentication). No config → report
   what is missing and stop.
2. **Dev servers** — same discovery as `/bymax-web-verify:test`: map the layout
   (single app or monorepo), read each `package.json` for the dev script, note
   ports from `.env`/config. If the config has a `webServer` block, Playwright
   manages the server itself — skip Step 1 entirely.
3. **Artifact convention** — where does this repo keep review evidence? Reuse an
   existing tracked `artifacts/`-style directory and its naming if one exists;
   otherwise default to `artifacts/<YYYY-MM-DD>-<flow-slug>/`.
4. **Tooling** — `ffmpeg`/`ffprobe` on PATH? Without them Step 5's trim and pacing
   gate degrade (publish raw, with a warning and the install hint) — say so up
   front, not after recording.
5. **The flow** — from the arguments if given, else from conversation context,
   `git diff --stat`, or the ticket's acceptance criteria. Write the golden-path
   steps as a numbered list *before* touching anything — it becomes the test
   plan and the Step 7 narration.

## Step 1 — Servers (only when the config has no `webServer`)

Follow the project's own dev-server rules (CLAUDE.md / AGENTS.md) if stated.
Otherwise, the same lifecycle as `/bymax-web-verify:test`: probe the discovered
port first — a **healthy listener is reused**, never killed (it may be the
user's own server); an unhealthy or unidentified listener is reported and the
user decides — this command never terminates a process it did not start. Only
on a free port: launch the discovered dev script(s) with
`run_in_background: true` and poll readiness with a capped loop — never a blind
sleep. Step 6 kills exactly the processes this command started, nothing else.

## Step 2 — Locate or create the spec

1. Search `<testDir>` for a spec already covering the flow. **Never edit an
   existing spec in place for a recording** — the `test.use` video/`slowMo`
   overrides, the raised timeout and the final hold are recording-only edits
   that would otherwise be left behind, permanently slowing that test. Copy the
   spec into `.record-tmp/<run-id>/` (fixing relative imports for the new
   depth), apply
   the recording overrides to the copy, and delete it in Step 6 like any other
   throwaway. The original stays byte-identical.
2. If none exists, decide the spec's fate **now**:
   - **Throwaway** (evidence only) → write it under `<testDir>/.record-tmp/<run-id>/<slug>.spec.ts`
     — a per-run directory, so overlapping recording sessions cannot delete each
     other's specs — removed in Step 6.
   - **Permanent coverage** (`--keep-spec`, or the flow verifies a new feature
     that deserves regression coverage) → write the **clean** spec at its real
     location, obeying the project's E2E conventions (fixtures/seeds committed
     alongside — check the repo's own rules; "it's just for the video" is not an
     exemption) — then record from a `.record-tmp/<run-id>/` copy exactly as in
     item 1. The permanent spec never carries recording overrides.
3. Force video and human pacing **in the temp copy only** — whatever the spec's
   origin, the overrides live and die with `.record-tmp/<run-id>/`; no config
   edits, no permanent spec touched:

   ```ts
   import { test, expect } from '@playwright/test';
   test.use({ video: 'on', launchOptions: { slowMo: 1500 } });

   test('...', async ({ page }) => {
     test.setTimeout(180_000); // slowMo is real wall-clock per action — the default 30s dies fast
     ...
     await page.waitForTimeout(2000); // hold the final state so the ending isn't cut mid-read
   });
   ```

   `slowMo` inserts a real pause after every action, so the recording shows each
   click and fill landing instead of jump-cutting between static states.
   **1000–1500 ms** is the range a non-technical viewer can follow; 300–500 ms
   still reads as "too fast" once someone tries to track individual form fields.
   Size `test.setTimeout` to the step count — `slowMo` time is added to every
   single action.
4. **Authentication:** reuse the stored session when the config's `setup` project
   provides `storageState` — never re-implement login. When the flow *is* login,
   take credentials from the project's env/helpers; never reconstruct them
   through shell interpolation (`grep`/`cut`/`$(...)`) — test passwords may carry
   shell metacharacters that corrupt silently in a round-trip.
5. **Click-only navigation:** the only direct `page.goto()` is the flow's true
   entry point. Every other screen is reached by clicking, as a user would. If no
   clickable path exists to a required screen, stop and record it as a gap — a
   `goto()` around it would hide an unreachable feature and defeat the evidence.
6. **`waitForURL` needs a trailing `**`.** Pages that sync tabs/filters into the
   query string on load make `page.waitForURL('**/orders')` wait forever — the
   URL stops literally ending in `/orders` faster than a `slowMo` run can catch
   it, while an un-slowed run may race past and pass. The bug therefore *appears*
   when you add `slowMo` and reads as a `slowMo` problem; it is not. Always
   `page.waitForURL('**/orders**')` (or match on pathname) for any route that
   might append query params.

## Step 3 — Run it, isolated per run

```bash
npx playwright test <spec-path> --project=<project> --output <scratch>/record-run-<timestamp> --reporter=list
```

`--output` gives every recording its own directory, so a second run can never
delete the first run's video (Playwright clears its output directory at the start
of each invocation — with a shared one, back-to-back recordings silently destroy
each other). Add `--headed` only when the user asked to watch; headless records
identically. **Confirm the assertions passed** — a failed run still produces a
video, but that video documents a bug, not a verification. Report it as exactly
that and stop the publishing path.

## Step 4 — Recover the video

```bash
find <scratch>/record-run-<timestamp> -iname '*.webm'
```

Copy it out to your scratchpad immediately anyway (belt and braces — scratch
directories are cheap, re-recording a flow is not), then post-process the copy.

## Step 5 — Post-process before publishing

Requires `ffmpeg`/`ffprobe` (Step 0.4). Without them: publish the raw `.webm`,
state plainly that the lead-in trim and pacing check were skipped and why, and
include the install hint (`brew install ffmpeg` / distro equivalent).

1. **Trim the blank lead-in.** Recording starts when the browser page is created —
   before the first `goto()`, before first paint — so recordings open on ~1–1.5 s
   of blank page, which a correctly slowed video turns into conspicuous dead air:

   ```bash
   ffmpeg -y -ss 1.5 -i raw.webm -c:v libvpx -b:v 1M -crf 10 trimmed.webm
   ```

2. **Verify the trim** — never trust the cut blind:

   ```bash
   ffmpeg -y -i trimmed.webm -update 1 -vframes 1 first-frame.png
   ```

   First frame still blank → raise `-ss` a little; content already cut off →
   lower it. First paint varies a few hundred ms run to run.
3. **Gate the pacing:** `ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1 trimmed.webm`.
   A multi-step flow under ~15–20 s is still too fast for a human reviewer —
   raise `slowMo` and **re-record**; that is the fix. Stretching
   (`-filter:v "setpts=4.0*PTS"`) only holds static frames longer — a fallback
   when re-recording is impractical, never the preferred path, and always
   applied *after* the trim (stretching the lead-in turns a sub-second blank
   into seconds of dead air).
4. **`--mp4` (optional):** `.webm` does not preview inline everywhere reviewers
   live (issue trackers, chat clients). When asked:

   ```bash
   ffmpeg -y -i trimmed.webm -c:v libx264 -pix_fmt yuv420p flow.mp4
   ```

Copy (don't move) the final file into the Step 0.3 artifact location, named
`<ticket-or-slug>-<flow-description>.<ext>`.

## Step 6 — Report and clean up

- Per-step status **read from the runner, never inferred**: wrap each golden-path
  step in `test.step('<n>. <description>', …)` when writing the spec, so the
  reporter names every step it executed. A step the runner never reached is
  reported **NOT RUN** — a mid-flow failure proves nothing about later steps,
  and inventing their status is worse than omitting it. Then: navigation gaps
  found, and the artifact path.
- Delete this run's `<testDir>/.record-tmp/<run-id>/` — only this run's, never
  the whole `.record-tmp/`, which may hold a concurrent recording's spec. If
  permanent,
  confirm its fixtures/seeds are staged alongside it.
- Kill any dev servers Step 1 started.
- **Never commit from this command** — the artifact directory may be tracked, and
  committing is the user's decision, always.

## Step 7 — The companion walkthrough (always)

A video with no caption is unusable — the viewer cannot tell what to watch for.
Every run ends with a **plain-text, English, condensed step-by-step** the user can
paste next to the video. It narrates the *footage*, not the report:

- **The text is the recording, step for step** — derived from the spec that
  actually ran, in execution order, using the literal values typed and the
  literal strings asserted on screen. A step cut from the spec goes in a final
  "not in this video" line, never in the numbered list.
- Plain text in the chat reply — no artifact, no file, no code fences (the user
  copies it straight out of the terminal). English regardless of conversation
  language.
- First line: ticket/slug, environment recorded, filename, duration.
- **Identify signed-in users by ROLE, never by email/username** — "sign in as the
  admin account", not the address. The role tells the reader whether behaviour is
  permission-dependent; the address is a credential that would end up pasted into
  chat and tickets. Same for every identity the flow touches.
- Numbered steps, one short line each, matching the video 1:1: what is
  clicked/typed, then what appears — on-screen strings verbatim so the viewer can
  match text to frame.
- Close with notes: anything deliberately left out, and any test data the run
  wrote that needs cleaning up.

Keep it under a screen — it is a caption, not a manual.

## Common mistakes

| Mistake | Consequence |
|---|---|
| Forgetting `test.use({ video: 'on' })` | Silently no video — most configs keep video off locally. |
| `slowMo` skipped or too low (300–500 ms) | Recording too fast for the audience — gate with `ffprobe` before publishing; aim 1000–1500 ms. |
| `slowMo` without raising `test.setTimeout` | The run blows the default 30 s budget mid-flow and fails. |
| Not trimming (and not verifying) the blank lead-in | Ships with dead air up front; a blind `-ss` cut can also decapitate real content — pull the first frame and look. |
| Sharing one output directory across runs | Playwright wipes it per invocation — the previous video is deleted even though its test passed. Use `--output` per run. |
| Bare `waitForURL('**/page')` on a query-param route | Hangs under `slowMo`, may race-pass without it — reads as a `slowMo` bug and isn't. Trailing `**`. |
| `page.goto()` straight to the target screen | An unreachable-by-click feature passes anyway — the evidence lies. |
| Publishing a video from a failed run as verification | The video documents a bug. Say so; don't publish it as proof of working behaviour. |
| Handing over the video without the Step 7 walkthrough | The reviewer gets a silent recording and no idea what to look for. |
| Walkthrough written from the plan instead of the spec that ran | Lists steps the footage doesn't contain; the reader loses sync in seconds. |
| Naming test accounts by email instead of role | Leaks a credential into chat/tickets and tells the reader nothing. |
| Bolting Playwright onto a project that doesn't have it | Out of scope for producing one video — report the gap instead. |
| Editing an existing spec in place to force video/`slowMo` | The recording-only overrides outlive the recording — that test stays slowed and video-enabled for every future run. Record from a `.record-tmp/<run-id>/` copy. |
