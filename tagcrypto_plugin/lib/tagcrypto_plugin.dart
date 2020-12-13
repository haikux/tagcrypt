
import 'dart:async';

import 'package:flutter/services.dart';

class TagcryptoPlugin {
  static const MethodChannel _channel =
      const MethodChannel('tagcrypto_plugin');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
  static Future<String> tagcrypt (String payload) async{
    final String response = await _channel.invokeMethod("tagcrypt",payload);
    return response;
  }
}
