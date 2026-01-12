import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityState {
  final bool isConnected;
  final bool isChecking;

  ConnectivityState({
    this.isConnected = true,
    this.isChecking = false,
  });

  ConnectivityState copyWith({
    bool? isConnected,
    bool? isChecking,
  }) {
    return ConnectivityState(
      isConnected: isConnected ?? this.isConnected,
      isChecking: isChecking ?? this.isChecking,
    );
  }
}

class ConnectivityNotifier extends StateNotifier<ConnectivityState> {
  ConnectivityNotifier() : super(ConnectivityState()) {
    _checkConnectivity();
    Connectivity().onConnectivityChanged.listen((result) {
      _handleConnectivityChange(result);
    });
  }

  Future<void> _checkConnectivity() async {
    state = state.copyWith(isChecking: true);
    final result = await Connectivity().checkConnectivity();
    _handleConnectivityChange(result);
    state = state.copyWith(isChecking: false);
  }

  void _handleConnectivityChange(dynamic result) {
    bool connected;
    if (result is List) {
      connected = !result.contains(ConnectivityResult.none);
    } else {
      connected = result != ConnectivityResult.none;
    }
    state = state.copyWith(isConnected: connected);
  }

  Future<bool> checkConnection() async {
    await _checkConnectivity();
    return state.isConnected;
  }
}

final connectivityProvider = StateNotifierProvider<ConnectivityNotifier, ConnectivityState>((ref) {
  return ConnectivityNotifier();
});
