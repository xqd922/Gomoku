---
name: Gomoku Design System
description: Material 3 Expressive design language for the six-platform Gomoku game — a violet seed, generous feature-scale rounding, CJK-first weight-driven typography, and a fixed physical board palette.

tokens:
  colors:
    seed: "#7560C7"
    brand-ink: "#36313F"
    brand-paper: "#FFFBF5"
    brand-sand: "#DED7CB"
    board-canvas-light: "#F4F0E8"
    board-canvas-dark: "#27252C"
    board-grid-light: "#979087"
    board-grid-dark: "#817889"
    stone-black: "#302D35"
    stone-black-border: "#4C4752"
    stone-white: "#FFFDFA"
    stone-white-border: "#BFB8BA"
  typography:
    fontFamily: "NotoSansSC"
  rounded:
    joined: "6px"
    thumb: "14px"
    field: "20px"
    menu: "24px"
    card: "28px"
    feature: "32px"
  spacing:
    tight: "8px"
    content: "16px"
    section: "24px"
    page: "32px"
  components:
    primary-button:
      height: "56px"
      shape: "stadium"
    secondary-button:
      height: "52px"
      shape: "stadium"
    input:
      fill: "surfaceContainerHighest"
      radius: "{rounded.field}"
    card:
      fill: "surfaceContainerLow"
      radius: "{rounded.card}"
      elevation: "0"
    dialog:
      radius: "{rounded.feature}"
    chip:
      radius: "{rounded.thumb}"
    navigation:
      compact: "bottom bar, 4 destinations"
      expanded: "side rail, 4 destinations"
      indicator: "superellipse pill"
---

# Design System: Gomoku

## Overview

