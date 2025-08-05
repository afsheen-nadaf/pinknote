import 'dart:async';
import 'package:flutter/services.dart';

class FlutterNativeTimezone {
  static const MethodChannel _channel =
      MethodChannel('flutter_native_timezone');

  static Future<String> getLocalTimezone() async {
    final String timeZone =
        await _channel.invokeMethod<String>('getLocalTimezone') ?? 'UTC';
    return timeZone;
  }
}