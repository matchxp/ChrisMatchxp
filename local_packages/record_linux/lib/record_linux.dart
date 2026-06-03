import 'dart:async';
import 'dart:typed_data';
import 'package:record_platform_interface/record_platform_interface.dart';

/// Stub Linux implementation that satisfies record_platform_interface 1.5.x.
/// Linux recording is not used in this app — this stub prevents compilation
/// errors caused by the outdated pub.dev record_linux 0.7.2 package.
class RecordLinux extends RecordPlatform {
  static void registerWith() {
    RecordPlatform.instance = RecordLinux();
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  Future<void> create(String recorderId) async {}

  @override
  Future<void> dispose(String recorderId) async {}

  // ── State queries ──────────────────────────────────────────────────────────
  @override
  Future<Amplitude> getAmplitude(String recorderId) async =>
      Amplitude(current: -160.0, max: -160.0);   // not const — Amplitude has no const ctor

  @override
  Future<bool> hasPermission(String recorderId, {bool request = true}) async =>
      false;

  @override
  Future<bool> isPaused(String recorderId) async => false;

  @override
  Future<bool> isRecording(String recorderId) async => false;

  // ── Encoder / device info ──────────────────────────────────────────────────
  @override
  Future<bool> isEncoderSupported(
      String recorderId, AudioEncoder encoder) async => false;

  @override
  Future<List<InputDevice>> listInputDevices(String recorderId) async => [];

  // ── Recording control ──────────────────────────────────────────────────────
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
  ) async => const Stream<Uint8List>.empty();

  @override
  Future<void> pause(String recorderId) async {}

  @override
  Future<void> resume(String recorderId) async {}

  @override
  Future<void> cancel(String recorderId) async {}

  @override
  Future<String?> stop(String recorderId) async => null;

  // ── State stream ───────────────────────────────────────────────────────────
  @override
  Stream<RecordState> onStateChanged(String recorderId) =>
      const Stream<RecordState>.empty();
}
