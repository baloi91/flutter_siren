library flutter_siren;

import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info/package_info.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/apple_app_store.dart';
import 'services/google_play_store.dart';

class Siren {
  String storeUrl;

  Future<String> _getVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  Future<String> _getPackage() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.packageName;
  }

  void _openStoreUrl(BuildContext context) async {
    if (storeUrl == null) {
      return null;
    }

    try {
      if (await canLaunch(storeUrl)) {
        await launch(storeUrl, forceSafariVC: false);
      }
    } on PlatformException {}
  }

  Future<bool> updateIsAvailable() async {
    final currentVersion = await _getVersion();
    final packageName = await _getPackage();
    var newVersion = currentVersion;

    if (Platform.isIOS) {
      final applicationDetails =
          await AppleAppStore.getStoreDetails(from: packageName);
      storeUrl =
          'https://apps.apple.com/app/id${applicationDetails.trackId.toString()}?mt=8';
      newVersion = applicationDetails.version;
    }

    if (Platform.isAndroid) {
      storeUrl = 'https://play.google.com/store/apps/details?id=$packageName';
      newVersion = await GooglePlayStore.getLatestVersion(from: packageName);
    }

    final newList = newVersion.split('.');
    final currentList = currentVersion.split('.');

    if (newList.length == 3 && currentList.length == 3) {
      final newMajor = int.parse(newList[0]);
      final newMinor = int.parse(newList[1]);
      final newPatch = int.parse(newList[2]);
      
      final currentMajor = int.parse(currentList[0]);
      final currentMinor = int.parse(currentList[1]);
      final currentPatch = int.parse(currentList[2]);

      if (newMajor > currentMajor
          || (newMajor == currentMajor && newMinor > currentMinor)
          || (newMajor == currentMajor && newMinor == currentMinor
              && newPatch > currentPatch)) {
        return true;
      } else {
        return false;
      }
    }
    return currentVersion != newVersion;
  }

  Future<void> promptUpdate(BuildContext context,
      {String title = 'Update Available',
      String message = '''
There is an updated version available on the App Store. Would you like to upgrade?''',
      String buttonUpgradeText = 'Upgrade',
      String buttonCancelText = 'Cancel',
      bool forceUpgrade = false}) async {
    final buttons = <Widget>[];

    if (!forceUpgrade) {
      buttons.add(TextButton(
        child: Text(buttonCancelText),
        onPressed: () {
          Navigator.of(context).pop();
        },
      ));
    }

    buttons.add(TextButton(
      child: Text(buttonUpgradeText),
      onPressed: () {
        _openStoreUrl(context);
        if (!forceUpgrade) {
          Navigator.of(context).pop();
        }
      },
    ));

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return FutureBuilder<bool>(
            future: updateIsAvailable(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return WillPopScope(
                  onWillPop: () async => false,
                  child: AlertDialog(
                    title: Text(title),
                    content: Text(message),
                    actions: buttons,
                  ),
                );
              }

              return Container();
            });
      },
    );
  }
}
