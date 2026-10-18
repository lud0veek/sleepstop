import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/active_session_state.dart';

class HeartRatePacket {
  final int bpm;
  final List<int> rrIntervalsMs;

  const HeartRatePacket({required this.bpm, this.rrIntervalsMs = const []});
}

class BleHeartRateService {
  static const String hrServiceUuidString =
      '0000180d-0000-1000-8000-00805f9b34fb';
  static const String hrMeasurementCharUuidString =
      '00002a37-0000-1000-8000-00805f9b34fb';
  static const String genericAccessServiceUuidString =
      '00001800-0000-1000-8000-00805f9b34fb';
  static const String deviceNameCharUuidString =
      '00002a00-0000-1000-8000-00805f9b34fb';

  static final Guid hrServiceGuid = Guid(hrServiceUuidString);
  static final Guid hrMeasurementCharGuid = Guid(hrMeasurementCharUuidString);

  BluetoothDevice? _connectedDevice;
  String? _resolvedWatchName;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _hrCharSubscription;

  final StreamController<int> _bpmStreamController =
      StreamController<int>.broadcast();
  final StreamController<HeartRatePacket> _packetStreamController =
      StreamController<HeartRatePacket>.broadcast();
  final StreamController<List<DiscoveredBleWatch>> _watchesStreamController =
      StreamController<List<DiscoveredBleWatch>>.broadcast();
  final StreamController<String> _connectionStatusController =
      StreamController<String>.broadcast();

  Stream<int> get bpmStream => _bpmStreamController.stream;
  Stream<HeartRatePacket> get packetStream => _packetStreamController.stream;
  Stream<List<DiscoveredBleWatch>> get discoveredWatchesStream =>
      _watchesStreamController.stream;
  Stream<String> get connectionStatusStream =>
      _connectionStatusController.stream;

  BluetoothDevice? get connectedDevice => _connectedDevice;
  String? get resolvedWatchName => _resolvedWatchName;

  /// Parses raw BLE Heart Rate Measurement (0x2A37) payload according to the
  /// official Bluetooth SIG GATT Specification:
  /// - Byte 0: Flags
  ///   - Bit 0 (0x01): Heart Rate Value Format (0 = UINT8, 1 = UINT16 LE)
  ///   - Bit 3 (0x08): Energy Expended Present (2 bytes UINT16 LE if 1)
  ///   - Bit 4 (0x10): RR-Interval Present (one or more UINT16 LE in 1/1024s units)
  static HeartRatePacket? parseHeartRatePacket(List<int> bytes) {
    if (bytes.length < 2) return null;

    final int flags = bytes[0] & 0xFF;
    final bool isUint16 = (flags & 0x01) != 0;
    final bool hasEnergyExpended = (flags & 0x08) != 0;
    final bool hasRrIntervals = (flags & 0x10) != 0;

    int offset = 1;
    int bpm;
    if (!isUint16) {
      bpm = bytes[offset] & 0xFF;
      offset += 1;
    } else {
      if (bytes.length < offset + 2) return null;
      bpm = (bytes[offset] & 0xFF) | ((bytes[offset + 1] & 0xFF) << 8);
      offset += 2;
    }

    if (bpm < 25 || bpm > 240) {
      return null;
    }

    if (hasEnergyExpended) {
      offset += 2;
    }

    final List<int> rrMsList = [];
    if (hasRrIntervals && bytes.length >= offset + 2) {
      while (offset + 1 < bytes.length) {
        final rawRr =
            (bytes[offset] & 0xFF) | ((bytes[offset + 1] & 0xFF) << 8);
        offset += 2;
        // Convert 1/1024s units to milliseconds
        final rrMs = ((rawRr * 1000) / 1024).round();
        if (rrMs >= 250 && rrMs <= 2000) {
          rrMsList.add(rrMs);
        }
      }
    }

    return HeartRatePacket(bpm: bpm, rrIntervalsMs: rrMsList);
  }

  static int? parseHeartRateMeasurement(List<int> bytes) {
    return parseHeartRatePacket(bytes)?.bpm;
  }

