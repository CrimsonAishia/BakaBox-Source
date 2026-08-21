import 'package:equatable/equatable.dart';

class ActivityModel extends Equatable {
  final int id;
  final String title;
  final String description;
  final String bannerUrl;
  final String content;
  final int startTime;
  final int? endTime;
  final bool isPinned;
  final bool isActive;
  final List<String> serverAddresses;

  const ActivityModel({
    required this.id,
    required this.title,
    required this.description,
    required this.bannerUrl,
    required this.content,
    required this.startTime,
    this.endTime,
    required this.isPinned,
    required this.isActive,
    required this.serverAddresses,
  });

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      bannerUrl: json['bannerUrl'] as String? ?? '',
      content: json['content'] as String? ?? '',
      startTime: json['startTime'] as int? ?? 0,
      endTime: json['endTime'] as int?,
      isPinned: json['isPinned'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? false,
      serverAddresses:
          (json['serverAddresses'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    bannerUrl,
    content,
    startTime,
    endTime,
    isPinned,
    isActive,
    serverAddresses,
  ];
}
