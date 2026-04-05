---
name: Project goals and direction
description: Forked OpenNutriTracker - building seamless AI calorie tracker with VLLM integration
type: project
---

Forking OpenNutriTracker to build a personal low-friction calorie tracking app. Key planned changes:
- VLLM integration (Google API, possibly OpenAI) for food recognition / nutrition estimation
- Focus on minimal user effort for logging
- Needs to support rapid iteration cycles without data loss

**Why:** Existing calorie tracking apps have too much friction. AI-powered estimation can reduce effort dramatically.
**How to apply:** Prioritize simplicity, upgradability, and backward-compatible data migrations in all design decisions. This is a personal-use app — no need for feature flags, graceful degradation for other users, or release processes. Move fast, keep data safe.
