import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminAdsScreen extends StatefulWidget {
  const AdminAdsScreen({super.key});

  @override
  State<AdminAdsScreen> createState() => _AdminAdsScreenState();
}

class _AdminAdsScreenState extends State<AdminAdsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _adsList = [];

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _fetchAds();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _fetchAds() async {
    try {
      final response = await Supabase.instance.client
          .from('advertisements')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _adsList = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ في جلب الإعلانات: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addOrUpdateAd({String? adId}) async {
    final title = _titleController.text.trim();
    final imageUrl = _imageUrlController.text.trim();

    if (title.isEmpty || imageUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('الرجاء إدخال العنوان ورابط الصورة'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      if (adId == null) {
        await Supabase.instance.client.from('advertisements').insert({
          'title': title,
          'image_url': imageUrl,
          'is_active': _isActive,
        });
      } else {
        await Supabase.instance.client.from('advertisements').update({
          'title': title,
          'image_url': imageUrl,
          'is_active': _isActive,
        }).eq('id', adId);
      }

      _titleController.clear();
      _imageUrlController.clear();
      if (mounted) Navigator.pop(context);
      _fetchAds();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم حفظ الإعلان بنجاح'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحفظ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteAd(String adId) async {
    try {
      await Supabase.instance.client
          .from('advertisements')
          .delete()
          .eq('id', adId);
      setState(() {
        _adsList.removeWhere((ad) => ad['id'].toString() == adId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم حذف الإعلان بنجاح'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحذف: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAdDialog({Map<String, dynamic>? ad}) {
    if (ad != null) {
      _titleController.text = ad['title'] ?? '';
      _imageUrlController.text = ad['image_url'] ?? '';
      _isActive = ad['is_active'] ?? true;
    } else {
      _titleController.clear();
      _imageUrlController.clear();
      _isActive = true;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            ad == null ? 'إضافة إعلان جديد' : 'تعديل الإعلان',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'عنوان الإعلان',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _imageUrlController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'رابط صورة الإعلان (URL)',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey)),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('تفعيل الإعلان (Active)',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                value: _isActive,
                activeThumbColor: const Color(0xFF34D399),
                onChanged: (val) => setDialogState(() => _isActive = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6)),
              onPressed: () => _addOrUpdateAd(adId: ad?['id']?.toString()),
              child: const Text('حفظ', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('لوحة تحكم الإعلانات (Admin)',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFF3B82F6),
          child: const Icon(Icons.add, color: Colors.white),
          onPressed: () => _showAdDialog(),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
            : _adsList.isEmpty
                ? const Center(
                    child: Text('لا توجد إعلانات مضافة حالياً',
                        style: TextStyle(color: Colors.grey, fontSize: 14)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _adsList.length,
                    itemBuilder: (context, index) {
                      final ad = _adsList[index];
                      final isActive = ad['is_active'] ?? false;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              ad['image_url'] ?? '',
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image,
                                      color: Colors.grey, size: 30),
                            ),
                          ),
                          title: Text(ad['title'] ?? '',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            isActive ? 'الحالة: نشط ✅' : 'الحالة: متوقف ❌',
                            style: TextStyle(
                                color: isActive
                                    ? const Color(0xFF34D399)
                                    : Colors.redAccent,
                                fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: Color(0xFF60A5FA), size: 20),
                                onPressed: () => _showAdDialog(ad: ad),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.redAccent, size: 20),
                                onPressed: () => _deleteAd(ad['id'].toString()),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
