import 'package:flutter/material.dart';
import 'package:pigcam2/components/common_app_bar.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:provider/provider.dart'; // Import provider for notifications
import 'package:pigcam2/models/notification_provider.dart'; // Import NotificationProvider
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:pigcam2/pages/wifi_settings_page.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  Uint8List? _liveViewImageBytes;
  String _connectionStatus = 'Disconnected';
  bool _showWifiSettings = false; // New state variable
  bool _isFrontCamera = false; // Simulated camera mode
  final TextEditingController _ipController = TextEditingController(text: '192.168.4.1'); // Default IP for ESP32-CAM
  final TextEditingController _ssidController = TextEditingController(text: 'ESP32-CAM'); // Default ESP32-CAM SSID
  final TextEditingController _passwordController = TextEditingController(text: 'password'); // Default ESP32-CAM password

  @override
  void initState() {
    super.initState();
  }

  Future<void> _connectToEsp32CamWifi() async {
    final ssid = _ssidController.text;
    final password = _passwordController.text;

    setState(() {
      _connectionStatus = 'Attempting to connect to $ssid...';
    });

    try {
       Request necessary permissions
       REMOVE: await _p2pClient.askP2pPermissions();
       REMOVE: await _p2pClient.askLocationPermissions();
       REMOVE: await _p2pClient.askBluetoothPermissions(); // Though we're using direct Wi-Fi, BLE permissions might be part of P2P setup

       Enable services
       REMOVE: await _p2pClient.enableWifiServices();
       REMOVE: await _p2pClient.enableLocationServices();

      // Connect using credentials
      try {
         REMOVE: await _p2pClient.connectWithCredentials(
         REMOVE:   ssid,
         REMOVE:   password,
         REMOVE:   timeout: const Duration(seconds: 60),
         REMOVE: );
        setState(() {
          _connectionStatus = 'Successfully connected to $ssid!';
        });
      } catch (e) {
        setState(() {
          _connectionStatus = 'Failed to connect to $ssid: $e';
        });
      }
    } catch (e) {
      setState(() {
        _connectionStatus = 'Wi-Fi P2P connection error: $e';
      });
    }
  }

  void _stopStreaming() {
    setState(() {
      _liveViewImageBytes = null;
      _connectionStatus = 'Streaming stopped.';
    });
  }

  Future<void> _captureStillImage() async {
    setState(() {
      _connectionStatus = 'Capturing image...';
    });

    final ipAddress = _ipController.text;
    final captureUrl = 'http://$ipAddress/capture';

    try {
      final response = await http.get(Uri.parse(captureUrl));

      if (response.statusCode == 200) {
        setState(() {
          _liveViewImageBytes = response.bodyBytes;
          _connectionStatus = 'Image captured successfully!';
        });

        // Add notification
        if (_liveViewImageBytes != null) {
          Provider.of<NotificationProvider>(context, listen: false).addImageCaptureNotification(
            _liveViewImageBytes!,
          );
        }
        // Show snackbar for feedback
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image captured!')),
        );
      } else {
        setState(() {
          _connectionStatus = 'Failed to capture image: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _connectionStatus = 'Network error during capture: $e';
      });
    }
  }

  Future<Uint8List?> _fetchEsp32Image(String esp32Url) async {
    final response = await http.get(Uri.parse(esp32Url));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    return null;
  }

  Future<void> _captureFromEsp32Cam() async {
    final esp32Url = 'http://192.168.4.1/capture';
    final imageBytes = await _fetchEsp32Image(esp32Url);
    if (imageBytes != null) {
      await _sendImageBytesToPython(imageBytes);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch image from ESP32-CAM')),
      );
    }
  }

  Future<void> _sendImageBytesToPython(Uint8List imageBytes) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://<PYTHON_SERVER_IP>:5000/predict'), // TODO: Set your server IP
    );
    request.files.add(http.MultipartFile.fromBytes('image', imageBytes, filename: 'esp32.jpg'));
    var response = await request.send();
    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Prediction Result'),
          content: Text(respStr),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${response.statusCode}')),
      );
    }
  }

  void _toggleCameraMode() {
    setState(() {
      _isFrontCamera = !_isFrontCamera;
      _connectionStatus = _isFrontCamera ? 'Front camera (simulated)' : 'Rear camera (simulated)';
    });
  }

  // Placeholder for camera settings
  void _showCameraSettings() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Camera Settings'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Settings options will go here.'),
                // Add sliders, dropdowns, etc. for ESP32-CAM settings
                // e.g., resolution, quality, flash, etc.
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleRefresh() async {
    await Future.delayed(const Duration(seconds: 1));
    setState(() {}); // For demo, just rebuild
  }

  @override
  void dispose() {
    _ipController.dispose();
    _ssidController.dispose();
    _passwordController.dispose();
    // REMOVE: _p2pClient.dispose(); // Dispose P2P client
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: 'Camera Page',
        showBackButton: true, // Show back button
        onWifiPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const WiFiSettingsPage()),
          );
        },
      ),
      body: LiquidPullToRefresh(
        onRefresh: _handleRefresh,
        child: Stack(
          children: <Widget>[
            // Camera icon watermark
            Center(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.15,
                  child: Icon(
                    Icons.camera_alt,
                    size: 180,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            // Main content below the watermark
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: <Widget>[
                  // --- Camera Power Button ---
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.power_settings_new),
                        label: const Text('Turn Camera On'),
                        onPressed: () async {
                          final url = 'http://${_ipController.text}/camera_power?on=1';
                          try {
                            final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));
                            if (response.statusCode == 200) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Camera turned ON!')),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to turn on camera. Status: ${response.statusCode}')),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // --- IP Address Field and Test Button ---
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ipController,
                          decoration: const InputDecoration(
                            labelText: 'ESP32-CAM IP Address',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Test Connection'),
                        onPressed: () async {
                          final testUrl = 'http://${_ipController.text}:81/stream';
                          try {
                            final response = await http.get(Uri.parse(testUrl)).timeout(const Duration(seconds: 3));
                            if (response.statusCode == 200) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Connection Successful'),
                                  content: Text('Successfully connected to $testUrl'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Connection Failed'),
                                  content: Text('Received status code ${response.statusCode} from $testUrl'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          } catch (e) {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Connection Failed'),
                                content: Text('Could not connect to $testUrl\nError: $e'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // MJPEG stream from ESP32-CAM
                  if (_liveViewImageBytes == null)
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Start Stream'),
                                onPressed: () {
                                  setState(() {
                                    _connectionStatus = 'Streaming from ${_ipController.text}';
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.stop),
                                label: const Text('Stop Stream'),
                                onPressed: _stopStreaming,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 240,
                          child: Mjpeg(
                            stream: 'http://${_ipController.text}/stream', // ESP32-CAM MJPEG stream URL
                            isLive: true,
                            error: (context, error, stack) {
                              print('MJPEG Error: $error');
                              print('MJPEG Stack: $stack');
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('Stream error. Check IP address and connection.'),
                                    const SizedBox(height: 8),
                                    Text('Current URL: http://${_ipController.text}/stream'),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  if (_showWifiSettings)
                    Column(
                      children: <Widget>[
                        Text('Connection Status: $_connectionStatus'),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _ssidController,
                          decoration: const InputDecoration(
                            labelText: 'ESP32-CAM Wi-Fi SSID',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Wi-Fi Password (if any)',
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _ipController,
                          decoration: const InputDecoration(
                            labelText: 'ESP32-CAM IP Address',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _connectToEsp32CamWifi,
                          child: const Text('Connect to ESP32-CAM Wi-Fi'),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  if (_liveViewImageBytes != null)
                    Expanded(
                      child: GestureDetector(
                        onTap: _stopStreaming,
                        onScaleUpdate: (details) {
                          setState(() {
                            _connectionStatus = 'Zoom: ${details.scale.toStringAsFixed(2)}x (simulated)';
                          });
                        },
                        child: Image.memory(
                          _liveViewImageBytes!,
                          fit: BoxFit.contain,
                        ),
                      ),
                    )
                  else if (_liveViewImageBytes == null) ...[
                    const SizedBox(height: 200), // Space for watermark
                    const Center(
                      child: Text(
                        'Live view or captured image will appear here.',
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              bottom: 25.0,
              left: 16.0,
              right: 16.0,
              child: Column(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: _showCameraSettings,
                        child: const Icon(Icons.settings), // Camera Settings icon
                      ),
                      ElevatedButton(
                        onPressed: _captureFromEsp32Cam,
                        child: const Text('Capture from ESP32-CAM'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade50,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
