---
name: schedly-design-system
description: Permanent visual design authority and UI design system for Schedly. Governs all frontend visual and interaction decisions across Classic, Heritage, Neo Future, Bloom, and Champion themes. Enforces timetable visual priority, typography hierarchy, materials, cards, badges, crowns/crests, motion, accessibility, and Flutter 60fps performance rules. Works in synergy with ui-ux-pro-max and impeccable.
---

# Schedly Design System (SDS)

The permanent visual design authority for Schedly. Academic schedule clarity under pressure is the primary mission: lecture name, time, and room number must be identifiable within 500ms. Decorative styling must always yield to content.

## 1. Skill Synergy & Execution Triad
- **SDS (Supreme Authority)**: Dictates Schedly brand identity, theme recipes, card rails, and non-negotiable UX constraints.
- **Source of Truth**: `lib/theme/visual_skin.dart`, `lib/theme/design_tokens.dart`, `lib/theme/app_colors.dart`.
- **`ui-ux-pro-max` (Searchable Intelligence)**: Query via `python .agents/skills/ui-ux-pro-max/scripts/search.py "<query>" --domain <domain>` for Flutter stack rules, touch scales, and WCAG AA contrast values.
- **`impeccable` (Execution Playbook)**: Use playbooks (`shape`, `audit`, `critique`, `polish`) to enforce workflow rigor, review heuristics, and eliminate defect drift.
- **Workflow Order**: 1. Plan mode in `impeccable` → 2. Query stack rules in `ui-ux-pro-max` → 3. Implement SDS tokens & recipes → 4. Audit via `impeccable`.

## 2. Core Visual Philosophy
- **Production-grade mobile native**: Polished, tactile, university-level utility. Never generic AI aesthetics, cartoon emojis, or pastel soup.
- **Restraint over flash**: "Gradient + glow != premium". True luxury comes from micro-typography, precise optical spacing, authentic materials, and sharp specular borders.
- **Timetable always has priority**: Canvas animations and decorative backgrounds must never compromise card contrast or text legibility.

## 3. Theme Architecture (`VisualSkin`)
All styling routes through `VisualSkin.of(context)` responding to `ThemeController`:
- **Classic (`defaultTheme`)**: Slate (`#0F172A`), white, indigo (`#4F46E5`), cyan. Crisp SaaS clarity.
- **Heritage (`heritage`)**: Aged copper (`#C25E38`), rust, brass (`#D9822B`), cream. Collegiate academic elegance.
- **Future (`future`)**: Deep graphite (`#0B0E14`), neon cyan (`#00F2FE`), teal. Precision HUD terminal.
- **Bloom (`bloom`)**: French rose (`#DE527B`), coral, lavender, mint. Friendly, rounded organic warmth.
- **Champion (`champion`)**: Imperial obsidian (`#08070B`), metallic gold (`#FFD700`), champagne. Prestigious earned reward.

## 4. Champion Theme Visual Identity (Earned Reward)
- **Palette**: Obsidian base (`#08070B`), elevated surfaces (`#131118`, `#1B1722`), metallic gold (`#FFD700`), specular glints (`#FFE57F`), satin brass borders (`#B4831B`), imperial white text (`#FFFDF5`), champagne muted text (`#C7B696`).
- **Heraldic Language**: Laurels, crowns (`Icons.workspace_premium_rounded`), chevron rank bars, and gold gradient shader masks reserved strictly for earned rank/Champion views.
- **Specular Sheen**: Directional light source (top-left 135°) on borders; 90% obsidian, 10% gold accents. Never bathe entire screens in solid yellow.
- **Background Atmosphere**: Animated gold energy streams must run in an isolated `AnimatedThemeCanvas` behind a `RadialGradient` vignette scrim and never penetrate card bounds.

## 5. Timetable Visual Priority & Cards
- **Opaque Surfaces**: Timetable cards must be 100% solid/opaque (`#131118` dark, `#FFFFFF` light). Never use translucent/glassmorphic cards over animated backgrounds.
- **Left Status Rail**: Mandatory 4.0–4.5px vertical indicator:
  - Primary Accent: Scheduled lecture
  - Emerald (`#10B981`): Conducted / Attended
  - Crimson (`#EF4444`): Cancelled
  - Amber (`#F59E0B`): Rescheduled / Active
- **Scanning Hierarchy**:
  - Level 1: Tabular time (13px, w600) + Status badge right-aligned
  - Level 2: Subject name (16–17px, w700, max 2 lines with ellipsis)
  - Level 3: Faculty, room number, building (12–13px, w500, muted)

## 6. Typography & Materials
- **Headers**: `GoogleFonts.outfit` or `Plus Jakarta Sans` (w700–w800, tight tracking -0.4 to -0.6).
- **Body & Data**: `GoogleFonts.inter` (tabular figures for timestamps, rooms, and metrics).
- **Spacing**: Follow `AppSpacing` (4px/8px modular scale: xs=4, sm=8, md=12, lg=16, xl=24, x2l=32).
- **Corner Radii**: Follow `AppRadius` (md=12px controls/inputs, lg=16px cards, xl=20px hero, full=999px pills).
- **Depth**: Soft ambient drop shadows + 1px hairline borders (`AppColors.borderSubtle` or theme border).

## 7. Component Standards
- **Buttons**: Minimum 48px touch height, solid fill or crisp hairline border, rounded `AppRadius.md`.
- **Badges**: Tinted container (10–15% opacity) with matching border; must include both uppercase text label (`CANCELLED`) and supporting icon (`Icons.warning_amber_rounded`).
- **Icon Containers**: 44–50px square containers with `AppRadius.md` (12px), icon sized at 48% container width.
- **Crowns / Crests**: Reserved strictly for Champion achievements, Rank 1–3 podiums, and CR/SR badges. Never use gratuitously.

## 8. Motion Principles
- **Durations**: Snappy and physics-based (micro: 50ms, fast: 100ms, standard: 150ms, smooth: 200ms).
- **Curves**: Crisp deceleration (`Curves.easeOutCubic`) or spring (`Curves.easeOutBack`).
- **Reduced Motion**: Always check and honor `MediaQuery.disableAnimationsOf(context)` before triggering transitions.

## 9. Flutter Performance Rules (60/120fps Guarantee)
- **RepaintBoundary**: Isolate `AnimatedThemeCanvas` and foreground `ListView` in separate `RepaintBoundary` widgets.
- **Zero Tree Rebuilds**: Background controllers must repaint via `CustomPainter(repaint: animation)`, never via root `setState`.
- **No BackdropFilter in Lists**: Avoid live blur filters in scrollable views due to mobile GPU fill-rate penalties.
- **Const Everywhere**: Mark all immutable decorations, styles, and paddings with `const`.

## 10. Accessibility & Anti-Patterns to Reject
- **WCAG 2.1 AA**: Minimum 4.5:1 contrast for normal text; minimum 44x44dp interactive touch targets.
- **Never color-only state**: Statuses must feature text labels alongside color indicators.
- ❌ No translucent timetable cards bleeding animated background clutter.
- ❌ No generic AI neon pastel soup or fuzzy, ungrounded glows.
- ❌ No emojis as primary course/subject icons (use vector icons only).
- ❌ No laggy animations (>250ms) blocking user interactions or day changes.
- ❌ No layout shift on data load (use fixed-height skeleton cards).
