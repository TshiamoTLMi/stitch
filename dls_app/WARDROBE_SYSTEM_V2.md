# Digital Lesela Sete: Advanced Wardrobe System v2

## Objective
Upgrade the clothing upload flow to a structured taxonomy with cascading UI logic and generator compatibility.

## Firestore Schema (clothing_items)

```json
{
  "userId": "String",
  "parentCategory": "String",
  "subcategory": "String",
  "categoryType": "String",
  "fit": "String?",
  "color": "String",
  "colorGroup": "String",
  "styleTags": ["String"],
  "season": "String",
  "status": "String",
  "gender": "String",
  "imageUrl": "String",
  "createdAt": "Timestamp"
}
```

## Implemented Taxonomy
The taxonomy map is implemented in:
- lib/core/constants/wardrobe_taxonomy.dart

Includes:
- Parent category -> subcategory cascade
- Fit options and conditional fit requirement
- CategoryType mapping for generator
- Color group mapping for neutral/dark/light/bright

## Upload UI Behavior
Implemented in:
- lib/views/upload_screen.dart

Behavior:
- Parent Category dropdown
- Subcategory dropdown filtered by parent
- Reset subcategory and fit when parent changes
- Fit field appears only for Jeans/Trousers/Blazers

Validation:
- parentCategory required
- subcategory required
- fit required when applicable
- at least 1 style tag required
- status required

## Image Handling
Implemented in:
- lib/services/firebase_service.dart

Rules:
- Compression via flutter_image_compress
- max width: 1080
- quality: 70
- format: JPEG
- upload path: users/{userId}/items/{timestamp}_{uuid}.jpg

## Generator Compatibility
Implemented in:
- lib/services/outfit_bot_service.dart
- lib/services/recommendation_service.dart

Rules:
- Uses categoryType as primary routing key
- Uses only clean items
- Keeps scoring + fallback behavior
- Legacy category fallback still supported for old records

## Firestore Indexes
Declared in:
- firestore.indexes.json

Required indexes:
- userId + status
- userId + parentCategory
- userId + styleTags

Deploy indexes:
- firebase deploy --only firestore:indexes

## Migration Note
During migration, code also writes legacy keys (user_id, style_tags, image_url, category) so existing screens continue to work while backend transitions to the new schema.