  /// Scans for BLE Heart Rate devices (0x180D) and probes already-paired /
  /// connected system BLE devices (such as Garmin watches connected to Garmin Connect).
  Future<BluetoothDevice?> scanAndConnect({
    String? preferredDeviceId,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    await stopScan();

    final Map<String, DiscoveredBleWatch> discoveredMap = {};
    final Map<String, BluetoothDevice> deviceObjects = {};

    try {
      final systemDevs = await FlutterBluePlus.systemDevices([hrServiceGuid]);
      final bondedDevs = await FlutterBluePlus.bondedDevices;

      final List<BluetoothDevice> priorityCandidates = [];
      final Set<String> seenIds = {};

      for (final d in [...systemDevs, ...bondedDevs]) {
        final id = d.remoteId.str;
        if (seenIds.add(id)) {
          final lowerName = d.platformName.toLowerCase();
          if (lowerName.contains('powerbeats') ||
              lowerName.contains('bmw') ||
              lowerName.contains('jbl') ||
              lowerName.contains('airpods') ||
              lowerName.contains('buds') ||
              lowerName.contains('loudof')) {
            continue;
          }
          priorityCandidates.add(d);
          deviceObjects[id] = d;
          discoveredMap[id] = DiscoveredBleWatch(
            id: id,
            name: d.platformName.isNotEmpty
                ? d.platformName
                : 'Garmin / BLE Watch ($id)',
            rssi: -45,
            advertisesHrService: true,
          );
        }
      }

      if (discoveredMap.isNotEmpty) {
        _watchesStreamController.add(discoveredMap.values.toList());
      }

      priorityCandidates.sort((a, b) {
        if (preferredDeviceId != null) {
          if (a.remoteId.str == preferredDeviceId) return -1;
          if (b.remoteId.str == preferredDeviceId) return 1;
        }
        final aInSys = systemDevs.any((d) => d.remoteId == a.remoteId);
        final bInSys = systemDevs.any((d) => d.remoteId == b.remoteId);
        if (aInSys != bInSys) return aInSys ? -1 : 1;
        return 0;
      });

      for (final candidate in priorityCandidates) {
        debugPrint(
          '[SleepStop BLE] Probing bonded/system candidate: ${candidate.remoteId.str} (${candidate.platformName})',
        );
        final ok = await connectToDevice(candidate);
        if (ok) {
          return candidate;
        }
      }
    } catch (e) {
      debugPrint('[SleepStop BLE] System/bonded lookup error: $e');
    }

    _connectionStatusController.add(
      'Scanning BLE airwaves for 0x180D Heart Rate broadcast...',
    );
    final Completer<BluetoothDevice?> scanMatchCompleter =
        Completer<BluetoothDevice?>();

    _scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
      for (final result in results) {
        final device = result.device;
        final id = device.remoteId.str;
        final advName = result.advertisementData.advName;
        final platformName = device.platformName;
        final name = advName.isNotEmpty
            ? advName
            : (platformName.isNotEmpty ? platformName : '');

        final serviceUuids = result.advertisementData.serviceUuids;
        final hasHrUuid = serviceUuids.any(
          (u) =>
              u == hrServiceGuid ||
              u.str.toLowerCase() == '180d' ||
              u.str.toLowerCase() == hrServiceUuidString,
        );

        final hasGarminMfg = result.advertisementData.manufacturerData
            .containsKey(0x0087);
        final isKnownWearableName = _looksLikeHeartRateWatch(name);

        if (!hasHrUuid &&
            !hasGarminMfg &&
            !isKnownWearableName &&
            id != preferredDeviceId) {
          continue;
        }

        final displayName = name.isNotEmpty ? name : 'BLE HR Watch ($id)';
        deviceObjects[id] = device;
        discoveredMap[id] = DiscoveredBleWatch(
          id: id,
          name: displayName,
          rssi: result.rssi,
          advertisesHrService: hasHrUuid,
        );

        final sortedList = discoveredMap.values.toList()
          ..sort((a, b) {
            if (a.advertisesHrService != b.advertisesHrService) {
              return a.advertisesHrService ? -1 : 1;
            }
            return b.rssi.compareTo(a.rssi);
          });
        _watchesStreamController.add(sortedList);

        if (hasHrUuid ||
            hasGarminMfg ||
            (preferredDeviceId != null && id == preferredDeviceId)) {
          if (!scanMatchCompleter.isCompleted) {
            scanMatchCompleter.complete(device);
          }
        }
      }
    });

