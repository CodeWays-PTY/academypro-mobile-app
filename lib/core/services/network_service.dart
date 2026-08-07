import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Minimal network status — only set to offline when actual API calls fail.
/// No proactive checking, no connectivity_plus listener, no HTTP pinging.
class NetworkStatusNotifier extends StateNotifier<bool> {
  NetworkStatusNotifier() : super(true);

  void markOffline() {
    if (state != false) state = false;
  }

  void markOnline() {
    if (state != true) state = true;
  }

  Future<bool> checkRealConnection() async {
    state = true;
    return true;
  }
}

final networkStatusProvider = StateNotifierProvider<NetworkStatusNotifier, bool>((ref) {
  return NetworkStatusNotifier();
});

