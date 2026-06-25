import '../models/map_tag_models.dart';

class MapTagUtils {
  static int? _extractNumber(String text) {
    final match = RegExp(r'\d+').firstMatch(text);
    return match != null ? int.tryParse(match.group(0)!) : null;
  }

  /// 处理和排序标签列表
  /// 合并 Tier 标签时使用 "玩家:Tier" 前缀，
  /// 并将标签按照官方和玩家分类排序。
  static List<MapTagSimple> prepareTags(List<MapTagSimple> rawTags) {
    if (rawTags.length <= 1) return rawTags.toList();

    final officialTags = <MapTagSimple>[];
    final tierTags = <MapTagSimple>[];
    final otherTags = <MapTagSimple>[];

    for (final tag in rawTags) {
      if (tag.isOfficial == true) {
        officialTags.add(tag);
      } else if (tag.isDifficulty == true &&
          tag.difficultyType == 'tier') {
        tierTags.add(tag);
      } else {
        otherTags.add(tag);
      }
    }

    var tags = otherTags;

    if (tierTags.isNotEmpty) {
      tierTags.sort((a, b) {
        final numA = _extractNumber(a.name) ?? 0;
        final numB = _extractNumber(b.name) ?? 0;
        return numA.compareTo(numB);
      });

      final nums = tierTags
          .map((t) => _extractNumber(t.name))
          .whereType<int>()
          .toList();

      String combinedName;
      final prefix = '玩家:Tier';

      if (nums.length == tierTags.length && nums.length > 2) {
        bool isContinuous = true;
        for (int i = 1; i < nums.length; i++) {
          if (nums[i] != nums[i - 1] + 1) {
            isContinuous = false;
            break;
          }
        }
        if (isContinuous) {
          combinedName = '$prefix ${nums.first}~${nums.last}';
        } else {
          combinedName = '$prefix ${nums.join(' ')}';
        }
      } else {
        final parts = tierTags.map(
          (t) =>
              _extractNumber(t.name)?.toString() ??
              t.name.replaceAll('Tier', '').trim(),
        );
        combinedName = '$prefix ${parts.join(' ')}';
      }

      final colorsStr = tierTags
          .map((t) => t.color)
          .whereType<String>()
          .join(',');

      final combinedTag = MapTagSimple(
        name: combinedName,
        color: colorsStr,
        isDifficulty: true,
        difficultyType: 'tier_combined',
        isOfficial: false,
      );
      tags = [combinedTag, ...tags];
    }

    if (officialTags.isNotEmpty) {
      final names = officialTags.expand((t) => t.name.split(',')).map((s) => s.trim()).where((s) => s.isNotEmpty).join('、');
      final combinedOfficialTag = MapTagSimple(
        name: names,
        color: officialTags.first.color,
        isOfficial: true,
      );
      tags = [combinedOfficialTag, ...tags];
    }

    tags.sort((a, b) {
      if (a.isOfficial == true && b.isOfficial != true) return -1;
      if (a.isOfficial != true && b.isOfficial == true) return 1;
      return 0; // 保持原有相对顺序
    });

    return tags;
  }
}
