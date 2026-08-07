import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NetworkStatusNotifier extends StateNotifier<bool> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _periodicCheckTimer;
  Timer? _offlineDebounceTimer;

  NetworkStatusNotifier() : super(true) {
    _init();
  }

  void _init() {
    _checkRealConnection();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final hasConnection = results.isNotEmpty &&
          results.any((r) => r != ConnectivityResult.none);

      if (hasConnection) {
        // Connection restored — cancel any pending offline debounce & go online immediately
        _offlineDebounceTimer?.cancel();
        _offlineDebounceTimer = null;
        if (state != true) state = true;
      } else {
        // Connectivity reports "none" — debounce for 3 seconds before marking offline.
        // This absorbs brief blips caused by app switching on Android/iOS.
        _offlineDebounceTimer?.cancel();
        _offlineDebounceTimer = Timer(const Duration(seconds: 3), () {
          _checkRealConnection();
        });
      }
    });

    // Periodic check every 30 seconds to ensure continuous monitoring
    _periodicCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkRealConnection();
    });
  }

  Future<bool> checkRealConnection() async {
    // Cancel any pending debounce — the user explicitly pressed retry
    _offlineDebounceTimer?.cancel();
    _offlineDebounceTimer = null;
    return await _checkRealConnection();
  }

  Future<bool> _checkRealConnection() async {
    // 1. Web Platform Guard
    if (kIsWeb) {
      if (state != true) state = true;
      return true;
    }

    // 2. Mobile & Desktop Interface Check
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
        if (state != false) state = false;
        return false;
      }

      // If interface (Wi-Fi, Mobile Data, Ethernet, VPN) is connected, mark online
      if (state != true) state = true;
      return true;
    } catch (_) {
      if (state != true) state = true;
      return true;
    }
  }

  void markOffline() {
    if (state != false) state = false;
  }

  void markOnline() {
    if (state != true) state = true;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _periodicCheckTimer?.cancel();
    _offlineDebounceTimer?.cancel();
    super.dispose();
  }
}

final networkStatusProvider = StateNotifierProvider<NetworkStatusNotifier, bool>((ref) {
  return NetworkStatusNotifier();
});

