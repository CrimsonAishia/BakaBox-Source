import 'package:equatable/equatable.dart';

class GuideTagSuggestState extends Equatable {
  final List<String> suggestions;

  const GuideTagSuggestState({this.suggestions = const []});

  GuideTagSuggestState copyWith({List<String>? suggestions}) {
    return GuideTagSuggestState(suggestions: suggestions ?? this.suggestions);
  }

  @override
  List<Object?> get props => [suggestions];
}
