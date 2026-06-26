import 'dart:async';
import 'dart:convert';
import 'dart:io';

class NetworkDiscovery {
  static const int discoveryPort = 41234;
  static const int timeoutSeconds = 5;

  static Future<String?> discoverServer() async {
    print('🔍 Starting network discovery...');

    // Try methods in order
    final result =
        await _tryBroadcast() ??
            await _tryScanSubnet();

    return result;
  }

  // ── Method 1: UDP Broadcast ──────────────────────────────────────
  static Future<String?> _tryBroadcast() async {
    print('📡 Trying UDP broadcast...');
    RawDatagramSocket? socket;

    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final message = utf8.encode('DISCOVER_SERVER');
      socket.send(message, InternetAddress('255.255.255.255'), discoveryPort);
      socket.send(message, InternetAddress('127.0.0.1'), discoveryPort);

      final completer = Completer<String?>();

      final sub = socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = socket?.receive();
          if (dg != null && !completer.isCompleted) {
            try {
              final json = jsonDecode(utf8.decode(dg.data));
              completer.complete('http://${json['ip']}:${json['port']}/api');
            } catch (_) {}
          }
        }
      });

      final result = await completer.future
          .timeout(const Duration(seconds: 3), onTimeout: () => null);

      await sub.cancel();
      socket.close();

      if (result != null) print('✅ Broadcast found: $result');
      return result;
    } catch (e) {
      print('⚠️ Broadcast failed: $e');
      socket?.close();
      return null;
    }
  }

  // ── Method 2: Subnet Scan ────────────────────────────────────────
  static Future<String?> _tryScanSubnet() async {
    print('🔎 Trying subnet scan...');

    try {
      // Get device's own IP to find subnet
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      String? subnet;
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          // Skip loopback and non-private ranges
          if (ip.startsWith('192.168.') ||
              ip.startsWith('10.') ||
              ip.startsWith('172.')) {
            final parts = ip.split('.');
            subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
            print('📶 Scanning subnet: $subnet.x');
            break;
          }
        }
        if (subnet != null) break;
      }

      if (subnet == null) {
        print('❌ Could not determine subnet');
        return null;
      }

      // Scan all 255 hosts in parallel using UDP
      final completer = Completer<String?>();
      RawDatagramSocket? socket;

      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      // Listen for any response
      final sub = socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = socket?.receive();
          if (dg != null && !completer.isCompleted) {
            try {
              final json = jsonDecode(utf8.decode(dg.data));
              completer.complete('http://${json['ip']}:${json['port']}/api');
            } catch (_) {}
          }
        }
      });

      // Send to every host in subnet
      final message = utf8.encode('DISCOVER_SERVER');
      for (int i = 1; i <= 254; i++) {
        try {
          socket.send(
            message,
            InternetAddress('$subnet.$i'),
            discoveryPort,
          );
        } catch (_) {}
      }

      final result = await completer.future
          .timeout(Duration(seconds: timeoutSeconds), onTimeout: () => null);

      await sub.cancel();
      socket.close();

      if (result != null) print('✅ Subnet scan found: $result');
      else print('❌ Subnet scan: no server found');

      return result;
    } catch (e) {
      print('❌ Subnet scan error: $e');
      return null;
    }
  }
}