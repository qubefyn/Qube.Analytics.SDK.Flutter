import 'package:example/firebase_database.dart';
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
      setState(() async {
        // Update the device info string with all necessary data
        _deviceInfo = '''
          Device Type: ${userInfo.deviceType}
          Width: ${userInfo.width}
          Height: ${userInfo.height}
          Country Code: ${userInfo.countryCode}
        ''';
        //
        //
        String Id = userInfo.deviceType;
        Map<String, dynamic> DeviceInfoMap = {
          //"Id": Id,
          "Device Type": {userInfo.deviceType},
          "Width": {userInfo.width},
          "Height": {userInfo.height},
          "Country Code": {userInfo.countryCode},
        };
        await DatabaseMethods().DeviceInfo(DeviceInfoMap, Id);
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
          ],
        ),
      ),
    );
  }
}