Gomoku is a calm, tactile board-game surface wrapped in Material 3 Expressive chrome. The atmosphere is **"evening study"**: warm paper tones meet a single confident violet seed (#7560C7), with generous feature-scale rounding (28–32px) and a stone board that behaves like a physical object — fixed warm colors, soft drop shadows, and a spring-settle drop animation. Density is balanced (5/10): roomy on phones, tighter information panels on wide screens. Motion is fluid but spring-driven (6/10): continuous-corner shapes everywhere, press feedback that compresses on a spring, staggered entrances, shared-axis page transitions, and everything honors the system reduce-motion setting.

The design system is implemented in `apps/gomoku_app/lib/design/` — `theme.dart` builds both brightness schemes, `tokens.dart` holds spacing/shape/layout/motion constants, `motion.dart` holds the spring presets and curves, and `shape.dart` holds the superellipse shape language. This document is the source of truth those files express; when code and this document disagree, fix the code.

## Colors

The scheme is generated with `ColorScheme.fromSeed(seedColor: #7560C7, dynamicSchemeVariant: vibrant)` per brightness, so users may swap in Android 12+ dynamic color at runtime. The static values below are the canonical fallback palette.

### Light scheme

| Role | Hex | Usage |
| --- | --- | --- |
| Primary | #6425FF | Primary actions, selected tabs, focused borders, section captions |
| On primary | #FFFFFF | Text on primary fills |
| Primary container | #E7DEFF | Hero banner, selected account cards |
| On primary container | #4B00D3 | Text on primary container |
| Secondary container | #F0DBFF | Notices, status pills, unselected choice cards |
| On secondary container | #514060 | Text on secondary container |
| Tertiary container | #FDD6FF | Avatar (signed-in), third accent surface |
| On tertiary container | #5D3A63 | Text on tertiary container |
| Surface | #FDF7FF | Scaffold background |
| Surface container low | #F7F1FF | Cards, list groups, bottom sheets |
| Surface container high | #ECE6F5 | Dialogs, menus |
| Surface container highest | #E6E0EF | Filled text fields, guest avatar |
| On surface | #1C1A24 | Primary text |
| On surface variant | #484553 | Secondary text, icons |
| Outline | #797585 | Outlined button borders |
| Outline variant | #CAC4D6 | Dividers, hairlines, guest avatar border |
| Error / container | #BA1A1A / #FFDAD6 | Destructive and failure states |
| On error container | #93000A | Error body text |

### Dark scheme

| Role | Hex | Usage |
| --- | --- | --- |
| Primary | #CBBEFF | Primary actions, selected tabs |
| On primary | #340098 | Text on primary fills |
| Primary container | #4B00D3 | Hero banner, selected account cards |
| On primary container | #E7DEFF | Text on primary container |
| Secondary container | #514060 | Notices, status pills |
| On secondary container | #F0DBFF | Text on secondary container |
| Tertiary container | #5D3A63 | Avatar (signed-in) |
| On tertiary container | #FDD6FF | Text on tertiary container |
| Surface | #14121C | Scaffold background |
| Surface container low | #1C1A24 | Cards, list groups, bottom sheets |
| Surface container high | #2B2833 | Dialogs, menus |
| Surface container highest | #36333E | Filled text fields, guest avatar |
| On surface | #E6E0EF | Primary text |
| On surface variant | #CAC4D6 | Secondary text, icons |
| Outline | #938E9F | Outlined button borders |
| Outline variant | #484553 | Dividers, hairlines, guest avatar border |
| Error / container | #FFB4AB / #93000A | Destructive and failure states |

### Board palette (fixed, physical)

The board is a physical object and does **not** follow the scheme: its colors are constant across themes and brand changes, only light/dark canvases swap.

| Token | Light | Dark | Usage |
| --- | --- | --- | --- |
| Canvas | #F4F0E8 | #27252C | Board background (warm paper / deep slate) |
| Grid | #979087 | #817889 | Lines, star points, coordinate labels |
| Stone black fill | #302D35 | #302D35 | Charcoal ink, never #000000 |
| Stone black border | #4C4752 | #4C4752 | Edge definition |
| Stone white fill | #FFFDFA | #FFFDFA | Warm porcelain white, never #FFFFFF |
| Stone white border | #BFB8BA | #BFB8BA | Edge definition |

Every stone disc — on the board, in avatars, in record previews — must use these four stone tokens from `lib/design/board_palette.dart`. Brand artwork ink (#36313F), paper (#FFFBF5) and sand (#DED7CB) are reserved for the logo mark.

## Typography

Single family: **NotoSansSC** for both CJK and Latin (offline-bundled, no web font fetching). Hierarchy is weight-driven, not size-shouting.

| Style | Weight | Notes |
| --- | --- | --- |
| displayLarge | w700, 56px | Reserved for rare display moments; negative tracking (-1.8) for Latin only, 0 for CJK |
| displayMedium | w700, 44px | Section heroes |
| displaySmall | w700, 36px | Compact heroes |
| headlineLarge/Medium | w700–w600 | Page titles and the home banner |
| headlineSmall | w600 | Card titles |
| titleLarge / titleMedium / titleSmall | w600 | List titles, labels |
| bodyLarge / bodyMedium | 400, height 1.5 (CJK) / 1.4 (Latin) | Relaxed leading for CJK density |
| labelLarge | w600 | Buttons and chips |

## Layout

**Navigation is adaptive**: below 840px a bottom navigation bar carries the four destinations (对局 Play, 联机 Online, 棋谱 Library, 我的 Me); at 840px and above it becomes a left navigation rail so wide windows keep the content — not the chrome — as the protagonist. The four destinations are the app's top level; account, settings, and about live inside 我的. Game surfaces (local game, online room, replay) are pushed full-screen routes and never show the navigation shell.

Breakpoints: compact 600, expanded 840. Page inset: 16 / 24 / 32 by width; content max-width 1160; reading pages cap at 680; the board caps at 688. Vertical page rhythm uses the spacing scale (8/16/24/32). Phones stack single-column always; wide screens pair the board with a details panel. Fixed action areas on phones keep primary controls reachable without scrolling. Horizontal overflow at any viewport is a critical failure.

## Elevation & Depth

Elevation is expressed through **surface color, not shadows**: all chrome sits at elevation 0 with distinct surface-container tones. The only shadows in the product are the physical stone drop shadows (black at 8–13% alpha, 2–5px blur) — never on UI chrome. Dialogs, menus and sheets differentiate themselves by container color plus shape, not shadow.

## Shapes

Every corner uses a **continuous superellipse** (`RoundedSuperellipseBorder`): the radii below are unchanged, but corners read softer and more expressive than plain circular ones. Rounding scale, largest to smallest: feature 32 (dialogs, bottom sheets, home banner), card 28 (cards, player strips, settings swatches), menu 24 (pop-up menus, notices, record tiles), field 20 (inputs, snackbars, shortcut icon wells), thumb 14 (chips, small previews), joined 6 (reserved for tightly joined controls). Primary buttons are stadium-shaped (full pill); navigation indicators are superellipse pills. Corner radii are never mixed arbitrarily within one component group, and plain circular borders never appear where a token exists.

## Components

- **Primary button (filled):** stadium shape, minimum height 56px, primary fill, icon + label, disabled at reduced opacity. The home banner uses primaryContainer with onPrimaryContainer text; the filled primary button on that banner is the single loudest action.
- **Secondary buttons (outlined / tonal):** stadium shape, height 52px, outline variant or secondary container fill.
- **Text buttons / icon buttons:** minimum 48×48 touch target.
- **Inputs:** filled with surfaceContainerHighest, borderless at rest, 2px primary border on focus, error border in error color, 20px radius, label inside the field, error text below (max 3 lines).
- **Cards:** surfaceContainerLow, 28px radius, elevation 0, zero external margin (spacing is composed by parents).
- **List groups:** one surfaceContainerLow card at 28px radius. Rows are separated by a hairline divider, not by gaps or mixed corner radii.
- **Dialogs:** surfaceContainerHigh, 32px radius. **Bottom sheets:** surfaceContainerLow, 32px top radius, drag handle shown. **Menus:** surfaceContainerHigh, 24px radius.
- **Snackbars:** floating, 20px radius, used for all error feedback (never blocking dialogs for recoverable errors).
- **Notices (inline):** secondaryContainer at rest, errorContainer for failures, 24px radius, icon + message + optional right-aligned action, live-region semantics.
- **Chips / status pills:** thumb radius, container colors from the scheme, w600 labels.
- **Navigation bar / rail:** surface-container fill, no elevation, four destinations with outlined icons that swap to their filled pair when selected. The active destination sits in a secondary-container superellipse pill indicator. Destinations are always labeled.
- **Account avatar:** 40px circle; guests get surfaceContainerHighest with a 1px outlineVariant ring, signed-in users get tertiaryContainer with the first character of the nickname.
- **Loading:** brief spinners are acceptable for sub-second fetches; anything longer must show skeleton or composed empty states. Empty states are composed (stone trio illustration + explanation + action), never bare text.
- **Board interactions:** touch pre-select then confirm (configurable), mouse hover preview, keyboard cursor with Enter/Space placement, Escape clears, screen-reader per-point actions. The winning line is highlighted with an accent underline wash at 23% alpha.

## Motion & Interaction

Motion runs on two layers: **durations** (fast 150ms, feedback 180ms, mid 220ms, transition 320ms, settle 420ms) and **springs** (`AppSprings`/`SpringCurve` in `motion.dart` — a spring feel with deterministic timing that always lands exactly on target). State swaps and theme changes use `easeInOutCubicEmphasized`; entrances use `emphasizedDecelerate`.

- **Press feedback:** tappable cards and key buttons compress to 96% on a spring while pressed and release with an elastic settle — a paint-only transform, so layout and hit testing observe the surface at rest.
- **Entrances:** page sections and first-screen cards fade in while sliding up 24px; list tiles cascade in 30ms steps for the first items (long lists enter without waiting); empty states stagger illustration → title → body → action at 60ms steps.
- **Tab navigation:** switching destinations plays a 220ms fade-and-slide on the incoming branch and fires a selection haptic; the bottom bar's filled/outline icon pair swaps with the selection.
- **Page transitions:** every pushed route uses the horizontal shared-axis transition (320ms) on all platforms.
- **Dialogs:** scale-and-fade in over a 32% scrim (240ms).
- **Board:** stone placement settles on the settle spring over 400ms. A five-in-a-row win is the single loud moment: the accent wash grows along the winning line (~400ms) while the winning stones pulse outward one after another (90ms stagger) with a medium haptic. The pre-selected ghost stone breathes gently while it waits for confirmation.
- All motion collapses to zero when `MediaQuery.disableAnimationsOf` or the in-app reduce-motion setting is active — via `AppMotion.duration` for timing and explicit settled states elsewhere. Animate implicit only (transform/opacity equivalents in Flutter); never block input on animation.

## Accessibility

- Body text contrast ≥ 4.5:1 in both schemes; scheme pairs above satisfy this.
- Touch targets ≥ 48×48; board cross-points expose semantic actions with per-point labels.
- Every error surfaces as a localized string via `strings.error(code)`; never raw exception text.
- Full Chinese/English parity: every user-facing string lives in `l10n/strings.dart` with both locales.

## Do's and Don'ts

**Do** use the shape and spacing tokens; **do** keep the board palette fixed and physical; **do** keep elevation in surface tones; **do** treat the home hero as the single loud moment; **do** keep both locales complete.

**Never** use pure black #000000 or pure white #FFFFFF for stones; never put drop shadows on chrome; never introduce a second accent hue; never use emoji as UI icons; never overlap text over images or other text; never fabricate metrics or numbers; never add filler copy ("scroll to explore" style); never block input behind animations; never hardcode a radius or spacing that exists as a token — extend the token set instead.
