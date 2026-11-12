// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'product_detail_screen.dart';
import '../app_theme.dart';

class SearchResultsScreen extends StatefulWidget {
  final String searchQuery;
  final bool isArabic;

  const SearchResultsScreen({
    super.key,
    required this.searchQuery,
    required this.isArabic,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  bool _isLoading = true;
  List<dynamic> _searchResults = [];
  final Map<String, String> _sellerPhones = {};
  final Map<String, bool> _revealedPhones = {};

  @override
  void initState() {
    super.initState();
    _performSearch();
  }

  Future<void> _performSearch() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('products')
          .select()
          .eq('is_hidden', false);

      final data = List<dynamic>.from(res);
      final q = widget.searchQuery.toLowerCase();

      final filtered = data.where((p) {
        final title = (p['title'] ?? '').toString().toLowerCase();
        final carName = (p['car_name'] ?? '').toString().toLowerCase();
        final model = (p['car_model'] ?? '').toString().toLowerCase();
        final vin = (p['chassis_number'] ?? '').toString().toLowerCase();
        return title.contains(q) ||
            carName.contains(q) ||
            model.contains(q) ||
            vin.contains(q);
      }).toList();

      if (mounted) {
        setState(() {
          _searchResults = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Error searching: $e');
    }
  }

  Future<void> _fetchSellerPhone(String productId, String userId) async {
    try {
      var customerRes = await Supabase.instance.client
          .from('customers')
          .select('phone')
          .eq('id', userId)
          .maybeSingle();

      String phone = '';
      if (customerRes != null && customerRes['phone'] != null) {
        phone = customerRes['phone'].toString();
      } else {
        var profileRes = await Supabase.instance.client
            .from('profiles')
            .select('phone')
            .eq('id', userId)
            .maybeSingle();
        if (profileRes != null && profileRes['phone'] != null) {
          phone = profileRes['phone'].toString();
        }
      }

      if (mounted) {
        setState(() {
          _sellerPhones[productId] = phone.isNotEmpty
              ? phone
              : (widget.isArabic ? 'غير متوفر' : 'Not available');
          _revealedPhones[productId] = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sellerPhones[productId] = '0790000000';
          _revealedPhones[productId] = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          elevation: 0,
          title: Text(
            widget.isArabic
                ? 'نتائج البحث: "${widget.searchQuery}"'
                : 'Search Results: "${widget.searchQuery}"',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary))
            : _searchResults.isEmpty
                ? Center(
                    child: Text(
                      widget.isArabic
                          ? 'لا توجد نتائج مطابقة لبحثك'
                          : 'No matching results found',
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final product = _searchResults[index];
                      final List<dynamic> images = product['images'] ?? [];
                      final imgUrl = images.isNotEmpty ? images[0] : '';
                      final productId = product['id'].toString();
                      final userId = product['user_id'].toString();

                      final isRevealed = _revealedPhones[productId] ?? false;
                      final realPhone = _sellerPhones[productId] ??
                          (widget.isArabic
                              ? 'جاري جلب الرقم...'
                              : 'Fetching...');

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
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: imgUrl.isNotEmpty
                                    ? Image.network(imgUrl,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover)
                                    : Container(
                                        width: 80,
                                        height: 80,
                                        color: AppTheme.background,
                                        child: const Icon(Icons.image,
                                            color: Colors.grey),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product['title'] ?? '',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${product['car_name'] ?? ''} (${product['car_model'] ?? ''})',
                                      style: const TextStyle(
                                          color: AppTheme.primaryLight,
                                          fontSize: 13),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: SizedBox(
                                            height: 32,
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: isRevealed
                                                    ? AppTheme.success
                                                    : AppTheme.background,
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8)),
                                              ),
                                              icon: Icon(
                                                  isRevealed
                                                      ? Icons.phone
                                                      : Icons.phone_locked,
                                                  size: 14,
                                                  color: Colors.white),
                                              label: Text(
                                                isRevealed
                                                    ? realPhone
                                                    : (widget.isArabic
                                                        ? 'الهاتف'
                                                        : 'Phone'),
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              onPressed: () {
                                                if (!isRevealed) {
                                                  _fetchSellerPhone(
                                                      productId, userId);
                                                } else {
                                                  setState(() {
                                                    _revealedPhones[productId] =
                                                        false;
                                                  });
                                                }
                                              },
                                            ),
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
                      );
                    },
                  ),
      ),
    );
  }
}
