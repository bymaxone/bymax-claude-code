# Attribution — ui-ux-pro-max

The contents of this folder are vendored from the **ui-ux-pro-max** Claude Code skill:

- **Project**: ui-ux-pro-max-skill
- **Author**: nextlevelbuilder
- **Repository**: <https://github.com/nextlevelbuilder/ui-ux-pro-max-skill>
- **Website**: <https://ui-ux-pro-max-skill.nextlevelbuilder.io/>
- **License**: MIT (see [`LICENSE`](./LICENSE) — copy of upstream license preserved)
- **Version vendored**: snapshot taken on 2026-04-25

> ⚠️ **This snapshot is stale.** Upstream is at **v2.11.0** (84 styles, 192 palettes,
> 74 font pairings, 22 stacks) as of 2026-07-25. This folder exists for the author's
> machine-restore flow only — **do not treat it as the current version**. Install from
> upstream (below) to get the maintainer's latest.

## Why this is here

It's bundled in this repo as part of the author's **personal backup** — it's symlinked back into `~/.claude/skills/ui-ux-pro-max/` by [`scripts/install.sh`](../../scripts/install.sh) when restoring on a new Mac.

It is **NOT** listed in [`.claude-plugin/marketplace.json`](../../.claude-plugin/marketplace.json) and **cannot** be installed via `/plugin install` from this repo. Anyone who wants this skill should install it directly from the upstream maintainer:

```bash
claude plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill
claude plugin install ui-ux-pro-max@ui-ux-pro-max-skill
```

The suffix matters: the marketplace is named `ui-ux-pro-max-skill` (after the repo),
while the plugin inside it is `ui-ux-pro-max`. Installing `@ui-ux-pro-max` fails.

(Or follow the upstream README for the latest install command.)

## What this skill does

Design intelligence for Claude Code. Bundles:

- 67 styles (glassmorphism, claymorphism, brutalism, neumorphism, bento grid, etc.)
- 96 color palettes
- 57 font pairings
- 25 chart types
- 99 UX guidelines
- 96 product types
- 13 stacks (React, Next.js, Astro, Vue, Nuxt.js, Nuxt UI, Svelte, SwiftUI, React Native, Flutter, Jetpack Compose, Tailwind/HTML, shadcn/ui)

Counts describe this vendored snapshot — verified against the CSVs in `data/`.
Upstream has moved on since; see the staleness warning at the top of this file.

The skill auto-activates on UI/frontend tasks and recommends a complete design system based on product type and requirements.

## How to update from upstream

```bash
# Clone fresh upstream
git clone https://github.com/nextlevelbuilder/ui-ux-pro-max-skill /tmp/uiux

# Copy the skill content
rm -rf vendor/ui-ux-pro-max
mkdir -p vendor/ui-ux-pro-max
cp -r /tmp/uiux/.claude/skills/ui-ux-pro-max/* vendor/ui-ux-pro-max/

# Update LICENSE if upstream changed it
cp /tmp/uiux/LICENSE vendor/ui-ux-pro-max/LICENSE
```

---

If you are the author of ui-ux-pro-max and prefer this content not be vendored here, please [open an issue](https://github.com/bymaxone/bymax-claude-code/issues) — we'll remove it promptly.
