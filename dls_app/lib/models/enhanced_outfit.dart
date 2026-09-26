import 'outfit.dart';

class EnhancedOutfit {
  const EnhancedOutfit({
    required this.outfit,
    required this.reason,
    this.swapSuggestion,
    this.usedAi = true,
  });

  final Outfit outfit;
  final String reason;
  final String? swapSuggestion;
  final bool usedAi;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'outfit': outfit.toJson(),
        'reason': reason,
        'swapSuggestion': swapSuggestion,
        'usedAi': usedAi,
      };
}