    try {
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: false,
        androidCheckLocationServices: false,
      );
    } catch (e) {
      debugPrint('[SleepStop BLE] startScan error: $e');
    }

    BluetoothDevice? scannedDevice;
    try {
      scannedDevice = await scanMatchCompleter.future.timeout(
        timeout,
        onTimeout: () => null,
      );
    } catch (_) {
      scannedDevice = null;
    }

    await stopScan();

    if (scannedDevice != null) {
      final ok = await connectToDevice(scannedDevice);
      if (ok) return scannedDevice;
    }

    return null;
  }

  Future<bool> connectToDevice(BluetoothDevice device) async {
    await disconnect();

    try {
      final initialLabel = device.platformName.isNotEmpty
          ? device.platformName
          : device.remoteId.str;
      _connectionStatusController.add('Connecting to $initialLabel...');

      await device.connect(
        license: License.nonprofit,
        mtu: null,
        timeout: const Duration(seconds: 8),
        autoConnect: false,
      );
      _connectedDevice = device;

      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _connectionStatusController.add('Watch disconnected');
        }
      });

      List<BluetoothService> services = await device.discoverServices(
        subscribeToServicesChanged: false,
        timeout: 8,
      );

      BluetoothCharacteristic? hrCharacteristic = _findHrCharacteristic(
        services,
      );

      if (hrCharacteristic == null) {
        try {
          await device.clearGattCache();
          await Future<void>.delayed(const Duration(milliseconds: 500));
          services = await device.discoverServices(
            subscribeToServicesChanged: false,
            timeout: 8,
          );
          hrCharacteristic = _findHrCharacteristic(services);
        } catch (_) {}
      }

      if (hrCharacteristic == null) {
        await disconnect();
        return false;
      }

      String watchName = device.platformName.trim();
      if (watchName.isEmpty) {
        watchName =
            await _readGattDeviceName(services) ??
            'Garmin Watch (${device.remoteId.str})';
      }
      _resolvedWatchName = watchName;

      await hrCharacteristic.setNotifyValue(true);
      _hrCharSubscription = hrCharacteristic.onValueReceived.listen((bytes) {
        final packet = parseHeartRatePacket(bytes);
        if (packet != null) {
          _bpmStreamController.add(packet.bpm);
          _packetStreamController.add(packet);
        }
      });

      if (hrCharacteristic.properties.read) {
        try {
          final initialBytes = await hrCharacteristic.read();
          final packet = parseHeartRatePacket(initialBytes);
          if (packet != null) {
            _bpmStreamController.add(packet.bpm);
            _packetStreamController.add(packet);
          }
        } catch (_) {}
      }

      _connectionStatusController.add(
        'Connected to $watchName • Live Biometrics (0x2A37)',
      );
      return true;
    } catch (e) {
      _connectionStatusController.add('BLE Error: $e');
      await disconnect();
      return false;
    }
  }

  BluetoothCharacteristic? _findHrCharacteristic(
    List<BluetoothService> services,
  ) {
    for (final service in services) {
      final serviceUuid = service.uuid.str.toLowerCase();
      if (service.uuid == hrServiceGuid ||
          serviceUuid == '180d' ||
          serviceUuid == hrServiceUuidString) {
        for (final characteristic in service.characteristics) {
          final charUuid = characteristic.uuid.str.toLowerCase();
          if (characteristic.uuid == hrMeasurementCharGuid ||
              charUuid == '2a37' ||
              charUuid == hrMeasurementCharUuidString) {
            return characteristic;
          }
        }
      }
    }
    return null;
  }

  Future<String?> _readGattDeviceName(List<BluetoothService> services) async {
    try {
      for (final service in services) {
        final suuid = service.uuid.str.toLowerCase();
        if (suuid == '1800' || suuid == genericAccessServiceUuidString) {
          for (final c in service.characteristics) {
            final cuuid = c.uuid.str.toLowerCase();
            if (cuuid == '2a00' || cuuid == deviceNameCharUuidString) {
              if (c.properties.read) {
                final bytes = await c.read(timeout: 3);
                final decoded = utf8
                    .decode(bytes, allowMalformed: true)
                    .replaceAll('\u0000', '')
                    .trim();
                if (decoded.isNotEmpty) {
                  return decoded;
                }
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  bool _looksLikeHeartRateWatch(String name) {
    if (name.isEmpty) return false;
    final lower = name.toLowerCase();
    const keywords = [
      'garmin',
      'forerunner',
      'fenix',
      'epix',
      'venu',
      'vivoactive',
      'instinct',
      'lily',
      'marq',
      'enduro',
      'approach',
      'quatix',
      'tactix',
      'polar',
      'wahoo',
      'tickr',
      'whoop',
      'coros',
      'suunto',
      'hrm',
      'heart',
    ];
    return keywords.any(lower.contains);
  }

  Future<void> stopScan() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
    } catch (_) {}
  }

  Future<void> disconnect() async {
    await stopScan();
    await _hrCharSubscription?.cancel();
    _hrCharSubscription = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;

    final dev = _connectedDevice;
    _connectedDevice = null;
    if (dev != null) {
      try {
        await dev.disconnect();
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    await disconnect();
    await _bpmStreamController.close();
    await _packetStreamController.close();
    await _watchesStreamController.close();
    await _connectionStatusController.close();
  }
}
