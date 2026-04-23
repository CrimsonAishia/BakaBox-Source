import 'package:equatable/equatable.dart';

class FloatingChatState extends Equatable {
  final int unreadCount;
  final bool isPanelOpen;
  final int lastSeenMessageCount;

  const FloatingChatState({
    this.unreadCount = 0,
    this.isPanelOpen = false,
    this.lastSeenMessageCount = 0,
  });

  FloatingChatState copyWith({
    int? unreadCount,
    bool? isPanelOpen,
    int? lastSeenMessageCount,
  }) {
    return FloatingChatState(
      unreadCount: unreadCount ?? this.unreadCount,
      isPanelOpen: isPanelOpen ?? this.isPanelOpen,
      lastSeenMessageCount: lastSeenMessageCount ?? this.lastSeenMessageCount,
    );
  }

  @override
  List<Object?> get props => [unreadCount, isPanelOpen, lastSeenMessageCount];
}
