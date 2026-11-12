import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'add_product_screen.dart';
import 'product_detail_screen.dart';
import '../app_theme.dart';

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  bool _isLoading = true;
  String _selectedPeriod = 'all';

  double _totalRevenue = 0.0;
  int _totalViews = 0;
  int _totalProducts = 0;
  int _contactClicks = 0;

  DateTime? _customStartDate;
  List<Map<String, dynamic>> _sellerProducts = [];
  Map<int, Map<String, dynamic>> _dailySalesDetails = {};
  RealtimeChannel? _productsSubscription;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    if (_productsSubscription != null) {
      Supabase.instance.client.removeChannel(_productsSubscription!);
    }
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _productsSubscription = Supabase.instance.client
        .channel('public:products')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'products',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            if (mounted) {
              _fetchDashboardData();
            }
          },
        )
        .subscribe();
  }

  Future<void> _fetchDashboardData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      DateTime now = DateTime.now();
      DateTime? startDate;
      if (_selectedPeriod == '30days') {
        startDate = now.subtract(const Duration(days: 30));
      } else if (_selectedPeriod == '90days') {
        startDate = now.subtract(const Duration(days: 90));
      } else if (_selectedPeriod == 'year') {
        startDate = now.subtract(const Duration(days: 365));
      } else if (_selectedPeriod == 'custom' && _customStartDate != null) {
        startDate = _customStartDate!;
      } else {
        startDate = null;
      }

      final productsRes = await Supabase.instance.client
          .from('products')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final products = List<Map<String, dynamic>>.from(productsRes);

      int views = 0;
      double revenue = 0.0;
      Map<int, Map<String, dynamic>> dailySales = {};

      for (var p in products) {
        views += (p['views_count'] ?? 0) as int;

        bool isSold = p['is_sold'] ?? false;
        if (isSold) {
          DateTime? soldAt =
              p['sold_at'] != null ? DateTime.tryParse(p['sold_at']) : null;
          double itemPrice =
              ((p['sold_price'] ?? p['price'] ?? 0) as num).toDouble();

          if (startDate == null ||
              soldAt == null ||
              soldAt.isAfter(startDate) ||
              soldAt.isAtSameMomentAs(startDate)) {
            revenue += itemPrice;
          }

          if (soldAt != null &&
              soldAt.year == now.year &&
              soldAt.month == now.month) {
            int day = soldAt.day;
            dailySales[day] = {
              'amount':
                  ((dailySales[day]?['amount'] ?? 0.0) as double) + itemPrice,
              'date': '${soldAt.year}/${soldAt.month}/$day',
              'title': p['title'] ?? 'قطعة مباعة',
            };
          }
        }
      }

      if (mounted) {
        setState(() {
          _sellerProducts = products;
          _totalProducts = products.length;
          _totalViews = views;
          _totalRevenue = revenue;
          _contactClicks = products.where((p) => p['is_sold'] == true).length;
          _dailySalesDetails = dailySales;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Error loading dashboard: $e');
    }
  }

  Future<void> _markAsUnsold(String productId) async {
    await Supabase.instance.client.from('products').update({
      'is_sold': false,
      'sold_price': null,
      'sold_at': null,
    }).eq('id', productId);

    await _fetchDashboardData();
  }

  Future<void> _toggleHideProduct(String productId, bool currentStatus) async {
    await Supabase.instance.client.from('products').update({
      'is_hidden': !currentStatus,
    }).eq('id', productId);

    await _fetchDashboardData();
  }

  Future<void> _deleteProduct(String productId) async {
    await Supabase.instance.client
        .from('products')
        .delete()
        .eq('id', productId);
    await _fetchDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);

    List<BarChartRodData> barRods = [];
    for (int day = 1; day <= daysInMonth; day++) {
      double dayRevenue = _dailySalesDetails[day]?['amount'] ?? 0.0;
      barRods.add(
        BarChartRodData(
          toY: dayRevenue,
          color: dayRevenue > 0 ? AppTheme.success : Colors.white10,
          width: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: const Text(
          'لوحة تحكم البائع والأرباح',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryLight),
            onPressed: _fetchDashboardData,
            tooltip: 'تحديث البيانات',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPeriodChip('جميع الأوقات', 'all'),
                        const SizedBox(width: 8),
                        _buildPeriodChip('آخر 30 يوم', '30days'),
                        const SizedBox(width: 8),
                        _buildPeriodChip('آخر 90 يوم', '90days'),
                        const SizedBox(width: 8),
                        _buildPeriodChip('آخر سنة', 'year'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: 'إجمالي الأرباح',
                          value: '\$$_totalRevenue',
                          icon: Icons.account_balance_wallet_rounded,
                          color: AppTheme.success,
                          subtitle: 'حسب الفترة المحددة',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'مشاهدات الإعلانات',
                          value: '$_totalViews',
                          icon: Icons.remove_red_eye_rounded,
                          color: AppTheme.primaryLight,
                          subtitle: 'إجمالي مرات الظهور',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: 'نقرات التواصل',
                          value: '$_contactClicks',
                          icon: Icons.phone_callback_rounded,
                          color: AppTheme.warning,
                          subtitle: 'ضغط الزبائن على الرقم',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'القطع المعروضة',
                          value: '$_totalProducts',
                          icon: Icons.inventory_2_rounded,
                          color: AppTheme.primary,
                          subtitle: 'جميع منشوراتك',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'أداء المبيعات لشهر ${now.month}/${now.year} (أعمدة تفاعلية)',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'مباشر (Real-time) ✓',
                        style: TextStyle(
                            color: AppTheme.success,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 240,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: BarChart(
                      BarChartData(
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (group) => AppTheme.background,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              int day = group.x.toInt();
                              double amount = rod.toY;
                              var saleData = _dailySalesDetails[day];
                              String dateStr = saleData != null
                                  ? saleData['date']
                                  : 'اليوم $day';
                              return BarTooltipItem(
                                '$dateStr\nالمبلغ: \$$amount',
                                const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              );
                            },
                          ),
                        ),
                        gridData:
                            FlGridData(show: true, drawVerticalLine: false),
                        titlesData: FlTitlesData(
                          rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              getTitlesWidget: (val, meta) {
                                return Text('\$${val.toInt()}',
                                    style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 10));
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              interval: 5,
                              getTitlesWidget: (val, meta) {
                                int day = val.toInt();
                                if (day == 1 ||
                                    day == 5 ||
                                    day == 10 ||
                                    day == 15 ||
                                    day == 20 ||
                                    day == 25 ||
                                    day == daysInMonth) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Text('\$day',
                                        style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 10)),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: List.generate(daysInMonth, (index) {
                          int day = index + 1;
                          return BarChartGroupData(
                            x: day,
                            barRods: [barRods[index]],
                          );
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'إدارة منشوراتك وقطعك المعروضة',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _sellerProducts.isEmpty
                      ? const Center(
                          child: Text('لا توجد منشورات حالياً',
                              style: TextStyle(color: AppTheme.textSecondary)))
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _sellerProducts.length,
                          itemBuilder: (context, index) {
                            final product = _sellerProducts[index];
                            final bool isSold = product['is_sold'] ?? false;
                            final bool isHidden = product['is_hidden'] ?? false;
                            final double price =
                                ((product['price'] ?? 0) as num).toDouble();
                            final double soldPrice =
                                ((product['sold_price'] ?? price) as num)
                                    .toDouble();
                            final int viewsCount =
                                (product['views_count'] ?? 0) as int;

                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ProductDetailScreen(product: product),
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSold
                                        ? AppTheme.success
                                            .withValues(alpha: 0.5)
                                        : isHidden
                                            ? AppTheme.warning
                                                .withValues(alpha: 0.5)
                                            : Colors.white12,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: (product['images'] != null &&
                                              (product['images'] as List)
                                                  .isNotEmpty)
                                          ? Image.network(product['images'][0],
                                              width: 60,
                                              height: 60,
                                              fit: BoxFit.cover)
                                          : Container(
                                              width: 60,
                                              height: 60,
                                              color: AppTheme.background,
                                              child: const Icon(Icons.image)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product['title'] ?? '',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            isSold
                                                ? 'تم البيع بمبلغ: \$$soldPrice'
                                                : isHidden
                                                    ? 'المنتج مخفي حالياً'
                                                    : 'السعر الأساسي: \$$price',
                                            style: TextStyle(
                                              color: isSold
                                                  ? AppTheme.success
                                                  : isHidden
                                                      ? AppTheme.warning
                                                      : AppTheme.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '👁 عدد المشاهدات: $viewsCount',
                                            style: const TextStyle(
                                                color: AppTheme.primaryLight,
                                                fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        if (!isSold)
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.success,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              minimumSize: Size.zero,
                                            ),
                                            onPressed: () =>
                                                _showMarkAsSoldDialog(
                                                    product['id'].toString(),
                                                    price),
                                            child: const Text('هل تم بيعه؟',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.white)),
                                          )
                                        else
                                          TextButton(
                                            style: TextButton.styleFrom(
                                                padding: EdgeInsets.zero,
                                                minimumSize: Size.zero),
                                            onPressed: () => _markAsUnsold(
                                                product['id'].toString()),
                                            child: const Text(
                                                'إلغاء البيع (غير مباع)',
                                                style: TextStyle(
                                                    color: AppTheme.warning,
                                                    fontSize: 11)),
                                          ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            InkWell(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        AddProductScreen(
                                                            productToEdit:
                                                                product),
                                                  ),
                                                ).then((_) =>
                                                    _fetchDashboardData());
                                              },
                                              child: const Text('تعديل',
                                                  style: TextStyle(
                                                      color:
                                                          AppTheme.primaryLight,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ),
                                            const SizedBox(width: 8),
                                            InkWell(
                                              onTap: () => _toggleHideProduct(
                                                  product['id'].toString(),
                                                  isHidden),
                                              child: Text(
                                                isHidden ? 'إظهار' : 'إخفاء',
                                                style: TextStyle(
                                                  color: isHidden
                                                      ? AppTheme.primaryLight
                                                      : AppTheme.warning,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            InkWell(
                                              onTap: () => _deleteProduct(
                                                  product['id'].toString()),
                                              child: const Icon(
                                                Icons.delete_outline_rounded,
                                                color: AppTheme.error,
                                                size: 18,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  void _showMarkAsSoldDialog(String productId, double currentPrice) {
    final priceController =
        TextEditingController(text: currentPrice.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('تحديد المنتج كمبيع',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('الرجاء إدخال المبلغ الفعلي الذي تم بيع القطعة به:',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'مبلغ البيع (\$)',
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.background,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
            onPressed: () async {
              final soldPrice =
                  double.tryParse(priceController.text) ?? currentPrice;
              Navigator.pop(context);

              await Supabase.instance.client.from('products').update({
                'is_sold': true,
                'sold_price': soldPrice,
                'sold_at': DateTime.now().toIso8601String(),
              }).eq('id', productId);

              await _fetchDashboardData();
            },
            child: const Text('تأكيد البيع',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return InkWell(
      onTap: () {
        setState(() => _selectedPeriod = value);
        _fetchDashboardData();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isSelected ? Colors.transparent : Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_upward, color: color, size: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }
}
