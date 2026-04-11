# Tomorrow Test Flow (Physical Device)

This guide is for the next test phase on your phone after the code-level work completed today.

Use together with:

- `PRE_GO_LIVE_CHECKLIST.md` (release gate checklist)
- `FEATURE_PLANS.md` (possible feature roadmap)

## 1. Current Application Flow

On launch, routing now follows this exact flow:

1. Not authenticated -> Login screen
2. Authenticated but no profile in Firestore -> Onboarding screen
3. Authenticated and profile exists -> Main dashboard

## 2. Onboarding Data Contract

A profile is created only after onboarding submit, then saved in `users/{userId}` with:

- `email` (String)
- `displayName` (String)
- `gender` (String)
- `birthdate` (Timestamp)
- `age` (int)
- `stylePreferences` (List<String>)
- `profileImageUrl` (String)
- `createdAt` (Timestamp)

Profile image path:

- `users/{userId}/profile.jpg`

Compression settings:

- max width `500px`
- quality `70%`
- JPEG format

## 3. What Was Tested In Code Today

Code-based test phase completed with:

1. Analyzer checks (`flutter analyze`)
2. Unit tests for business logic including:
   - outfit generation rules
   - recommendation logic
   - caption service
   - onboarding validation and age bounds

## 4. Physical Device Checklist (You Run Tomorrow)

## Auth

1. Open app while signed out -> confirm Login screen appears.
2. Sign up with email/password -> confirm redirect to Onboarding.
3. Sign out, then login with same account -> confirm redirect to Onboarding until profile is complete.
4. Test Google sign-in -> confirm redirect to Onboarding for first-time profile.
5. Test Apple sign-in (iOS only) and Microsoft sign-in -> confirm provider flow + app return.

## Onboarding

1. Submit with missing name -> validation error.
2. Submit with no gender -> validation error.
3. Submit with age <13 or >100 -> validation error.
4. Submit with no style selection -> validation error.
5. Deny camera permission -> friendly snackbar appears (no crash).
6. Deny gallery permission -> friendly snackbar appears (no crash).
7. Complete onboarding with valid data + image -> routes to dashboard.

## Firestore + Storage Verification

1. Confirm Storage file exists at `users/{uid}/profile.jpg`.
2. Confirm `users/{uid}` document appears with expected schema and values.
3. Confirm app restart routes directly to dashboard after profile exists.

## Regression Checks

1. Closet uploads still work.
2. Filters still work.
3. Outfit generator still produces + stores history.
4. Event planner save/recommendations still work.
5. Profile metrics still load.

## 5. Next Phase (AI Scope)

After onboarding + auth is stable on physical devices, next AI phase should focus on:

1. Style DNA personalization model
   - derive user style vectors from profile + wardrobe metadata.
2. Context-aware outfit ranking
   - improve scoring using event context, weather, and user style history.
3. Explainable recommendations
   - human-readable reasoning for every suggested outfit.
4. Feedback loop
   - collect like/dislike signals to adapt ranking over time.

This keeps the system serverless and free-tier compatible by running recommendation logic in-app with Firestore-backed data.
