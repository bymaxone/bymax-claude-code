# 📦 Vendor

This folder bundles **third-party Claude Code skills** the author uses personally. Both are MIT-licensed and the original `LICENSE` and an `ATTRIBUTION.md` are preserved in each subfolder.

These skills are **NOT** redistributed via the marketplace (they're not listed in `marketplace.json` and `/plugin install` cannot fetch them from here). They live here for two reasons:

1. **Personal backup** — when the author restores `~/.claude/` on a new Mac via [`scripts/install.sh`](../scripts/install.sh), these get symlinked back too.
2. **Discoverability** — readers of this repo can see the original sources and install them properly from the upstream maintainers.

---

## What's in here

### [`ecc-skills/`](./ecc-skills/) — Everything Claude Code

A subset of skills from [Everything Claude Code (ECC)](https://github.com/affaan-m/everything-claude-code) by **Affaan Mustafa**. ECC is an open-source agent harness with **100K+ stars** and 119 skills.

The seven skills bundled here are domain-knowledge skills for backend, frontend, API design, database migrations, postgres patterns, security review, and coding standards.

→ For the full collection, install ECC at <https://github.com/affaan-m/everything-claude-code>.

### [`ui-ux-pro-max/`](./ui-ux-pro-max/) — UI/UX Design Intelligence

A complete UI/UX design intelligence skill from [ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) by **nextlevelbuilder**.

Bundles 50+ styles, 161 color palettes, 57 font pairings, 99 UX guidelines, 25 chart types across 10 stacks (React, Next.js, Vue, Svelte, SwiftUI, React Native, Flutter, Tailwind, shadcn/ui, HTML/CSS).

→ For updates and the canonical version, install at <https://github.com/nextlevelbuilder/ui-ux-pro-max-skill>.

---

## Design skills — fetched from upstream, **not** vendored

A set of third-party **design** skills the author uses are deliberately **not** copied into this folder. Instead, [`scripts/install.sh`](../scripts/install.sh) fetches them from their original repos via the [`skills`](https://www.npmjs.com/package/skills) CLI (`npx skills add … --global`). Two reasons: licensing (Impeccable is Apache-2.0; the Emil skill ships no license file) and freshness (you always get the maintainer's latest version).

| Skill | Author | License | Source |
| ----- | ------ | ------- | ------ |
| [Emil Design Engineering](https://github.com/emilkowalski/skill) | Emil Kowalski | _no license file_ | `emilkowalski/skill` |
| [Impeccable](https://github.com/pbakaus/impeccable) | Paul Bakaus | Apache-2.0 | `pbakaus/impeccable` |
| [Taste-Skill](https://github.com/Leonxlnx/taste-skill) (subset) | Leonxlnx | MIT | `Leonxlnx/taste-skill` |

Install them yourself (or let `install.sh` do it):

```bash
npx skills add emilkowalski/skill --global --skill emil-design-eng --yes
npx skills add pbakaus/impeccable --global --skill impeccable --yes
npx skills add Leonxlnx/taste-skill --global \
  --skill design-taste-frontend,redesign-existing-projects,minimalist-ui,industrial-brutalist-ui,high-end-visual-design --yes
```

Skip the automatic fetch with `./scripts/install.sh --no-design-skills`.

---

## License compliance

Both vendored skills are MIT-licensed. Per MIT terms, redistribution is permitted as long as:

- ✅ The original copyright notice is preserved (see `LICENSE` file in each subfolder).
- ✅ Attribution to the original author is given (see `ATTRIBUTION.md` in each subfolder).

If you are the author of either project and prefer not to be vendored here, please [open an issue](https://github.com/bymaxone/bymax.claude-code/issues) and we'll remove your content.

---

## How to install these (officially)

If you want these skills, **install from the original sources** (not from this repo). That way you get updates automatically:

```bash
# Everything Claude Code
git clone https://github.com/affaan-m/everything-claude-code ~/dotfiles-ecc
# follow ECC's install instructions

# ui-ux-pro-max
claude plugin install ui-ux-pro-max@ui-ux-pro-max
# (or follow the upstream README)
```
