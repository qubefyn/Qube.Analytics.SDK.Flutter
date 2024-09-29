import 'package:example/firebase_database.dart';
import 'package:example/pages/screen1.dart';
import 'package:flutter/material.dart';
import 'package:qube_analytics_sdk/qube_analytics_sdk.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _deviceInfo = "Loading...";
  final UniqueDeviceIdService _deviceIdService = UniqueDeviceIdService();

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _getDeviceInfo(context);
  }

  Future<void> _getDeviceInfo(BuildContext context) async {
    final userInfo = await _deviceIdService.getUserInfo(context);

    if (userInfo != null) {
      // Prepare the device info string first
      String deviceInfo = '''
      Unique ID: ${userInfo.deviceID}
      Device Type: ${userInfo.deviceType}
      Width: ${userInfo.width}
      Height: ${userInfo.height}
      Country Code: ${userInfo.countryCode}
    ''';

      // Create the device info map
      String id = userInfo.deviceID;
      Map<String, dynamic> deviceInfoMap = {
        "Unique ID": userInfo.deviceID,
        "Device Type": userInfo.deviceType,
        "Width": userInfo.width,
        "Height": userInfo.height,
        "Country Code": userInfo.countryCode,
      };

      // Now call the database method
      await DatabaseMethods().DeviceInfo(deviceInfoMap, id);

      // Finally, update the state synchronously
      setState(() {
        _deviceInfo = deviceInfo; // Update device info string
      });
    } else {
      setState(() {
        _deviceInfo = "Could not retrieve device information";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              _deviceInfo,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const Screen1(),
                    settings: const RouteSettings(name: 'Screen1'),
                  ),
                );
              },
              child: const Text('Go to Screen1'),
            )
          ],
        ),
      ),
    );
  }
}
