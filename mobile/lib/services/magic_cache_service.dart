import "dart:convert";
import 'dart:math';

import "package:logging/logging.dart";
import "package:photos/services/machine_learning/semantic_search/semantic_search_service.dart";
import "package:shared_preferences/shared_preferences.dart";

const _promptsJson = {
  "prompts": [
    {
      "prompt": "identity document",
      "title": "Identity Document",
      "minimumScore": 0.269,
      "minimumSize": 0.0,
    },
    {
      "prompt": "sunset at the beach",
      "title": "Sunset",
      "minimumScore": 0.25,
      "minimumSize": 0.0,
    },
    {
      "prompt": "roadtrip",
      "title": "Roadtrip",
      "minimumScore": 0.26,
      "minimumSize": 0.0,
    },
    {
      "prompt": "pizza pasta burger",
      "title": "Food",
      "minimumScore": 0.27,
      "minimumSize": 0.0,
    }
  ],
};

class MagicCache {
  final String title;
  final List<int> fileUploadedIDs;
  MagicCache(this.title, this.fileUploadedIDs);

  factory MagicCache.fromJson(Map<String, dynamic> json) {
    return MagicCache(
      json['title'],
      List<int>.from(json['fileUploadedIDs']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'fileUploadedIDs': fileUploadedIDs,
    };
  }

  static String encodeListToJson(List<MagicCache> magicCaches) {
    final jsonList = magicCaches.map((cache) => cache.toJson()).toList();
    return jsonEncode(jsonList);
  }

  static List<MagicCache> decodeJsonToList(String jsonString) {
    final jsonList = jsonDecode(jsonString) as List;
    return jsonList.map((json) => MagicCache.fromJson(json)).toList();
  }
}

class MagicCacheService {
  static const _key = "magic_cache";
  late SharedPreferences prefs;
  final Logger _logger = Logger((MagicCacheService).toString());
  MagicCacheService._privateConstructor();

  static final MagicCacheService instance =
      MagicCacheService._privateConstructor();

  void init(SharedPreferences preferences) {
    prefs = preferences;
  }

  List<Map<String, Object>> getRandomPrompts() {
    final promptsJson = _promptsJson["prompts"];
    final randomPrompts = <Map<String, Object>>[];
    final randomNumbers =
        _generateUniqueRandomNumbers(promptsJson!.length - 1, 4);
    for (int i = 0; i < randomNumbers.length; i++) {
      randomPrompts.add(promptsJson[randomNumbers[i]]);
    }

    return randomPrompts;
  }

  Future<Map<String, List<int>>> getMatchingFileIDsForPromptData(
    Map<String, Object> promptData,
  ) async {
    final result = await SemanticSearchService.instance.getMatchingFileIDs(
      promptData["prompt"] as String,
      promptData["minimumScore"] as double,
    );

    return {promptData["title"] as String: result};
  }

  Future<void> updateMagicCache(List<MagicCache> magicCaches) async {
    await prefs.setString(
      _key,
      MagicCache.encodeListToJson(magicCaches),
    );
  }

  Future<List<MagicCache>?> getMagicCache() async {
    final jsonString = prefs.getString(_key);
    if (jsonString == null) {
      return null;
    }
    return MagicCache.decodeJsonToList(jsonString);
  }

  Future<void> clearMagicCache() async {
    await prefs.remove(_key);
  }

  ///Generates from 0 to max unique random numbers
  List<int> _generateUniqueRandomNumbers(int max, int count) {
    final numbers = <int>[];
    for (int i = 1; i <= count;) {
      final randomNumber = Random().nextInt(max + 1);
      if (numbers.contains(randomNumber)) {
        continue;
      }
      numbers.add(randomNumber);
      i++;
    }
    return numbers;
  }
}
