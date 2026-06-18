# Attribution — ui-ux-pro-max

The contents of this folder are vendored from the **ui-ux-pro-max** Claude Code skill:

- **Project**: ui-ux-pro-max-skill
- **Author**: nextlevelbuilder
- **Repository**: <https://github.com/nextlevelbuilder/ui-ux-pro-max-skill>
- **Website**: <https://ui-ux-pro-max-skill.nextlevelbuilder.io/>
- **License**: MIT (see [`LICENSE`](./LICENSE) — copy of upstream license preserved)
- **Version vendored**: snapshot taken on 2026-04-25

## Why this is here

It's bundled in this repo as part of the author's **personal backup** — it's symlinked back into `~/.claude/skills/ui-ux-pro-max/` by [`scripts/install.sh`](../../scripts/install.sh) when restoring on a new Mac.

It is **NOT** listed in [`.claude-plugin/marketplace.json`](../../.claude-plugin/marketplace.json) and **cannot** be installed via `/plugin install` from this repo. Anyone who wants this skill should install it directly from the upstream maintainer:

```bash
claude plugin install ui-ux-pro-max@ui-ux-pro-max
```

(Or follow the upstream README for the latest install command.)

## What this skill does

Design intelligence for Claude Code. Bundles:

- 50+ styles (glassmorphism, claymorphism, brutalism, neumorphism, bento grid, etc.)
- 161 color palettes
- 57 font pairings
- 25 chart types
- 99 UX guidelines
- 161 product types
- 10 stacks (React, Next.js, Vue, Svelte, SwiftUI, React Native, Flutter, Tailwind, shadcn/ui, HTML/CSS)

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
