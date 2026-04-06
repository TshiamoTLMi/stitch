# Design System Specification: The Modern Curator

## 1. Overview & Creative North Star
This design system is built to bridge the gap between high-end fashion editorial and cutting-edge fintech utility. Our Creative North Star is **"The Modern Curator."** 

We are not building a utility app; we are building a digital atelier. To achieve this, the design system rejects "template-style" layouts in favor of an editorial approach. We use intentional asymmetry, expansive negative space, and image-first compositions that allow the user’s wardrobe to feel like a curated gallery. The visual language is deeply rooted in a South African luxury aesthetic—confident, warm, and sophisticated—while leveraging neon AI accents to signal intelligence and futurism.

## 2. Colors & Surface Architecture
The color palette is a study in tonal depth. We use deep charcoal and blacks to ground the experience, allowing gold and clay accents to feel like precious metals and earth against the night sky.

### Color Strategy
- **Primary Luxury (`#f2ca50`, `#d4af37`):** Use these Gold tones for high-conversion moments and status indicators.
- **Earth Tones (`#ffb4a5`, `#802918`):** These represent the "Human" element of the stylist, used for personalization and warmth.
- **AI Tertiary (`#96e400`, `#a5fa00`):** These lime highlights are used exclusively for AI-driven insights, suggestions, and scanning animations.

### The "No-Line" Rule
**Borders are strictly prohibited for sectioning.** To define boundaries, designers must use background color shifts or tonal transitions.
- **Surface Nesting:** Hierarchy is achieved by stacking `surface` tokens. A typical screen layout should follow this logic:
    1. Base layer: `surface` (#131313)
    2. Section layer: `surface_container_low` (#1c1b1b)
    3. Interactive card: `surface_container_high` (#2a2a2a)
- **The Glass & Gradient Rule:** For floating elements (like an AI stylist pop-over), use a backdrop-blur (20px-40px) combined with `surface_variant` at 60% opacity. For primary CTAs, apply a subtle linear gradient from `primary` to `primary_container` to create a "metallic sheen" rather than a flat fill.

## 3. Typography: Editorial Authority
The typography system uses high-contrast weights to mimic a fashion magazine. 

- **Display & Headlines (Plus Jakarta Sans):** These are our "Voice." Use `display-lg` for hero headers with tight letter spacing (-0.02em). This typeface brings a modern, tech-forward energy that balances the luxury theme.
- **Body & Titles (Inter):** Inter is used for all functional data. It provides the "Fintech" clarity needed for wardrobe management. 
- **The Contrast Rule:** Pair a `headline-lg` in Bold with a `body-sm` in Regular. This drastic jump in scale creates the "Editorial" feel found in high-end brand lookbooks.

## 4. Elevation & Depth
In this design system, we do not use "drop shadows" in the traditional sense. We use **Ambient Light.**

- **The Layering Principle:** Place a `surface_container_lowest` card on a `surface_container` background to create a "sunken" effect, or a `surface_container_highest` card on a `surface` background to create a "lifted" effect.
- **Ambient Shadows:** If a floating element requires a shadow (e.g., a bottom navigation bar), use a blur radius of 32px with the color `surface_container_lowest` at 40% opacity. It should feel like a soft glow of darkness, not a hard edge.
- **The "Ghost Border" Fallback:** If a layout feels too bleed-heavy for accessibility, use the `outline_variant` token at 15% opacity. This "Ghost Border" provides just enough structure without breaking the minimal aesthetic.

## 5. Components

### Buttons
- **Primary:** Rounded `full`. Gradient fill (`primary` to `primary_container`). Text color `on_primary`. High-gloss finish.
- **Secondary:** Rounded `full`. Surface `surface_container_high` with a `primary` ghost border (20% opacity).
- **AI Action:** Use `tertiary` (Lime) with a soft outer glow (4px blur) of the same color to indicate active AI processing.

### Cards (The Wardrobe Gallery)
- **Radius:** Always use `lg` (2rem) or `xl` (3rem) for image containers.
- **Structure:** No borders. Images should be edge-to-edge within the card. Use `surface_container_lowest` for the card body to create depth against the background.
- **Overlays:** Use subtle African geometric patterns (opacity 5%) as a background texture on cards that do not contain images.

### Input Fields
- **Styling:** Pill-shaped (`full` radius). Background `surface_container_low`. 
- **States:** On focus, the background transitions to `surface_container_highest` and the label moves to `primary` (Gold). No 1px border on focus; use a subtle outer glow instead.

### AI Stylist Pulse
- A unique component for this app. A floating `surface_variant` circle with a `backdrop-blur`. It uses a `tertiary` (Lime) "breathing" shadow to indicate the AI is listening or analyzing the wardrobe.

## 6. Do's and Don'ts

### Do:
- **Do** use massive amounts of white space (vertical padding). Let the clothes breathe.
- **Do** use `display-lg` for numbers (e.g., "42 Outfits") to give them a premium, statistical feel.
- **Do** use imagery that is high-contrast and professionally lit. The UI is the frame; the clothes are the art.

### Don't:
- **Don't** use 1px solid dividers. Use a 16px or 24px gap instead.
- **Don't** use pure white (#FFFFFF) for text. Use `on_surface` (#e5e2e1) to reduce eye strain in Dark Mode.
- **Don't** use standard "Material Design" FABs. Use bespoke, integrated action bars that follow the `surface_container` hierarchy.
- **Don't** over-use the African geometric patterns. They are a "whisper," not a "shout." Use them only on the most intentional surfaces (e.g., a profile header or a loading state).

---
**Director's Note:** Every pixel should feel like it was placed by a stylist. If a screen looks "busy," remove a line, increase a margin, and check your surface tiers. We are designing for the elite—simplicity is the ultimate sophistication.