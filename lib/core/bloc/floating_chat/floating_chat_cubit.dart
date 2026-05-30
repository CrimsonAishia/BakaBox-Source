import 'package:bloc/bloc.dart';

import '../../models/lobby_models.dart';
import 'floating_chat_state.dart';

class FloatingChatCubit extends Cubit<FloatingChatState> {
  List<LobbyMessage> _currentMessages = [];

  /// True after the first [onMessagesChanged] call.
  /// The very first batch is always historical — treat it as the baseline
  /// so those messages are never counted as unread.
  bool _initialized = false;

  FloatingChatCubit() : super(const FloatingChatState());

  /// Called when the messages list changes (driven by BlocListener).
  void onMessagesChanged(List<LobbyMessage> messages) {
    // Exclude local optimistic messages so self-sent messages don't inflate
    // the unread count before the server echo arrives.
    final serverMessages = messages
        .where((m) => !m.messageId.startsWith('local_'))
        .toList();
    _currentMessages = serverMessages;

    // First call: treat all existing messages as already seen — they are
    // historical messages loaded on startup, not new incoming messages.
    if (!_initialized) {
      _initialized = true;
      emit(
        state.copyWith(
          unreadCount: 0,
          lastSeenMessageCount: serverMessages.length,
        ),
      );
      return;
    }

    if (state.isPanelOpen) {
      // Panel is open: keep unreadCount at 0, just update lastSeenMessageCount
      emit(
        state.copyWith(
          unreadCount: 0,
          lastSeenMessageCount: serverMessages.length,
        ),
      );
    } else {
      // Panel is closed: accumulate delta
      final delta = serverMessages.length - state.lastSeenMessageCount;
      if (delta > 0) {
        emit(
          state.copyWith(
            unreadCount: state.unreadCount + delta,
            lastSeenMessageCount: serverMessages.length,
          ),
        );
      } else if (delta < 0) {
        // Message count shrank (e.g. deduplication removed a local_ message).
        // Sync the baseline so the next real message produces delta = 1,
        // not an inflated value.
        emit(state.copyWith(lastSeenMessageCount: serverMessages.length));
      }
    }
  }

  /// Called when the chat panel is opened.
  void panelOpened() {
    emit(
      state.copyWith(
        isPanelOpen: true,
        unreadCount: 0,
        lastSeenMessageCount: _currentMessages.length,
      ),
    );
  }

  /// Called when the chat panel is closed.
  void panelClosed() {
    emit(state.copyWith(isPanelOpen: false));
  }

  /// Called when the user navigates to the lobby page.
  void onLobbyPageEntered() {
    emit(
      state.copyWith(
        unreadCount: 0,
        lastSeenMessageCount: _currentMessages.length,
      ),
    );
  }
}
