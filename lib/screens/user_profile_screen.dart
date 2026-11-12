// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'product_detail_screen.dart';
import '../app_theme.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const UserProfileScreen(
      {super.key, required this.userId, required this.userName});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isLoading = true;
  List<dynamic> _userProducts = [];
  Map<String, dynamic>? _userInfo;

  @override
  void initState() {
    super.initState();
    _fetchUserDataAndProducts();
  }

  Future<void> _fetchUserDataAndProducts() async {
    setState(() => _isLoading = true);
    try {
      // جلب بيانات الحساب
      var userRes = await Supabase.instance.client
          .from('customers')
          .select()
          .eq('id', widget.userId)
          .maybeSingle();

      userRes ??= await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', widget.userId)
          .maybeSingle();

      // جلب منتجات هذا المستخدم فقط
      final productsRes = await Supabase.instance.client
          .from('products')
          .select()
          .eq('user_id', widget.userId)
          .eq('is_hidden', false);

      if (mounted) {
        setState(() {
          _userInfo = userRes;
          _userProducts = List<dynamic>.from(productsRes);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Error fetching profile: $e');
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
          title: Text('بروفايل: ${widget.userName}',
              style: const TextStyle(color: Colors.white, fontSize: 16)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: AppTheme.background,
                            child: Text(
                              widget.userName.isNotEmpty
                                  ? widget.userName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.userName,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(_userInfo?['email'] ?? 'مستخدم معتمد',
                                    style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 13)),
                                const SizedBox(height: 4),
                                Text('الدور: ${_userInfo?['role'] ?? 'user'}',
                                    style: const TextStyle(
                                        color: AppTheme.warning, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('القطع والمنتجات المعروضة من قبل هذا العميل:',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 14),
                    _userProducts.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Text('لا توجد منتجات معروضة حالياً',
                                  style:
                                      TextStyle(color: Colors.grey.shade400)),
                            ),
                          )
                        : GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.75,
                            ),
                            itemCount: _userProducts.length,
                            itemBuilder: (context, index) {
                              final product = _userProducts[index];
                              final List<dynamic> images =
                                  product['images'] ?? [];
                              final imgUrl = images.isNotEmpty ? images[0] : '';

                              return InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            ProductDetailScreen(
                                                product: product)),
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                  top: Radius.circular(16)),
                                          child: imgUrl.isNotEmpty
                                              ? Image.network(imgUrl,
                                                  width: double.infinity,
                                                  fit: BoxFit.cover)
                                              : Container(
                                                  color: AppTheme.background,
                                                  child: const Icon(Icons.image,
                                                      color: Colors.grey)),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(10.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(product['title'] ?? '',
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                            const SizedBox(height: 4),
                                            Text('${product['price'] ?? 0} د.أ',
                                                style: const TextStyle(
                                                    color:
                                                        AppTheme.primaryLight,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
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
