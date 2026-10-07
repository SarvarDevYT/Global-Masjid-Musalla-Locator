import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_colors.dart';
import '../../core/l10n/app_translations.dart';
import '../../providers/locale_provider.dart';
import '../../providers/mosque_providers.dart';

class AddMosqueScreen extends ConsumerStatefulWidget {
  const AddMosqueScreen({super.key});

  @override
  ConsumerState<AddMosqueScreen> createState() => _AddMosqueScreenState();
}

class _AddMosqueScreenState extends ConsumerState<AddMosqueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _altNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _photoUrlController = TextEditingController();

  String _type = 'masjid';
  bool _hasWuduMen = true;
  bool _hasWuduWomen = false;
  bool _hasWomenPrayerArea = false;
  bool _hasJuma = true;
  bool _hasWheelchair = false;
  bool _hasParking = false;
  bool _isSubmitting = false;

  late double _lat;
  late double _lng;

  @override
  void initState() {
    super.initState();
    final loc = ref.read(userLocationProvider).value ?? const LatLng(41.3381, 69.2415);
    _lat = loc.latitude;
    _lng = loc.longitude;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _altNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _photoUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.get('add_mosque', locale)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mosque Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Masjid yoki Namozxona nomi *',
                    hintText: 'masalan: Hazrati Umar Masjidi',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 3) {
                      return 'Iltimos, to\'liq nomini kiriting';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Alt Name
                TextFormField(
                  controller: _altNameController,
                  decoration: const InputDecoration(
                    labelText: 'Muqobil yoki xalqaro nomi',
                    hintText: 'masalan: Hazrat Umar Mosque',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Type selector (Jome vs Musalla)
                DropdownButtonFormField<String>(
                  value: _type,
                  decoration: const InputDecoration(
                    labelText: 'Joy turi *',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'masjid',
                      child: Text(AppTranslations.get('masjid', locale)),
                    ),
                    DropdownMenuItem(
                      value: 'musalla',
                      child: Text(AppTranslations.get('musalla', locale)),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _type = val;
                        if (_type == 'musalla') _hasJuma = false;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Address & City
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'To\'liq manzil *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Manzilni kiriting';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    labelText: 'Shahar / Tuman',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Coordinates info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Koordinatalar: ${_lat.toStringAsFixed(4)}, ${_lng.toStringAsFixed(4)} (Joriy GPS)',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Amenities
                const Text(
                  'Qulayliklar va Sharoitlar',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),

                SwitchListTile(
                  title: Text(AppTranslations.get('wudu_men', locale)),
                  value: _hasWuduMen,
                  onChanged: (val) => setState(() => _hasWuduMen = val),
                ),
                SwitchListTile(
                  title: Text(AppTranslations.get('wudu_women', locale)),
                  value: _hasWuduWomen,
                  onChanged: (val) => setState(() => _hasWuduWomen = val),
                ),
                SwitchListTile(
                  title: Text(AppTranslations.get('women_section', locale)),
                  value: _hasWomenPrayerArea,
                  onChanged: (val) => setState(() => _hasWomenPrayerArea = val),
                ),
                if (_type == 'masjid')
                  SwitchListTile(
                    title: Text(AppTranslations.get('juma_prayer', locale)),
                    value: _hasJuma,
                    onChanged: (val) => setState(() => _hasJuma = val),
                  ),
                SwitchListTile(
                  title: Text(AppTranslations.get('wheelchair_access', locale)),
                  value: _hasWheelchair,
                  onChanged: (val) => setState(() => _hasWheelchair = val),
                ),
                SwitchListTile(
                  title: Text(AppTranslations.get('parking', locale)),
                  value: _hasParking,
                  onChanged: (val) => setState(() => _hasParking = val),
                ),

                const SizedBox(height: 24),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitForm,
                    child: _isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            AppTranslations.get('submit', locale),
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final repo = ref.read(mosqueRepositoryProvider);
    final locale = ref.read(localeProvider);

    final payload = {
      'name': _nameController.text.trim(),
      'alt_name': _altNameController.text.trim().isEmpty ? null : _altNameController.text.trim(),
      'address': _addressController.text.trim(),
      'city': _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
      'type': _type,
      'lat': _lat,
      'lng': _lng,
      'has_wudu_men': _hasWuduMen,
      'has_wudu_women': _hasWuduWomen,
      'has_women_prayer_area': _hasWomenPrayerArea,
      'has_juma': _hasJuma,
      'has_wheelchair_access': _hasWheelchair,
      'has_parking': _hasParking,
      'photo_url': _photoUrlController.text.trim().isEmpty ? null : _photoUrlController.text.trim(),
    };

    final success = await repo.contributeMosque(payload);

    if (mounted) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? AppTranslations.get('success_added', locale)
                : 'Lokal qabul qilindi. Moderatsiyaga yuboriladi.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    }
  }
}
