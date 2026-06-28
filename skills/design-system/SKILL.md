---
name: design-system
description: Project design system rules — CSS framework, visual grammar, component classes, and UI generation surface patterns. Read this before designing or reviewing views to understand the project's visual constraints.
---

# Design System

This skill is project-specific. Read it to understand the CSS framework, visual grammar, and component library before designing or reviewing views.

> **Setup required:** When adopting this team for a new project, replace the placeholder sections below with the project's actual design system documentation. Remove any sections that don't apply (e.g., AI generation surfaces for projects without LLM features).

---

## CSS Framework

> Fill in your project's CSS framework name, class prefix/naming pattern, and layout system.

Document:
- Framework name and source (local gem, npm package, CDN, custom)
- Class naming prefix and convention
- Layout system: available regions and how they're structured
- Core component classes and what they render
- Utility classes for spacing, typography, color, flex

**ERB helper methods (if any):**

List any view helpers that wrap framework components. Example:

```ruby
framework_button(label, **options)
framework_card(**options, &block)
framework_badge(label, variant:)
```

---

## Visual Grammar

Define the type treatment for different data types. A clear grammar lets every agent make consistent `class` decisions without guessing.

> Fill in your project's visual grammar rules. Example pattern:

| Type | Treatment | Class |
|---|---|---|
| Technical data (IDs, timestamps, counts, codes, file sizes) | Monospace | `[your-mono-class]` |
| Prose, labels, instructions, headings, generated text | Sans-serif (default) | (no class needed) |

**The rule:** name the class for every data field in every design spec. A field rendered in the wrong type treatment is a design system violation.

---

## AI Generation Surfaces

> If this project has no AI generation features, delete this section.

Every surface that triggers or displays AI generation must follow this contract:

**Trigger state** — before generation fires:
- Generation triggers are visually distinct from regular form submits (class, label, or both)
- If there is a cost or token implication visible to the user, it appears before triggering

**Loading state** — while generation is in progress:
- Always show a visible progress indicator — never leave the UI frozen
- Streaming responses update the DOM incrementally as tokens arrive — never batch-replace on completion

**Error states** — when generation fails:
- Timeout, provider error, and rate limit each have distinct, user-readable messages
- Error messages never expose raw exception text

```erb
<%# Pattern for a generation trigger — replace with this project's trigger class %>
<%= framework_button "Generate", class: "[ai-trigger-class]", data: { turbo_submits_with: "Generating..." } %>
```

---

## Never Do

> Fill in prohibited patterns for this project's views.

Common entries:
- Conditional logic in views — move to helpers
- Custom framework classes that don't exist in the design system — add to a project-level CSS extension file first
- Raw exception messages in user-facing error states
- AI generation that blocks the UI with no loading feedback
- Decorative elements that add visual noise without conveying information
