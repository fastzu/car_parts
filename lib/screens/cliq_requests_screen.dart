// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_theme.dart';

class CliqRequestsScreen extends StatefulWidget {
  const CliqRequestsScreen({super.key});

  @override
  State<CliqRequestsScreen> createState() => _CliqRequestsScreenState();
}

class _CliqRequestsScreenState extends State<CliqRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _pendingCliqRequests = [];
  List<dynamic> _historyCliqRequests = [];
  final bool _isArabic = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchCliqData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchCliqData() async {
    setState(() => _isLoading = true);
    try {
      // افتراض أن جدول طلبات الكليك اسمه cliq_requests أو subscriptions
      // سنقوم بجلب الطلبات المعلقة وتاريخ السجل (History)
      final res = await Supabase.instance.client
          .from('cliq_requests') // أو جدول طلبات الكليك المعتمد لديك
          .select()
          .order('created_at', ascending: false);

      final List<dynamic> allData = List<dynamic>.from(res);

      if (mounted) {
        setState(() {
          _pendingCliqRequests = allData
              .where((item) =>
                  item['status'] == 'pending' || item['status'] == 'active')
              .toList();
          _historyCliqRequests = allData
              .where((item) =>
                  item['status'] == 'completed' ||
                  item['status'] == 'rejected' ||
                  item['status'] == 'paid')
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      // إذا لم يكن الجدول موجوداً بعد أو حدث خطأ، نضع بيانات تجريبية لتجنب توقف الشاشة
      if (mounted) {
        setState(() {
          _pendingCliqRequests = [];
          _historyCliqRequests = [];
          _isLoading = false;
        });
      }
      debugPrint('Error fetching Cliq requests: $e');
    }
  }

  Future<void> _updateRequestStatus(String id, String newStatus) async {
    try {
      await Supabase.instance.client
          .from('cliq_requests')
          .update({'status': newStatus}).eq('id', id);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isArabic
              ? 'تم تحديث حالة الطلب بنجاح'
              : 'Status updated successfully'),
          backgroundColor: AppTheme.success,
        ),
      );
      _fetchCliqData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          title: Text(
            _isArabic ? 'إدارة ومراجعة طلبات CliQ' : 'CliQ Requests & History',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primaryLight,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(
                  text: _isArabic
                      ? 'الطلبات المعلقة والنشطة'
                      : 'Active / Pending'),
              Tab(text: _isArabic ? 'سجل الطلبات (History)' : 'History Log'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary))
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildRequestsList(_pendingCliqRequests, isHistory: false),
                  _buildRequestsList(_historyCliqRequests, isHistory: true),
                ],
              ),
      ),
    );
  }

  Widget _buildRequestsList(List<dynamic> requests, {required bool isHistory}) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_rounded,
                color: Colors.grey, size: 48),
            const SizedBox(height: 12),
            Text(
              _isArabic
                  ? 'لا توجد طلبات كليك في هذا القسم'
                  : 'No Cliq requests found',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        final id = req['id'].toString();
        final username = req['username'] ?? req['full_name'] ?? 'مستخدم';
        final amount = req['amount'] ?? req['price'] ?? '0';
        final status = req['status'] ?? 'pending';
        final date = req['created_at'] != null
            ? req['created_at'].toString().substring(0, 10)
            : '';

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
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
                  Text(
                    'المرسل: $username',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: status == 'completed' || status == 'paid'
                          ? AppTheme.success.withValues(alpha: 0.2)
                          : AppTheme.warning.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: status == 'completed' || status == 'paid'
                            ? AppTheme.success
                            : AppTheme.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'المبلغ: $amount دينار',
                style:
                    const TextStyle(color: AppTheme.primaryLight, fontSize: 13),
              ),
              if (date.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('التاريخ: $date',
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 11)),
              ],
              if (!isHistory) ...[
                const Divider(color: Colors.white12, height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.success),
                        onPressed: () => _updateRequestStatus(id, 'completed'),
                        icon: const Icon(Icons.check,
                            size: 14, color: Colors.white),
                        label: Text(_isArabic ? 'قبول وتوثيق' : 'Approve',
                            style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.error),
                        onPressed: () => _updateRequestStatus(id, 'rejected'),
                        icon: const Icon(Icons.close,
                            size: 14, color: Colors.white),
                        label: Text(_isArabic ? 'رفض' : 'Reject',
                            style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ]
            ],
          ),
        );
      },
    );
  }
}
