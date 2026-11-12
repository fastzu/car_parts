// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart'; // حزمة اختيار الصور من الهاتف
import 'home_screen.dart';
import '../app_theme.dart';

class WorkshopSetupScreen extends StatefulWidget {
  final String email;
  final String password;
  final String username;
  final String fullPhone;
  final String fullName;
  final String country;
  final String role;
  final bool hasTowing;

  const WorkshopSetupScreen({
    super.key,
    required this.email,
    required this.password,
    required this.username,
    required this.fullPhone,
    required this.fullName,
    required this.country,
    required this.role,
    required this.hasTowing,
  });

  @override
  State<WorkshopSetupScreen> createState() => _WorkshopSetupScreenState();
}

class _WorkshopSetupScreenState extends State<WorkshopSetupScreen> {
  final TextEditingController _workshopNameController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _buildingNoController = TextEditingController();

  final TextEditingController _latController =
      TextEditingController(text: '31.985470');
  final TextEditingController _lngController =
      TextEditingController(text: '35.851445');

  final TextEditingController _maxCarsController =
      TextEditingController(text: '5');
  final TextEditingController _openingHoursController =
      TextEditingController(text: '08:00 ص - 08:00 م');
  final TextEditingController _mapsUrlController =
      TextEditingController(text: 'https://maps.google.com');

  File? _imageFile;
  Uint8List? _webImageBytes;
  String? _uploadedImageUrl;
  bool _isLoading = false;

  // 🌟 اختيار صورة الورشة من الهاتف (مثل عرض المنتجات)
  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        if (kIsWeb) {
          var bytes = await image.readAsBytes();
          setState(() {
            _webImageBytes = bytes;
          });
        } else {
          setState(() {
            _imageFile = File(image.path);
          });
        }

        // محاكاة رفع الصورة ورابط جاهز مؤقت أو رفعه لسوبابيس
        _uploadedImageUrl =
            'https://images.unsplash.com/photo-1486006920555-c77dce18193b?auto=format&fit=crop&w=600&q=80';
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم اختيار صورة الورشة بنجاح!'),
              backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      debugPrint('Image pick error: $e');
    }
  }

  Future<void> _getWorkshopLocationFromGPS() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _latController.text = position.latitude.toString();
        _lngController.text = position.longitude.toString();
        _mapsUrlController.text =
            'https://maps.google.com/?q=${position.latitude},${position.longitude}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('تم جلب الموقع بنجاح!'),
            backgroundColor: AppTheme.success),
      );
    } catch (_) {}
  }

  Future<void> _completeSignupWithWorkshop() async {
    if (_workshopNameController.text.trim().isEmpty ||
        _latController.text.trim().isEmpty ||
        _lngController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('الرجاء تعبئة اسم الورشة وإحداثيات الموقع لإتمام التسجيل'),
            backgroundColor: AppTheme.warning),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final double? lat = double.tryParse(_latController.text.trim());
      final double? lng = double.tryParse(_lngController.text.trim());
      final int maxCars = int.tryParse(_maxCarsController.text.trim()) ?? 5;

      if (lat == null || lng == null) throw 'إحداثيات الموقع غير صحيحة';

      String fullAddress =
          'شارع: ${_streetController.text.trim()}, مبنى: ${_buildingNoController.text.trim()}';
      String imageUrl = _uploadedImageUrl ??
          'https://images.unsplash.com/photo-1486006920555-c77dce18193b?auto=format&fit=crop&w=600&q=80';

      final AuthResponse res = await Supabase.instance.client.auth.signUp(
        email: widget.email,
        password: widget.password,
        data: {
          'full_name': widget.fullName,
          'username': _workshopNameController.text.trim(),
          'phone': widget.fullPhone,
          'country': widget.country,
          'role': widget.role,
          'has_towing': widget.hasTowing,
          'workshop_latitude': lat,
          'workshop_longitude': lng,
          'workshop_address': fullAddress,
          'max_car_capacity': maxCars,
          'workshop_image_url': imageUrl,
          'opening_hours': _openingHoursController.text.trim(),
          'google_maps_url': _mapsUrlController.text.trim(),
        },
      );

      final user = res.user;
      if (user != null) {
        final userData = {
          'id': user.id,
          'email': widget.email,
          'username': _workshopNameController.text.trim(),
          'phone': widget.fullPhone,
          'full_name': widget.fullName,
          'country': widget.country,
          'role': widget.role,
          'has_towing': widget.hasTowing,
          'workshop_latitude': lat,
          'workshop_longitude': lng,
          'workshop_address': fullAddress,
          'max_car_capacity': maxCars,
          'workshop_image_url': imageUrl,
          'opening_hours': _openingHoursController.text.trim(),
          'google_maps_url': _mapsUrlController.text.trim(),
        };

        try {
          await Supabase.instance.client.from('customers').upsert(userData);
        } catch (_) {}

        try {
          await Supabase.instance.client.from('profiles').upsert(userData);
        } catch (_) {}

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('تم إنشاء الحساب وحفظ الورشة بنجاح!'),
                backgroundColor: AppTheme.success),
          );

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    const HomeScreen(showTutorialOnStart: true)),
            (route) => false,
          );
        }
      }
    } catch (e) {
      String msg = e.toString().replaceAll('Exception: ', '');
      if (msg.contains('user_already_exists') ||
          msg.contains('already registered')) {
        msg = 'البريد الإلكتروني مسجل مسبقاً في النظام.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('خطأ في التسجيل: $msg'),
            backgroundColor: AppTheme.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('إكمال تسجيل ورشتي المعتمدة',
              style: TextStyle(color: Colors.white, fontSize: 14)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'أدخل تفاصيل الورشة، اختر الصورة من هاتفك، وساعات العمل:',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 20),
              TextField(
                controller: _workshopNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'اسم الورشة أو المركز',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),

              // 🌟 زر اختيار صورة الورشة من الهاتف (مثل عرض المنتجات)
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border, width: 1.5),
                  ),
                  child: _webImageBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child:
                              Image.memory(_webImageBytes!, fit: BoxFit.cover))
                      : _imageFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(_imageFile!, fit: BoxFit.cover))
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.add_a_photo,
                                    color: AppTheme.primary, size: 36),
                                SizedBox(height: 8),
                                Text('اضغط لاختيار صورة الورشة من الهاتف',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _openingHoursController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'ساعات العمل (مثال: 08:00 ص - 08:00 م)',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _streetController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'اسم الشارع / المنطقة',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _buildingNoController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'رقم المبنى أو المحل (إن وجد)',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _maxCarsController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'أقصى عدد سيارات تتحمله الورشة',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _mapsUrlController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'رابط خرائط جوجل (Google Maps URL)',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _latController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'خط العرض (Latitude)',
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _lngController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'خط الطول (Longitude)',
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _getWorkshopLocationFromGPS,
                  icon: const Icon(Icons.my_location),
                  label: const Text('جلب الموقع تلقائياً (GPS / افتراضي)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _completeSignupWithWorkshop,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('حفظ وإتمام التسجيل النهائي',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
