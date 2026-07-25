import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';

final networkProvider =
    StateNotifierProvider<NetworkNotifier, NetworkState>((ref) {
  final notifier = NetworkNotifier();
  // Register with ApiClient so every request automatically updates the state.
  ApiClient.addNetworkCallback(({required success, errorMessage}) {
    if (success) {
      notifier.setConnected();
    } else {
      notifier.setDisconnected(message: errorMessage);
    }
  });
  return notifier;
});

enum NetworkStatus { connected, disconnected, checking }

class NetworkState {
  final NetworkStatus status;
  final String? errorMessage;

  const NetworkState({
    this.status = NetworkStatus.connected,
    this.errorMessage,
  });

  bool get isOnline => status == NetworkStatus.connected;
}

class NetworkNotifier extends StateNotifier<NetworkState> {
  NetworkNotifier() : super(const NetworkState());

  void setConnected() =>
      state = const NetworkState(status: NetworkStatus.connected);
  void setDisconnected({String? message}) =>
      state = NetworkState(status: NetworkStatus.disconnected, errorMessage: message);
}
