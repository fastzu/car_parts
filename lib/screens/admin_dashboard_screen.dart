// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../app_theme.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _titleController = TextEditingController();
  bool _isLoadingAds = false;
  bool _enforceLimits = true;
  bool _isLoadingLimits = true;
  XFile? _selectedImage;
  List<Map<String, dynamic>> _adsList = [];

  @override
  void initState() {
    super.initState();
    _fetchAds();
    _fetchSystemSettings();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _fetchAds() async {
    setState(() => _isLoadingAds = true);
    try {
      final res = await Supabase.instance.client
          .from('advertisements')
          .select()
          .order('created_at', ascending: false);

      final data = res as List<dynamic>? ?? const [];
      setState(() {
        _adsList =
            data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      });
    } catch (e) {
      debugPrint('Error fetching ads: $e');
    } finally {
      setState(() => _isLoadingAds = false);
    }
  }

  Future<void> _fetchSystemSettings() async {
    try {
      final res = await Supabase.instance.client
          .from('system_settings')
          .select('value')
          .eq('key', 'enforce_posting_limits')
          .maybeSingle();

      if (res != null && mounted) {
        setState(() {
          final val = res['value'];
          _enforceLimits =
              val == true || val.toString().toLowerCase() == 'true';
          _isLoadingLimits = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching system settings: $e');
      if (mounted) setState(() => _isLoadingLimits = false);
    }
  }

  Future<void> _togglePostingLimits(bool value) async {
    setState(() => _enforceLimits = value);
    try {
      await Supabase.instance.client.from('system_settings').update(
          {'value': value.toString()}).eq('key', 'enforce_posting_limits');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'تم تفعيل قيود النشر (4 مجاناً ثم كل 24 ساعة)'
                  : 'تم إيقاف قيود النشر (مفتوح للجميع بدون قيود)',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ أثناء تحديث الإعدادات: $e'),
              backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _selectedImage = pickedFile);
    }
  }

  Future<void> _createAd() async {
    if (_titleController.text.trim().isEmpty || _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('يرجى إدخال عنوان الإعلان واختيار صورة'),
            backgroundColor: AppTheme.warning),
      );
      return;
    }

    setState(() => _isLoadingAds = true);
    try {
      final bytes = await _selectedImage!.readAsBytes();
      final fileName =
          'ad_${DateTime.now().millisecondsSinceEpoch}_${_selectedImage!.name}';

      await Supabase.instance.client.storage
          .from('product_images')
          .uploadBinary(fileName, bytes);

      final imageUrl = Supabase.instance.client.storage
          .from('product_images')
          .getPublicUrl(fileName);

      await Supabase.instance.client
          .from('advertisements')
          .update({'is_active': false}).eq('is_active', true);

      await Supabase.instance.client.from('advertisements').insert({
        'title': _titleController.text.trim(),
        'image_url': imageUrl,
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
      });

      _titleController.clear();
      setState(() => _selectedImage = null);
      await _fetchAds();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم نشر وتفعيل الإعلان بنجاح',
                  style: TextStyle(color: Colors.white)),
              backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ أثناء رفع الإعلان: $e'),
              backgroundColor: AppTheme.error),
        );
      }
    } finally {
      setState(() => _isLoadingAds = false);
    }
  }

  Future<void> _toggleAdStatus(String id, bool currentStatus) async {
    try {
      if (!currentStatus) {
        await Supabase.instance.client
            .from('advertisements')
            .update({'is_active': false}).eq('is_active', true);
      }

      await Supabase.instance.client
          .from('advertisements')
          .update({'is_active': !currentStatus}).eq('id', id);

      await _fetchAds();
    } catch (e) {
      debugPrint('Error toggling ad: $e');
    }
  }

  Future<void> _deleteAd(String id) async {
    try {
      await Supabase.instance.client
          .from('advertisements')
          .delete()
          .eq('id', id);
      await _fetchAds();
    } catch (e) {
      debugPrint('Error deleting ad: $e');
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
          title: const Text('لوحة تحكم الادمن (الإعلانات والنظام)',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('إعدادات النظام العامة',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('قيود النشر (4 مجاناً ثم كل 24 ساعة)',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                          SizedBox(height: 4),
                          Text('تفعيل أو إيقاف شروط النشر للمستخدمين',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    _isLoadingLimits
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Switch(
                            value: _enforceLimits,
                            activeThumbColor: AppTheme.primary,
                            onChanged: _togglePostingLimits,
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('إنشاء إعلان جديد',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'عنوان الإعلان',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: AppTheme.background,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primary),
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: kIsWeb
                              ? Image.network(_selectedImage!.path,
                                  fit: BoxFit.cover)
                              : Image.file(File(_selectedImage!.path),
                                  fit: BoxFit.cover),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate,
                                color: AppTheme.primary, size: 36),
                            SizedBox(height: 6),
                            Text('اضغط لاختيار صورة الإعلان',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoadingAds ? null : _createAd,
                  child: _isLoadingAds
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('نشر وتفعيل الإعلان',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 30),
              const Text('جميع الإعلانات السابقة',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _isLoadingAds
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary))
                  : _adsList.isEmpty
                      ? const Text('لا توجد إعلانات مضافة',
                          style: TextStyle(color: Colors.grey))
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _adsList.length,
                          itemBuilder: (context, index) {
                            final ad = _adsList[index];
                            final isActive = ad['is_active'] ?? false;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: isActive
                                        ? AppTheme.success
                                        : AppTheme.border),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      ad['image_url'] ?? '',
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                        width: 60,
                                        height: 60,
                                        color: AppTheme.border,
                                        child: const Icon(Icons.broken_image,
                                            color: Colors.white),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(ad['title'] ?? '',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text(
                                          isActive
                                              ? 'الحالة: نشط (يعرض الآن)'
                                              : 'الحالة: متوقف',
                                          style: TextStyle(
                                              color: isActive
                                                  ? AppTheme.success
                                                  : Colors.grey,
                                              fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: isActive,
                                    activeThumbColor: AppTheme.primary,
                                    onChanged: (val) => _toggleAdStatus(
                                        ad['id'].toString(), isActive),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: AppTheme.error),
                                    onPressed: () =>
                                        _deleteAd(ad['id'].toString()),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ],
          ),
        ),
      ),
    );
  }
}
