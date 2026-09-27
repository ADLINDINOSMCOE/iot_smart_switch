import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = true;
  bool _isInitialized = false;

  final StreamController<bool> _networkStatusController = StreamController<bool>.broadcast();

  bool get isOnline => _isOnline;
  Stream<bool> get networkStatus => _networkStatusController.stream;

  // =========================================================
  // INITIALIZE NETWORK MONITORING
  // =========================================================
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check initial connectivity status
      final results = await _connectivity.checkConnectivity();
      _isOnline = _isConnected(results);
      _networkStatusController.add(_isOnline);

      // Listen to connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        (List<ConnectivityResult> results) {
          final wasOnline = _isOnline;
          _isOnline = _isConnected(results);

          if (wasOnline != _isOnline) {
            _networkStatusController.add(_isOnline);
            if (kDebugMode) {
              print('Network status changed: ${_isOnline ? "Online" : "Offline"}');
            }
          }
        },
      );

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing network service: $e');
      // Assume online if we can't determine status
      _isOnline = true;
      _networkStatusController.add(_isOnline);
    }
  }

  // =========================================================
  // CHECK IF CONNECTED
  // =========================================================
  bool _isConnected(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  // =========================================================
  // CHECK CURRENT STATUS
  // =========================================================
  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _isOnline = _isConnected(results);
      _networkStatusController.add(_isOnline);
      return _isOnline;
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return true; // Assume online on error
    }
  }

  // =========================================================
  // DISPOSE
  // =========================================================
  void dispose() {
    _connectivitySubscription?.cancel();
    _networkStatusController.close();
  }

  // =========================================================
  // HANDLE NETWORK ERROR
  // =========================================================
  String getNetworkErrorMessage(dynamic error) {
    if (!_isOnline) {
      return 'No internet connection. Please check your network settings.';
    }

    if (error.toString().contains('network-request-failed') ||
        error.toString().contains('Connection failed')) {
      return 'Network connection failed. Please try again.';
    }

    if (error.toString().contains('timeout')) {
      return 'Request timed out. Please check your connection.';
    }

    return 'Network error occurred. Please try again.';
  }

  // =========================================================
  // WRAPPER FOR NETWORK-AWARE OPERATIONS
  // =========================================================
  Future<T> executeWithNetworkCheck<T>(
    Future<T> Function() operation, {
    String? errorMessage,
  }) async {
    if (!await checkConnectivity()) {
      throw Exception(getNetworkErrorMessage('offline'));
    }

    try {
      return await operation();
    } catch (e) {
      if (getNetworkErrorMessage(e) != errorMessage) {
        throw Exception(getNetworkErrorMessage(e));
      }
      rethrow;
    }
  }
}