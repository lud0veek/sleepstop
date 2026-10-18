import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_stop/main.dart';
import 'package:sleep_stop/services/ble_heart_rate_service.dart';
import 'package:sleep_stop/services/motion_detector_service.dart';

void main() {
  group('Bluetooth SIG 0x2A37 Heart Rate & R-R Parser', () {
    test('parses UINT8 heart rate format when flag bit 0 is 0', () {
      final bpm = BleHeartRateService.parseHeartRateMeasurement([0x06, 54]);
      expect(bpm, 54);
    });

    test('parses UINT16 little-endian heart rate format when flag bit 0 is 1', () {
      final bpm = BleHeartRateService.parseHeartRateMeasurement([
        0x01,
        0x3B,
        0x00,
      ]);
      expect(bpm, 59);
    });

    test('parses R-R intervals when flag bit 4 (0x10) is set', () {
      // Flags = 0x10 (UINT8 BPM + RR-Interval present), BPM = 60, RR = 1024 (1000ms)
      final packet = BleHeartRateService.parseHeartRatePacket([
        0x10,
        60,
        0x00,
        0x04,
      ]);
      expect(packet, isNotNull);
      expect(packet!.bpm, 60);
      expect(packet.rrIntervalsMs, [1000]);
    });

    test('returns null on malformed or out-of-range payloads', () {
      expect(BleHeartRateService.parseHeartRateMeasurement([]), isNull);
      expect(BleHeartRateService.parseHeartRateMeasurement([0x01, 50]), isNull);
      expect(BleHeartRateService.parseHeartRateMeasurement([0x00, 10]), isNull);
    });
  });

  group('Accelerometer 3D Magnitude Math', () {
    test('computes Euclidean vector length accurately', () {
      final mag = MotionDetectorService.calculateMagnitude(3.0, 4.0, 0.0);
      expect(mag, closeTo(5.0, 1e-6));
    });
  });

  testWidgets('SleepStopApp renders cleanly even on narrow Fold cover screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: SleepStopApp()));
    await tester.pump();

    expect(find.text('SleepStop'), findsOneWidget);
    expect(find.text('Montre (BLE)'), findsOneWidget);
    expect(find.text('Démarrer la veille'), findsOneWidget);
  });
}
