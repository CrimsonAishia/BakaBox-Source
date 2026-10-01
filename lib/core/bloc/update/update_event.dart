import 'package:equatable/equatable.dart';
import '../../models/realtime_models.dart';

abstract class UpdateEvent extends Equatable {
  const UpdateEvent();
  @override
  List<Object?> get props => [];
}

class UpdateCheck extends UpdateEvent {}

class UpdateAutoCheck extends UpdateEvent {}

class UpdateDownload extends UpdateEvent {}

class UpdateInstall extends UpdateEvent {}

class UpdateDownloadAndInstall extends UpdateEvent {}

class UpdateOpenAppStore extends UpdateEvent {}

class UpdateClearError extends UpdateEvent {}

class UpdateCancel extends UpdateEvent {}

class UpdateSkip extends UpdateEvent {}

class UpdateReset extends UpdateEvent {}

class UpdateRealtimeEventReceived extends UpdateEvent {
  final RealtimeChannelEvent event;
  const UpdateRealtimeEventReceived(this.event);
  @override
  List<Object?> get props => [event];
}
