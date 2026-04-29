import 'dart:convert';

import 'package:dls_app/models/clothing_item.dart';
import 'package:dls_app/models/outfit_result.dart';
import 'package:dls_app/services/virtual_tryon_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  ClothingItem item(String id, String categoryType, String subcategory) {
    final now = DateTime(2026, 1, 1);
    return ClothingItem(
      id: id,
      parentCategory: 'Test',
      subcategory: subcategory,
      categoryType: categoryType,
      color: 'black',
      colorGroup: 'neutral',
      styleTags: const <String>['casual'],
      season: 'All Season',
      status: 'clean',
      gender: 'Unisex',
      imageUrl: 'https://example.com/$id.jpg',
      userId: 'u1',
      createdAt: now,
      updatedAt: now,
    );
  }

  OutfitResult validResult() {
    return OutfitResult(
      top: item('top', 'top', 'shirt'),
      bottom: item('bottom', 'bottom', 'trousers'),
      shoes: item('shoes', 'shoes', 'sneakers'),
      accessory: null,
      score: 80,
      reasoning: const <String>['test'],
    );
  }

  test('reads nested result.image_url response', () async {
    final service = VirtualTryOnService(
      endpointOverride: 'https://tryon.example.com/render',
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'result': {'image_url': 'https://cdn.example.com/tryon.png'},
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final url = await service.generateTryOnImage(
      result: validResult(),
      mood: 'Street Flex',
      occasion: 'Braai',
      weather: 'Sunny',
    );

    expect(url, 'https://cdn.example.com/tryon.png');
  });

  test('returns null when response has no image url', () async {
    final service = VirtualTryOnService(
      endpointOverride: 'https://tryon.example.com/render',
      client: MockClient((request) async {
        return http.Response(jsonEncode({'ok': true}), 200);
      }),
    );

    final url = await service.generateTryOnImage(
      result: validResult(),
    );

    expect(url, isNull);
  });
}
