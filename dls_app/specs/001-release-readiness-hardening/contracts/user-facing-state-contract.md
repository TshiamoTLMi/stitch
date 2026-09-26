# User-facing state contract

This contract describes observable behavior for the four release-hardening stories. It complements `SCREENS.md`; existing visual tokens and navigation remain authoritative.

## Password recovery

| State | Required user-visible behavior |
|---|---|
| `idle` | Recovery dialog is reachable from the signed-out login surface. |
| `invalid` | Explain that a required or malformed email needs correction; do not call Firebase. |
| `sending` | Show progress and disable the recovery action; repeated taps do not start another active request. |
| `success` | Show neutral confirmation that an email was requested if the account exists; retain normal signed-out routing. |
| `failure` / `offline` | Use concise actionable copy, keep the email, show retry, and never show raw exception text. |
| `expired-link` | Explain that the link is no longer usable and direct the user to request a new link or sign in after retrying. |

## Event/reminder and recommendation guidance

- A next-local-day event shows its name, date, and occasion.
- Android shows one of `scheduled`, `permission denied`, `unavailable`, or `fallback`; it never claims delivery solely because scheduling was attempted.
- Web shows an in-app upcoming-event reminder on the next relevant app visit and states that browser notification delivery is unavailable or not verified.
- A recommendation shows `what is missing`, `why it relates to this event/occasion`, and one quick action. Actions target the existing wardrobe-add or generator route and preserve occasion/event context where supported.
- Covered wardrobe, incomplete event/metadata, no upcoming events, stale data, and unknown data are distinct states. Empty strings or fabricated needs are not valid output.

## Analytics/style evolution

- Profile metrics use readable labels for wardrobe items, outfits, events, and style measures.
- Loading is stable and does not alter the surrounding shell.
- Empty and partial data explain what is unavailable and how to create activity.
- Permission/data errors and offline/stale data are explicit and retryable.
- Timeline entries are newest-first with a readable date, mapped activity label, concise description, and fallback values for missing optional caption/metadata.

## Navigation and design constraints

- Do not add a new top-level navigation destination.
- Reuse the existing five-tab shell and its current auth/onboarding route.
- Reuse `SCREENS.md` tokens: dark layered surfaces, gold primary, lime tertiary, Plus Jakarta Sans/Inter, pill controls, rounded cards, and no visible borders.
- Any accepted layout, interaction, navigation, or state presentation change requires a corresponding `SCREENS.md` update before implementation is complete.