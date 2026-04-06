# Digital Lesela Sete (DLS) - Flutter MVP

This repository currently runs a **Sprint 1** implementation focused on one flow only:

- take/select photo
- compress image
- upload image to Firebase Storage
- save metadata in Firestore
- display uploaded items in a grid

For full chronological documentation from project start to now, read:

- `PROJECT_HISTORY.md`

## Current Sprint Scope

Implemented now:

1. Image capture from camera and gallery
2. Preview before upload
3. Compression before upload (`1080px`, JPEG, quality `70`)
4. Storage upload to `clothing_items/{uuid}.jpg`
5. Firestore metadata write to `clothing_items`
6. Dashboard grid with stream updates, loading/empty/error states

## Main Sprint Files

- `lib/services/firebase_service.dart`
- `lib/views/upload_screen.dart`
- `lib/views/wardrobe_dashboard.dart`
- `lib/app.dart` (sprint entry)

## Tech Stack (Sprint 1)

- Flutter
- Firebase Core
- Cloud Firestore
- Firebase Storage
- image_picker
- flutter_image_compress
- uuid
- permission_handler

## Setup

1. Install Flutter + Firebase CLI + FlutterFire CLI.
2. Install dependencies:

   ```bash
   flutter pub get
   ```

3. Configure Firebase for project **Digital Les Sete**:

   ```bash
   flutterfire configure
   ```

4. Run app:

   ```bash
   flutter run
   ```

## Firestore Collection Used in Sprint 1

Collection: `clothing_items`

Document fields:

- `id` (String)
- `category` (default `shirt`)
- `status` (default `clean`)
- `imageUrl` (String)
- `createdAt` (server timestamp)

## Manual Configuration Still Needed

1. Firebase project linkage (`flutterfire configure`) with real values in `lib/firebase_options.dart`
2. Firestore and Storage rules for production-safe access
3. Platform permission entries (Android/iOS) if building on mobile devices

