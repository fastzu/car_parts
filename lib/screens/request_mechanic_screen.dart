// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../app_theme.dart';

class RequestMechanicScreen extends StatefulWidget {
  const RequestMechanicScreen({super.key});

  @override
  State<RequestMechanicScreen> createState() => _RequestMechanicScreenState();
}

class _RequestMechanicScreenState extends State<RequestMechanicScreen> {
  String _serviceType = 'mechanic'; // 'mechanic' أو 'towing'
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _carController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();

  bool _isLoading = false;
  double? _currentLat;
  double? _currentLng;
  String _locationStatus = 'جارِ رصد موقعك الحالي عبر GPS...';

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(
          () => _locationStatus = 'خدمة الموقع (GPS) مغلقة. يرجى تفعيلها.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _locationStatus = 'تم رفض صلاحية الوصول للموقع');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _locationStatus =
          'صلاحيات الموقع مرفوضة بشكل دائم من إعدادات الجهاز');
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentLat = position.latitude;
        _currentLng = position.longitude;
        _locationStatus =
            'تم تحديد موقعك بنجاح (Lat: ${_currentLat!.toStringAsFixed(4)}, Lng: ${_currentLng!.toStringAsFixed(4)})';
      });
    } catch (e) {
      setState(() => _locationStatus = 'خطأ في جلب الموقع: $e');
    }
  }

  Future<void> _submitRequest() async {
    if (_phoneController.text.trim().isEmpty ||
        _carController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('الرجاء إدخال رقم الهاتف ومعلومات السيارة'),
            backgroundColor: AppTheme.warning),
      );
      return;
    }

    if (_currentLat == null || _currentLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('الرجاء الانتظار حتى يتم رصد موقعك الجغرافي'),
            backgroundColor: AppTheme.warning),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw 'يرجى تسجيل الدخول أولاً';

      final requestData = {
        'user_id': user.id,
        'service_type': _serviceType,
        'phone': _phoneController.text.trim(),
        'car_details': _carController.text.trim(),
        'description': _descController.text.trim(),
        'latitude': _currentLat,
        'longitude': _currentLng,
        'status': 'pending',
        'progress_step': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      };

      if (_serviceType == 'towing') {
        requestData['dropoff_address'] =
            _dropoffController.text.trim().isNotEmpty
                ? _dropoffController.text.trim()
                : 'ورشة أو وجهة الزبون';
        requestData['dropoff_latitude'] = _currentLat! + 0.02;
        requestData['dropoff_longitude'] = _currentLng! + 0.02;
      }

      await Supabase.instance.client
          .from('mechanic_requests')
          .insert(requestData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم إرسال طلب المساعدة الطارئة بنجاح!'),
              backgroundColor: AppTheme.success),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.error),
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
          title: const Text('طلب مساعدة طارئة (ميكانيكي / ونش)',
              style: TextStyle(color: Colors.white, fontSize: 14)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('اختر نوع الخدمة المطلوبة:',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _serviceType == 'mechanic'
                            ? AppTheme.primary
                            : AppTheme.surface,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () =>
                          setState(() => _serviceType = 'mechanic'),
                      child: const Text('ميكانيكي طوارئ',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _serviceType == 'towing'
                            ? AppTheme.primary
                            : AppTheme.surface,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => setState(() => _serviceType = 'towing'),
                      child: const Text('ونش سحب (Towing)',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // بطاقة عرض وتحديث الموقع الجغرافي الحالي للعميل
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _currentLat != null
                          ? AppTheme.success
                          : AppTheme.warning,
                      width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on,
                        color: _currentLat != null
                            ? AppTheme.success
                            : AppTheme.warning,
                        size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('موقعك الحالي (Pickup Location):',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 11)),
                          const SizedBox(height: 4),
                          Text(_locationStatus,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh,
                          color: AppTheme.primary, size: 22),
                      onPressed: _getCurrentLocation,
                      tooltip: 'إعادة تحديد الموقع',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'رقم الهاتف للتواصل معك (مثال: 079xxxxxxx)',
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
                controller: _carController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'نوع السيارة ورقمها (مثال: تويوتا كورولا 2020)',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              if (_serviceType == 'towing') ...[
                TextField(
                  controller: _dropoffController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'وجهة النقل المطلوبة (Drop-off Address)',
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _descController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'وصف المشكلة (مثال: تعطل محرك، بنشر إطار...)',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _submitRequest,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('إرسال الطلب الآن',
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
