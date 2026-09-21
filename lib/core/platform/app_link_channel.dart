import 'package:flutter/services.dart';

abstract interface class AppLinkOpener {
  Future<bool> openExternalUrl(String url);
}

/// Opens externally handled links without coupling presentation code to Android.
class AppLinkChannel implements AppLinkOpener {
  const AppLinkChannel();

  static const _channel = MethodChannel('nekocalc/app_link');

  @override
  Future<bool> openExternalUrl(String url) async {
    final opened = await _channel.invokeMethod<bool>('openUrl', {'url': url});
    return opened ?? false;
  }
}
