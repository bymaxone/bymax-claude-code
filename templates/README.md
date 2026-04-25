<!--
README.md TEMPLATE — Bymax style
================================
Replace every {{PLACEHOLDER}} with real content. Delete sections you don't need
(but think twice — most are valuable for adoption).

Visual conventions:
- Centered logo / badge at top
- Tagline + subtitle
- Badge row (license, CI, version, downloads, etc.)
- Quick-link nav anchors
- Emoji-prefixed section headings (✨ 🚀 📦 🔥 🛡️ 🏗️ 🗺️ 🤝 🔒 📄)
- Tables for features / endpoints / config / API
- Mermaid or ASCII for architecture
- Footer with "Built with ❤️" tagline
-->

<p align="center">
  <img src="https://img.shields.io/badge/{{ORG}}-{{PROJECT--SLUG}}-{{HEX_NO_HASH}}?style=for-the-badge&logo={{LOGO}}&logoColor=white" alt="{{PROJECT_NAME}}" />
</p>

<h1 align="center">{{PROJECT_NAME}}</h1>

<p align="center">
  <strong>{{ONE-LINE TAGLINE}}</strong><br />
  <sub>{{SUB-TAGLINE — comma-separated keywords / value props}}</sub>
</p>

<p align="center">
  <a href="https://www.npmjs.com/package/{{NPM_PACKAGE}}"><img src="https://img.shields.io/npm/v/{{NPM_PACKAGE}}?style=flat-square&colorA=000000&colorB=000000" alt="npm version" /></a>
  <a href="https://www.npmjs.com/package/{{NPM_PACKAGE}}"><img src="https://img.shields.io/npm/dm/{{NPM_PACKAGE}}?style=flat-square&colorA=000000&colorB=000000" alt="npm downloads" /></a>
  <a href="https://github.com/{{ORG}}/{{REPO}}/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/{{ORG}}/{{REPO}}/ci.yml?branch=main&style=flat-square&colorA=000000&label=CI" alt="CI status" /></a>
  <a href="https://github.com/{{ORG}}/{{REPO}}/blob/main/LICENSE"><img src="https://img.shields.io/npm/l/{{NPM_PACKAGE}}?style=flat-square&colorA=000000&colorB=000000" alt="license" /></a>
  <a href="https://www.typescriptlang.org/"><img src="https://img.shields.io/badge/TypeScript-strict-3178C6?style=flat-square&logo=typescript&logoColor=white" alt="TypeScript" /></a>
</p>

<p align="center">
  <a href="https://github.com/{{ORG}}/{{REPO}}">GitHub</a> ·
  <a href="https://github.com/{{ORG}}/{{REPO}}/issues">Issues</a> ·
  <a href="#-quick-start">Quick Start</a> ·
  <a href="#-features">Features</a> ·
  <a href="#-api-reference">API Reference</a>
</p>

---

## ✨ Overview

