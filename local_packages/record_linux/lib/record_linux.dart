import 'dart:typed_data';
import 'package:record_platform_interface/record_platform_interface.dart';

/// Stub Linux implementation that satisfies record_platform_interface 1.5.x.
/// Linux recording is not used in this app — this stub prevents compilation
/// errors caused by the outdated pub.dev record_linux 0.7.2 package.
class RecordLinux extends RecordPlatform {
  static void registerWith() {
    RecordPlatform.instance = RecordLinux();
  }

  @override
  Future<void> create(String recorderId) async {}

  @override
  Future<void> dispose(String recorderId) async {}

  @override
  Future<Amplitude> getAmplitude(String recorderId) async {
    return const Amplitude(current: -160.0, max: -160.0);
  }

  @override
  Future<bool> hasPermission(String recorderId, {bool request = true}) async =>
      false;

  @override
  Future<bool> isPaused(String recorderId) async => false;

  @override
  Future<bool> isRecording(String recorderId) async => false;

  @override
  Future<void> pause(String recorderId) async {}

  @override
  Future<void> resume(String recorderId) async {}

  @override
  Future<void> start(
    String recorderId,
    RecordConfig config, {
    required String path,
  }) async {}

  @override
  Future<Stream<Uint8List>> startStream(
    String recorderId,
    RecordConfig config,
  ) async {
    return Stream<Uint8List>.empty();
  }

  @override
  Future<String?> stop(String recorderId) async => null;
}
