# DLS Feature Plans (Post-MVP)

This file tracks possible features after the current MVP auth/onboarding and sprint stabilization work.

## Priority Framework

Use this ordering for planning:

1. P0: Release blockers
2. P1: Core value improvements
3. P2: UX polish
4. P3: Nice-to-have experiments

## P0 - Release Blockers

1. Complete Android physical smoke test pass.
2. Complete iOS physical smoke test pass.
3. Harden Firestore + Storage security rules for authenticated users.
4. Verify OAuth provider setup in Firebase Console:
   - Google
   - Apple (if enabled)
   - Microsoft (if enabled)

## P1 - Core Value Improvements

1. AI Style DNA v1 (client-side/serverless)
   - derive style profile from onboarding + closet metadata
   - generate explainable tags for user style identity
2. AI Outfit Ranking v2
   - improve scoring by weather/event context + user preference history
3. Feedback Loop
   - like/dislike per outfit suggestion
   - personalize future ranking from feedback
4. Better onboarding retention
   - save progress if onboarding interrupted
   - show profile completion progress state

## P2 - UX and Product Quality

1. Closet search by color/category/tag.
2. Batch edit for wardrobe items.
3. Better loading/empty/error UI states across all tabs.
4. Lightweight offline resilience for key read screens.

## P3 - Growth and Engagement

1. Weekly style recap card.
2. Event reminder nudges.
3. Share outfit card (export image).
4. Seasonal capsule suggestions.

## Delivery Plan Suggestion

1. Finish P0 only, then run full pre-go-live checklist.
2. Ship MVP release candidate.
3. Start P1 in one sprint focused on AI personalization and explainability.
4. Bring P2 and P3 incrementally after production telemetry.
