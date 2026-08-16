import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/sync/sync_engine.dart';

enum SyncPhase { idle, running, success, error }

class SyncControllerState {
  const SyncControllerState({required this.phase, this.outcome, this.message});

  const SyncControllerState.idle() : this(phase: SyncPhase.idle);

  final SyncPhase phase;
  final SyncOutcome? outcome;
  final String? message;
}

class SyncController extends StateNotifier<SyncControllerState> {
  SyncController(this._engine) : super(const SyncControllerState.idle());

  final SyncEngine _engine;

  Future<void> synchronize() async {
    if (state.phase == SyncPhase.running) {
      return;
    }
    state = const SyncControllerState(phase: SyncPhase.running);
    try {
      final outcome = await _engine.synchronize();
      state = SyncControllerState(phase: SyncPhase.success, outcome: outcome);
    } on Object catch (error) {
      state = SyncControllerState(
        phase: SyncPhase.error,
        message: error.toString(),
      );
      rethrow;
    }
  }
}
