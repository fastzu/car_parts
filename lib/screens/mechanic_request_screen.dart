// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../app_theme.dart';

class MechanicRequestScreen extends StatefulWidget {
  const MechanicRequestScreen({super.key});

  @override
  State<MechanicRequestScreen> createState() => _MechanicRequestScreenState();
}

class _MechanicRequestScreenState extends State<MechanicRequestScreen> {
  bool _isLoading = true;
  List<dynamic> _nearbyRequests = [];
  bool _hasTowing = false;
  String _userRole = '';
  Timer? _locationTimer;

  final double _providerLat = 31.985470;
  final double _providerLng = 35.851445;

  @override
  void initState() {
    super.initState();
    _checkProviderPermissionsAndFetchRequests();

    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _updateLiveProgressBasedOnLocation();
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkProviderPermissionsAndFetchRequests() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final userRes = await Supabase.instance.client
          .from('customers')
          .select('role, has_towing')
          .eq('id', user.id)
          .maybeSingle();

      if (userRes != null) {
        _userRole = (userRes['role'] ?? '').toString().toLowerCase().trim();
        _hasTowing = userRes['has_towing'] == true;
      }

      final response = await Supabase.instance.client
          .from('mechanic_requests')
          .select()
          .eq('status', 'pending');

      if (mounted) {
        List<dynamic> allRequests = List<dynamic>.from(response);

        if (_userRole == 'mechanic' && !_hasTowing) {
          allRequests = allRequests.where((req) {
            final type =
                (req['service_type'] ?? '').toString().toLowerCase().trim();
            return type == 'mechanic';
          }).toList();
        }

        setState(() {
          _nearbyRequests = allRequests;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching requests: $e');
      if (mounted) {
        setState(() {
          _nearbyRequests = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateLiveProgressBasedOnLocation() async {
    if (_nearbyRequests.isEmpty) return;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      for (var req in _nearbyRequests) {
        if (req['mechanic_id'] == user.id && req['status'] == 'accepted') {
          final double targetLat = double.tryParse(
                  req['pickup_latitude']?.toString() ??
                      req['latitude'].toString()) ??
              _providerLat;
          final double targetLng = double.tryParse(
                  req['pickup_longitude']?.toString() ??
                      req['longitude'].toString()) ??
              _providerLng;

          double distanceInMeters = Geolocator.distanceBetween(
            _providerLat,
            _providerLng,
            targetLat,
            targetLng,
          );

          int estimatedMinutes = (distanceInMeters / 500).ceil();
          if (estimatedMinutes < 1) estimatedMinutes = 1;

          await Supabase.instance.client.from('mechanic_requests').update({
            'progress_step': 'accepted',
            'estimated_time':
                '$estimatedMinutes دقائق (${distanceInMeters.toStringAsFixed(0)} متر)',
          }).eq('id', req['id']);
        }
      }
    } catch (e) {
      debugPrint('Error updating location progress: $e');
    }
  }

  Future<void> _acceptRequest(String requestId, bool redirectToWorkshop) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final updateData = {
        'mechanic_id': user.id,
        'status': 'accepted',
        'progress_step': 'accepted',
        'estimated_time': 'جاري حساب المسافة والوقت...',
      };

      if (redirectToWorkshop) {
        // إذا اختار المزود السحب لورشته الخاصة، يمكننا جلب إحداثيات ورشته وتحديث الـ dropoff
        final workshopRes = await Supabase.instance.client
            .from('customers')
            .select('workshop_latitude, workshop_longitude, workshop_address')
            .eq('id', user.id)
            .maybeSingle();

        if (workshopRes != null && workshopRes['workshop_latitude'] != null) {
          updateData['dropoff_latitude'] = workshopRes['workshop_latitude'];
          updateData['dropoff_longitude'] = workshopRes['workshop_longitude'];
          updateData['dropoff_address'] =
              workshopRes['workshop_address'] ?? 'ورشة المزود المعتمدة';
        }
      }

      await Supabase.instance.client
          .from('mechanic_requests')
          .update(updateData)
          .eq('id', requestId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم قبول الطلب وبدء تتبع خط سير الونش بنجاح!'),
              backgroundColor: AppTheme.success),
        );
        _checkProviderPermissionsAndFetchRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _showAcceptOptionsDialog(String requestId, String serviceType) {
    if (serviceType == 'towing' && _hasTowing) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('خيارات التوجه والوجهة',
              style: TextStyle(color: Colors.white, fontSize: 16)),
          content: const Text(
              'هل ترغب بسحب السيارة إلى ورشتك الخاصة أم إلى وجهة وطريق الزبون المحددة؟',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _acceptRequest(requestId, false); // وجهة الزبون
              },
              child: const Text('وجهة الزبون (Drop-off)',
                  style: TextStyle(color: AppTheme.primaryLight)),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              onPressed: () {
                Navigator.pop(context);
                _acceptRequest(requestId, true); // ورشة المزود
              },
              child: const Text('ورشتي الخاصة',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      _acceptRequest(requestId, false);
    }
  }

  void _showRepairProgressDialog(String requestId) {
    String selectedStep = 'in_progress';
    final TextEditingController repairTimeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              title: const Text('تحديث مرحلة صيانة السيارة بالورشة',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('اختر حالة العمل الحالية:',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  DropdownButton<String>(
                    value: selectedStep,
                    dropdownColor: AppTheme.surface,
                    style: const TextStyle(color: Colors.white),
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                          value: 'in_progress',
                          child: Text('السيارة قيد التصليح بالورشة')),
                      DropdownMenuItem(
                          value: 'completed',
                          child: Text('تم الانتهاء وجاهزة للاستلام')),
                    ],
                    onChanged: (val) =>
                        setDialogState(() => selectedStep = val!),
                  ),
                  const SizedBox(height: 16),
                  if (selectedStep == 'in_progress')
                    TextField(
                      controller: repairTimeController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'حدد وقت التصليح (مثال: ساعتان، 3 أيام)',
                        labelStyle: TextStyle(color: Colors.grey),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child:
                      const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary),
                  onPressed: () async {
                    Navigator.pop(context);
                    await Supabase.instance.client
                        .from('mechanic_requests')
                        .update({
                      'progress_step': selectedStep,
                      if (repairTimeController.text.trim().isNotEmpty)
                        'estimated_time': repairTimeController.text.trim(),
                    }).eq('id', requestId);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('تم تحديث مرحلة التصليح للزبون بنجاح!'),
                          backgroundColor: AppTheme.success),
                    );
                    _checkProviderPermissionsAndFetchRequests();
                  },
                  child: const Text('تأكيد وحفظ',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          title: const Text('طلبات الطوارئ والأوناش الواردة',
              style: TextStyle(color: Colors.white, fontSize: 15)),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _checkProviderPermissionsAndFetchRequests,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary))
            : _nearbyRequests.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.car_repair,
                            size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text('لا توجد طلبات طوارئ أو أوناش حالياً',
                            style: TextStyle(
                                color: Colors.grey.shade400, fontSize: 14)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _nearbyRequests.length,
                    itemBuilder: (context, index) {
                      final req = _nearbyRequests[index];
                      final requestId = req['id'].toString();
                      final serviceType = req['service_type'] ?? 'mechanic';
                      final serviceTitle = serviceType == 'towing'
                          ? 'طلب ونش سحب (Pickup & Drop-off)'
                          : 'طلب ميكانيكي طوارئ';
                      final carDetails = req['car_details'] ?? 'غير متوفر';
                      final description = req['description'] ?? '';
                      final phone = req['phone'] ?? 'غير متوفر';
                      final dropoffAddress =
                          req['dropoff_address'] ?? 'وجهة الزبون المحددة';
                      final status = req['status'] ?? 'pending';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(serviceTitle,
                                    style: const TextStyle(
                                        color: AppTheme.warning,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                Text(carDetails,
                                    style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(description,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13)),
                            if (serviceType == 'towing') ...[
                              const SizedBox(height: 6),
                              Text('📍 وجهة النقل (Drop-off): $dropoffAddress',
                                  style: const TextStyle(
                                      color: AppTheme.primaryLight,
                                      fontSize: 12)),
                            ],
                            const SizedBox(height: 6),
                            Text('هاتف الزبون: $phone',
                                style: const TextStyle(
                                    color: AppTheme.primaryLight,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                            const Divider(color: Colors.white12, height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: status == 'pending'
                                  ? ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.success,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                      onPressed: () => _showAcceptOptionsDialog(
                                          requestId, serviceType),
                                      child: const Text(
                                          'قبول الطلب وتحديد المسار (تتبع تلقائي)',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold)),
                                    )
                                  : ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primary,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                      onPressed: () =>
                                          _showRepairProgressDialog(requestId),
                                      child: const Text(
                                          'تحديث مرحلة التصليح في الورشة',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold)),
                                    ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
