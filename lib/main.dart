import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'dart:collection'; // for tracking discovered devices
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Channel for native Bluetooth audio
  static const _channel = MethodChannel('bt_audio');
  // List of discovered devices
  final _devices = <Map<String, String>>[];
  final Set<String> _seen = HashSet();
  String _status = 'idle';
  // Removed local address fetching
  // controller for manual server MAC input
  final TextEditingController _manualMacController = TextEditingController();
  // MAC address validation state
  bool _isMacValid = false;
    final RegExp _macRegExp = RegExp(r'^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$');
    // Toggle decryption on received audio for demo
    bool _decryptEnabled = true;

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler(_handleNativeCall);
    _manualMacController.addListener(_validateMac);
  }

  void _validateMac() {
    final text = _manualMacController.text.trim();
    final isValid = _macRegExp.hasMatch(text);
    if (isValid != _isMacValid) {
      setState(() {
        _isMacValid = isValid;
      });
    }
  }

  @override
  void dispose() {
    _manualMacController.removeListener(_validateMac);
    _manualMacController.dispose();
    super.dispose();
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onDeviceFound':
        final Map args = call.arguments as Map;
        final name = args['name'] as String;
        final addr = args['address'] as String;
        if (!_seen.contains(addr)) {
          _seen.add(addr);
          setState(() { _devices.add({'name': name, 'address': addr}); });
        }
        break;
      case 'onStatus':
        setState(() { _status = call.arguments as String; });
        break;
      case 'onError':
        setState(() { _status = 'Error: ${call.arguments}'; });
        break;
      default:
        break;
    }
  }

  Future<void> _startServer() async {
    // request microphone and Bluetooth permissions
    final statuses = await [
      Permission.microphone,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();
    if (statuses.values.any((status) => !status.isGranted)) {
      setState(() => _status = 'Permissions required');
      return;
    }
    await _channel.invokeMethod('startServer', {'decrypt': _decryptEnabled});
  }

  Future<void> _stop() async {
    await _channel.invokeMethod('stop');
  }
  
  Future<void> _startScan() async {
    setState(() { _devices.clear(); _seen.clear(); _status = 'scanning'; });
    // request location and Bluetooth permissions
    final statuses = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    if (statuses.values.any((status) => !status.isGranted)) {
      setState(() => _status = 'Permissions required');
      return;
    }
    await _channel.invokeMethod('startScan');
  }
  Future<void> _stopScan() async {
    await _channel.invokeMethod('stopScan');
    setState(() { _status = 'scan stopped'; });
  }
  Future<void> _connectToDevice(String address) async {
    await _channel.invokeMethod('startClient', {
      'macAddress': address,
      'decrypt': _decryptEnabled,
    });
  }
  

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Audio Stream'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
  child: ListView(
           children: [
            Text('Status: $_status'),
            // Manual server MAC entry
            TextField(
              controller: _manualMacController,
              decoration: InputDecoration(
                labelText: 'Server MAC Address',
                hintText: '00:11:22:33:44:55',
                errorText: _manualMacController.text.isEmpty || _isMacValid
                    ? null
                    : 'Invalid MAC format',
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isMacValid
                  ? () {
                      final mac = _manualMacController.text.trim();
                      _connectToDevice(mac);
                    }
                  : null,
              child: const Text('Connect to MAC'),
            ),
            const SizedBox(height: 16),
            const Text('Instructions:', style: TextStyle(fontWeight: FontWeight.bold)),
              // Decrypt toggle switch
              Row(
                children: [
                  const Text('Decrypt Audio'),
                  Switch(
                    value: _decryptEnabled,
                    onChanged: (v) {
                      setState(() => _decryptEnabled = v);
                      // Notify native code to toggle decryption mid-call
                      _channel.invokeMethod('setDecrypt', {'decrypt': v});
                    },
                  ),
                ],
              ),
            const Text('• Tap Server to listen for a connection.'),
            const Text('• Tap Scan to discover nearby peers.'),
            const Text('• Tap a device in the list to connect.'),
            const Text('• Tap Stop Scan to end discovery.'),
            const Text('• Tap Stop to end audio streaming.'),
            // Button controls
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton(onPressed: _startServer, child: const Text('Server')),
                ElevatedButton(onPressed: _startScan, child: const Text('Scan')),
                ElevatedButton(onPressed: _stopScan, child: const Text('Stop Scan')),
                ElevatedButton(onPressed: _stop, child: const Text('Stop')),
              ],
            ),
            const SizedBox(height: 16),
            Text('Discovered Devices:', style: TextStyle(fontWeight: FontWeight.bold)),
            // Shrink-wrapped ListView for devices inside a scrollable parent
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _devices.length,
              itemBuilder: (_, i) {
                final device = _devices[i];
                return ListTile(
                  title: Text(device['name']!.isNotEmpty ? device['name']! : 'Unknown Device'),
                  subtitle: Text('MAC: ${device['address']}'),
                  onTap: () => _connectToDevice(device['address']!),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
