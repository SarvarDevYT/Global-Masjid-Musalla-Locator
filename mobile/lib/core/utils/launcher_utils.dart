import 'package:url_launcher/url_launcher.dart';

enum NavigationApp {
  googleMaps,
  appleMaps,
  yandexMaps,
  twoGis,
  waze
}

class LauncherUtils {
  static Future<bool> openNavigationApp({
    required NavigationApp app,
    required double lat,
    required double lng,
    required String title,
  }) async {
    Uri uri;

    switch (app) {
      case NavigationApp.googleMaps:
        uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
        break;
      case NavigationApp.appleMaps:
        uri = Uri.parse('http://maps.apple.com/?daddr=$lat,$lng&q=${Uri.encodeComponent(title)}');
        break;
      case NavigationApp.yandexMaps:
        uri = Uri.parse('yandexmaps://build_route_on_map?lat_to=$lat&lon_to=$lng');
        if (!await canLaunchUrl(uri)) {
          uri = Uri.parse('https://yandex.com/maps/?rtext=~$lat,$lng&rtt=auto');
        }
        break;
      case NavigationApp.twoGis:
        uri = Uri.parse('dgis://2gis.ru/routeSearch/rsType/car/to/$lng,$lat');
        if (!await canLaunchUrl(uri)) {
          uri = Uri.parse('https://2gis.ru/routeSearch/rsType/car/to/$lng,$lat');
        }
        break;
      case NavigationApp.waze:
        uri = Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes');
        break;
    }

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      // Fallback to web browser
      return await launchUrl(
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
        mode: LaunchMode.externalApplication,
      );
    }
  }
}