`{{PROJECT_NAME}}` is **{{ONE-PARAGRAPH WHAT IT IS}}**. {{Why it exists / what problem it solves in the user's voice}}.

### Why {{PROJECT_NAME}}?

- **🎯 {{Value prop #1}}** — {{One sentence}}.
- **🔌 {{Value prop #2}}** — {{One sentence}}.
- **🔒 {{Value prop #3}}** — {{One sentence}}.
- **⚡ {{Value prop #4}}** — {{One sentence}}.

```bash
{{PKG_MGR}} add {{NPM_PACKAGE}}
```

---

## 🔥 Features

### 🔐 {{Group 1}}

- ✅ **{{Feature}}** — {{description}}
- ✅ **{{Feature}}** — {{description}}

### 🛡️ {{Group 2}}

- ✅ **{{Feature}}** — {{description}}
- ✅ **{{Feature}}** — {{description}}

### 🧩 {{Group 3 — Developer Experience}}

- ✅ **{{Feature}}** — {{description}}
- ✅ **{{Feature}}** — {{description}}

---

## 🚀 Quick Start

### 1. Install

```bash
# Using pnpm (recommended)
pnpm add {{NPM_PACKAGE}}

# Using npm
npm install {{NPM_PACKAGE}}

# Using yarn
yarn add {{NPM_PACKAGE}}
```

> [!IMPORTANT]
> {{Mention any required peer-dependencies or post-install steps}}.

### 2. {{Step name — e.g., Configure}}

```typescript
// {{example file}}
import { {{Symbol}} } from '{{NPM_PACKAGE}}';

// {{Show the simplest possible usage}}
```

### 3. {{Step name}}

```typescript
// {{example}}
```

---

## ⚙️ Configuration

| Group        | Key options                          | Default     |
| ------------ | ------------------------------------ | ----------- |
| **{{group}}** | {{`option1`, `option2`}}             | {{value}}   |
| **{{group}}** | {{`option1`, `option2`}}             | {{value}}   |

> [!NOTE]
> {{Important note about configuration}}.

---

## 🏗️ Architecture

```
{{ASCII or Mermaid diagram showing the system layout}}
```

### Design Principles

| Principle              | Description                                          |
| ---------------------- | ---------------------------------------------------- |
| **🔌 {{Principle}}**   | {{One-sentence explanation}}                         |
| **🔒 {{Principle}}**   | {{One-sentence explanation}}                         |
| **🪶 {{Principle}}**   | {{One-sentence explanation}}                         |
| **⚡ {{Principle}}**   | {{One-sentence explanation}}                         |

---

## 🧱 Tech Stack

<p>
  <img src="https://img.shields.io/badge/{{NAME}}-{{VERSION}}-{{HEX}}?style=flat-square&logo={{LOGO}}&logoColor=white" alt="{{NAME}}" />
  <img src="https://img.shields.io/badge/TypeScript-strict-3178C6?style=flat-square&logo=typescript&logoColor=white" alt="TypeScript" />
  <img src="https://img.shields.io/badge/Node.js-{{VERSION}}-339933?style=flat-square&logo=node.js&logoColor=white" alt="Node.js" />
</p>

---

## 📖 API Reference

### {{Section 1 — e.g., Functions / Endpoints / Components}}

| {{Header}} | {{Header}} | {{Header}}     |
| ---------- | ---------- | -------------- |
| {{cell}}   | {{cell}}   | {{cell}}       |

### {{Section 2}}

| {{Header}} | {{Header}} |
| ---------- | ---------- |
| {{cell}}   | {{cell}}   |

---

## 🗺️ Roadmap

| Item                                  | Status    |
| ------------------------------------- | --------- |
| {{Feature / improvement}}             | Planned   |
| {{Feature / improvement}}             | Exploring |
| {{Feature / improvement}}             | Done      |

> Track progress on the [issues board](https://github.com/{{ORG}}/{{REPO}}/issues).

---

## 🤝 Contributing

Contributions are welcome! Please read our [contributing guidelines](./CONTRIBUTING.md) before submitting a pull request.

```bash
# Clone the repository
git clone https://github.com/{{ORG}}/{{REPO}}.git
cd {{REPO}}

# Install dependencies
{{PKG_MGR}} install

# Run tests
{{PKG_MGR}} test

# Lint
{{PKG_MGR}} lint

# Type check
{{PKG_MGR}} type-check

# Build
{{PKG_MGR}} build
```

---

## 🔒 Security Policy

If you discover a security vulnerability, please **do not** open a public issue. Instead, email us at **{{security-email}}** with details. We take security seriously and will respond promptly.

See [SECURITY.md](./SECURITY.md).

---

## 📄 License

[MIT](./LICENSE) © [{{Author}}]({{author-url}})

---

<p align="center">
  <sub>Built with ❤️ by <a href="{{author-url}}">{{Author}}</a></sub>
</p>
