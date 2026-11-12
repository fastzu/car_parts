// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_screen.dart';
import 'user_profile_screen.dart';
import 'checkout_screen.dart';
import '../app_theme.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  String? _sellerPhone;
  bool _isPhoneRevealed = false;
  String _sellerName = 'البائع';

  @override
  void initState() {
    super.initState();
    _incrementViews();
    _fetchSellerInfo();
  }

  Future<void> _incrementViews() async {
    try {
      final currentViews = (widget.product['views_count'] ?? 0) as int;
      await Supabase.instance.client.from('products').update(
          {'views_count': currentViews + 1}).eq('id', widget.product['id']);
    } catch (_) {}
  }

  Future<void> _fetchSellerInfo() async {
    final sellerId = widget.product['user_id']?.toString();
    if (sellerId == null) return;

    try {
      var res = await Supabase.instance.client
          .from('customers')
          .select('username, full_name, phone')
          .eq('id', sellerId)
          .maybeSingle();

      res ??= await Supabase.instance.client
          .from('profiles')
          .select('username, full_name, phone')
          .eq('id', sellerId)
          .maybeSingle();

      if (res != null && mounted) {
        setState(() {
          _sellerName = res!['username'] ?? res['full_name'] ?? 'البائع';
          _sellerPhone = res['phone']?.toString();
        });
      }
    } catch (e) {
      debugPrint('Error fetching seller info: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.product['images'] as List? ?? [];
    final imageUrl = images.isNotEmpty ? images[0] : null;
    final sellerId = widget.product['user_id']?.toString() ?? '';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          title: Text(widget.product['title'] ?? 'تفاصيل القطعة',
              style: const TextStyle(color: Colors.white, fontSize: 16)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null)
                Image.network(imageUrl,
                    width: double.infinity, height: 250, fit: BoxFit.cover)
              else
                Container(
                  width: double.infinity,
                  height: 250,
                  color: AppTheme.surface,
                  child: const Icon(Icons.image,
                      size: 64, color: AppTheme.textSecondary),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product['title'] ?? '',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.product['price'] ?? 0} د.أ',
                      style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    GestureDetector(
                      onTap: () {
                        if (sellerId.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserProfileScreen(
                                  userId: sellerId, userName: _sellerName),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppTheme.background,
                              child: Text(
                                  _sellerName.isNotEmpty
                                      ? _sellerName[0].toUpperCase()
                                      : 'B',
                                  style: const TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('البائع / المعرض',
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 11)),
                                  Text(_sellerName,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14)),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios,
                                color: Colors.grey, size: 14),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(
                        'القسم: ${widget.product['category'] ?? widget.product['main_category'] ?? 'عام'}',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'الوصف:',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.product['description'] ?? 'لا يوجد وصف متوفر.',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 30),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.chat_bubble_rounded,
                                color: Colors.white, size: 18),
                            label: const Text('مراسلة البائع',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            onPressed: () {
                              if (sellerId.isNotEmpty) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatScreen(
                                      receiverId: sellerId,
                                      receiverName: _sellerName,
                                      productId:
                                          widget.product['id'].toString(),
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isPhoneRevealed
                                  ? AppTheme.success
                                  : AppTheme.surface,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              side: BorderSide(
                                  color: _isPhoneRevealed
                                      ? Colors.transparent
                                      : AppTheme.border),
                            ),
                            icon: Icon(
                                _isPhoneRevealed
                                    ? Icons.phone
                                    : Icons.phone_locked,
                                color: Colors.white,
                                size: 18),
                            label: Text(
                              _isPhoneRevealed
                                  ? (_sellerPhone ?? 'غير متوفر')
                                  : 'اتصال بالهاتف',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPhoneRevealed = !_isPhoneRevealed;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.success,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(
                              Icons.shopping_cart_checkout,
                              color: Colors.white,
                              size: 18,
                            ),
                            label: const Text(
                              'اشتري الآن (Buy Now)',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CheckoutScreen(
                                    product: widget.product,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
