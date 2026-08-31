---
description: 'Run this session as the Engineering Project Manager for multi-agent development: load the bymax-pm:pm skill, reconcile the persistent .claude/pm/ board against repositories and live agents, then operate — decompose requests into task contracts, delegate to independent Claude Code peer sessions via SendMessage, verify evidence through quality gates, resolve blockers, and report consolidated status. Modes: status (health block), standup (session report), release-check (evidence-backed release readiness). Triggers: "be my PM", "coordinate the agents", "delegate this work", "seja meu PM", "status do projeto".'
argument-hint: "[status|standup|release-check] [instruction]"
---

# /bymax-pm:pm — Engineering Project Manager

Invoke the `bymax-pm:pm` skill and follow it. Pass the arguments through verbatim:

- no argument, or a free-form instruction → **operate** (startup routine first if
  this session has not run it yet, then act on the instruction)
- `status` → PROJECT HEALTH report
- `standup` → SESSION REPORT
- `release-check` → release readiness, checked live, answered with evidence

The skill is the authority on all behaviour — lifecycle, peer protocol, gates,
escalation, persistence. This command only routes into it.

## Session identity note

The PM works best in a session the human started with an addressable name, e.g.
`claude --name pm`, from the coordination directory (see the plugin README). If
this session has no name yet, suggest `/rename pm` once — peers reply to the
session's name, and a stable name keeps the roster and message threads coherent
across restarts.
