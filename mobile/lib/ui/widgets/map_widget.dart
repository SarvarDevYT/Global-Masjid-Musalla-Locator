import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/mosque_model.dart';

class MapWidget extends StatefulWidget {
  final LatLng initialCenter;
  final LatLng? userLocation;
  final List<MosqueModel> mosques;
  final MosqueModel? selectedMosque;
  final Function(MosqueModel) onMosqueSelected;
  final Function(LatLng newCenter) onPositionChanged;
  final MapController? mapController;

  const MapWidget({
    super.key,
    required this.initialCenter,
    this.userLocation,
    required this.mosques,
    this.selectedMosque,
    required this.onMosqueSelected,
    required this.onPositionChanged,
    this.mapController,
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  late final MapController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.mapController ?? MapController();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: widget.initialCenter,
        initialZoom: 14.0,
        minZoom: 4.0,
        maxZoom: 18.0,
        onPositionChanged: (camera, hasGesture) {
          if (hasGesture) {
            widget.onPositionChanged(camera.center);
          }
        },
      ),
      children: [
        // Ultra-fast Global CARTO Basemaps with Official API Key (No watermarks)
        TileLayer(
          urlTemplate: isDark
              ? 'https://{s}.basemaps.cartocdn.com/rastertiles/dark_all/{z}/{x}/{y}.png?key=cb1_4d65_1_69dcf6f563a545ed10f0044e'
              : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png?key=cb1_4d65_1_69dcf6f563a545ed10f0044e',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.masjidlocator.masjid_locator',
          maxZoom: 19,
        ),

        // Mosque Markers
        MarkerLayer(
          markers: [
            // User Location Marker
            if (widget.userLocation != null)
              Marker(
                point: widget.userLocation!,
                width: 32,
                height: 32,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.my_location, color: Colors.white, size: 16),
                  ),
                ),
              ),

            // Mosque markers
            ...widget.mosques.map((mosque) {
              final isSelected = widget.selectedMosque?.id == mosque.id;
              final isMasjid = mosque.isMasjid;

              return Marker(
                point: LatLng(mosque.lat, mosque.lng),
                width: isSelected ? 52 : 40,
                height: isSelected ? 52 : 40,
                child: GestureDetector(
                  onTap: () => widget.onMosqueSelected(mosque),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accentGold
                          : (isMasjid ? AppColors.primary : const Color(0xFFD97706)),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: isSelected ? 3 : 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        isMasjid ? Icons.mosque : Icons.meeting_room,
                        color: Colors.white,
                        size: isSelected ? 26 : 20,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }
}
