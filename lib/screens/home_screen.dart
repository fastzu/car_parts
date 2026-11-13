// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'security_settings_screen.dart';
import 'personal_info_screen.dart';
import 'add_product_screen.dart';
import 'seller_dashboard_screen.dart';
import 'admin_dashboard_screen.dart';
import 'chat_screen.dart';
import 'conversations_screen.dart';
import 'product_detail_screen.dart';
import 'membership_screen.dart';
import 'request_mechanic_screen.dart';
import 'mechanic_request_screen.dart';
import 'mechanic_dashboard_screen.dart';
import 'cliq_requests_screen.dart';
import 'search_results_screen.dart';
import 'book_workshop_screen.dart';
import 'workshop_dashboard_screen.dart';
import 'notifications_screen.dart';
import 'my_appointments_screen.dart';
import 'wallet_screen.dart';
import '../app_theme.dart';

class HomeScreen extends StatefulWidget {
  final bool showTutorialOnStart;

  const HomeScreen({super.key, this.showTutorialOnStart = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isArabic = true;
  int _currentIndex = 0;

  String _dbUsername = 'قائد المركبة';
  String _dbEmail = 'user@ghayarak.com';
  String _userRole = 'user';
  bool _enforcePostingLimits = false;

  final Set<String> _trustedSellers = {};

  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategoryFilter;

  Timer? _refreshTimer;

  Map<String, dynamic>? _activeAd;
  bool _isLoadingAd = true;

  List<dynamic> _newArrivalsProducts = [];
  List<dynamic> _popularProducts = [];
  bool _isLoadingProducts = true;

  RealtimeChannel? _homeProductsSubscription;

  final List<Map<String, dynamic>> _allCategories = [
    {
      'name': 'ALL',
      'arName': 'الكل',
      'enName': 'All',
      'icon': Icons.grid_view_rounded,
      'gradient': [AppTheme.primary, const Color(0xFFF97316)],
    },
    {
      'name': 'المحرك وملحقاته (Engine)',
      'arName': 'المحرك وملحقاته',
      'enName': 'Engine',
      'icon': Icons.settings_suggest,
      'gradient': [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
    },
    {
      'name': 'نظام التبريد (Cooling System)',
      'arName': 'نظام التبريد',
      'enName': 'Cooling',
      'icon': Icons.ac_unit,
      'gradient': [const Color(0xFF06B6D4), const Color(0xFF0E7490)],
    },
    {
      'name': 'نظام الوقود والعادم (Fuel & Exhaust)',
      'arName': 'الوقود والعادم',
      'enName': 'Fuel & Exhaust',
      'icon': Icons.local_gas_station,
      'gradient': [const Color(0xFF10B981), const Color(0xFF047857)],
    },
    {
      'name': 'نظام التعليق والتوجيه (Suspension & Steering)',
      'arName': 'التعليق والتوجيه',
      'enName': 'Suspension',
      'icon': Icons.alt_route,
      'gradient': [const Color(0xFFF59E0B), const Color(0xFFB45309)],
    },
    {
      'name': 'نظام الفرامل (Braking System)',
      'arName': 'نظام الفرامل',
      'enName': 'Brakes',
      'icon': Icons.disc_full,
      'gradient': [const Color(0xFFEF4444), const Color(0xFFB91C1C)],
    },
    {
      'name': 'الكهرباء والإلكترونيات (Electrical System)',
      'arName': 'الكهرباء والإلكترونيات',
      'enName': 'Electrical',
      'icon': Icons.bolt,
      'gradient': [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
    },
    {
      'name': 'الإضاءة والرؤية (Lighting & Vision)',
      'arName': 'الإضاءة والرؤية',
      'enName': 'Lighting',
      'icon': Icons.lightbulb_outline,
      'gradient': [const Color(0xFFEC4899), const Color(0xFFBE185D)],
    },
    {
      'name': 'نقل الحركة ونظام الدوران (Transmission & Drivetrain)',
      'arName': 'نقل الحركة',
      'enName': 'Transmission',
      'icon': Icons.swap_horiz,
      'gradient': [const Color(0xFF6366F1), const Color(0xFF4338CA)],
    },
    {
      'name': 'جسم السيارة والديكور الخارجي (Body & Interior)',
      'arName': 'الهيكل والداخلية',
      'enName': 'Body & Interior',
      'icon': Icons.directions_car,
      'gradient': [const Color(0xFF14B8A6), const Color(0xFF0F766E)],
    },
    {
      'name': 'التكييف والتدفئة (HVAC)',
      'arName': 'التكييف والتدفئة',
      'enName': 'HVAC',
      'icon': Icons.mode_fan_off,
      'gradient': [const Color(0xFF0EA5E9), const Color(0xFF0369A1)],
    },
    {
      'name': 'الإطارات والجنوط (Tires & Wheels)',
      'arName': 'الإطارات والجنوط',
      'enName': 'Tires & Wheels',
      'icon': Icons.tire_repair,
      'gradient': [const Color(0xFFFB923C), const Color(0xFFC2410C)],
    },
    {
      'name': 'أخرى وعامة (General & Misc)',
      'arName': 'أخرى وعامة',
      'enName': 'General',
      'icon': Icons.more_horiz,
      'gradient': [const Color(0xFF64748B), const Color(0xFF334155)],
    },
  ];

  final Map<String, String> _sellerPhones = {};
  final Map<String, bool> _revealedPhones = {};

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _fetchTrustedSellers();
    await _fetchUserDataFromSupabase();
    await _fetchSystemSettings();
    await _fetchActiveAdvertisement();
    await _fetchAllProducts();
    _setupHomeRealtime();

    if (widget.showTutorialOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showWelcomeTutorialDialog();
      });
    }

    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted) {
        _fetchAllProducts();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    if (_homeProductsSubscription != null) {
      Supabase.instance.client.removeChannel(_homeProductsSubscription!);
    }
    super.dispose();
  }

  Future<void> _fetchSystemSettings() async {
    try {
      final res = await Supabase.instance.client
          .from('system_settings')
          .select('value')
          .eq('key', 'enforce_posting_limits')
          .maybeSingle();

      if (mounted) {
        setState(() {
          final val = res?['value'];
          _enforcePostingLimits =
              val == true || val.toString().toLowerCase() == 'true';
        });
      }
    } catch (e) {
      debugPrint('Error fetching system settings: $e');
    }
  }

  Future<void> _fetchTrustedSellers() async {
    try {
      final res = await Supabase.instance.client
          .from('subscription_requests')
          .select('user_id, status');

      if (mounted) {
        setState(() {
          _trustedSellers.clear();
          for (var item in res) {
            final status =
                item['status']?.toString().toLowerCase().trim() ?? '';
            final userId = item['user_id']?.toString().trim();

            if (userId != null &&
                (status == 'approved' ||
                    status == 'active' ||
                    status.contains('approv'))) {
              _trustedSellers.add(userId);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching trusted sellers: $e');
    }
  }

  Future<void> _fetchAllProducts() async {
    try {
      final query = Supabase.instance.client
          .from('products')
          .select()
          .eq('is_hidden', false);

      final filteredQuery = _selectedCategoryFilter == null
          ? query
          : query.eq('main_category', _selectedCategoryFilter!);

      final newRes =
          await filteredQuery.order('created_at', ascending: false).limit(8);

      final popularRes =
          await filteredQuery.order('views_count', ascending: false).limit(8);

      if (mounted) {
        setState(() {
          _newArrivalsProducts = List<dynamic>.from(newRes);
          _popularProducts = List<dynamic>.from(popularRes);
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingProducts = false);
      }
      debugPrint('Error fetching products: $e');
    }
  }

  void _setupHomeRealtime() {
    _homeProductsSubscription = Supabase.instance.client
        .channel('public:home_products')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'products',
          callback: (payload) {
            if (mounted) {
              _fetchAllProducts();
              _fetchTrustedSellers();
            }
          },
        )
        .subscribe();
  }

  void _showWelcomeTutorialDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.waving_hand,
                  color: AppTheme.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              _isArabic ? 'أهلاً بك في متجر غيارك!' : 'Welcome to Ghayarak!',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          _isArabic
              ? 'منصة غيارك تتيح لك البحث عن أصل قطع غيار السيارات، التواصل المباشر مع التجار، وعرض قطعك للبيع بكل سهولة.'
              : 'Ghayarak helps you find original auto parts and connect directly with sellers.',
          style:
              TextStyle(color: Colors.grey.shade300, fontSize: 13, height: 1.4),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(
                _isArabic ? 'ابدأ الاستخدام الآن' : 'Get Started',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchUserDataFromSupabase() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        var data = await Supabase.instance.client
            .from('customers')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        data ??= await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (data != null && mounted) {
          setState(() {
            _dbUsername =
                data!['username'] ?? data['full_name'] ?? 'قائد المركبة';
            _dbEmail = data['email'] ?? user.email ?? 'user@ghayarak.com';
            _userRole =
                (data['role'] ?? 'user').toString().trim().toLowerCase();
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching user info: $e');
    }
  }

  Future<void> _fetchActiveAdvertisement() async {
    try {
      final res = await Supabase.instance.client
          .from('advertisements')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _activeAd = res;
          _isLoadingAd = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAd = false);
      }
    }
  }

  void _showAddAdBottomSheet() {
    final titleController = TextEditingController();
    XFile? pickedMedia;
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isArabic ? 'إضافة إعلان جديد' : 'Add New Ad',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: _isArabic ? 'عنوان الإعلان' : 'Ad Title',
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: AppTheme.background,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final image =
                          await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        setModalState(() {
                          pickedMedia = image;
                        });
                      }
                    },
                    child: Container(
                      height: 130,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.primary),
                      ),
                      child: pickedMedia != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: kIsWeb
                                  ? Image.network(pickedMedia!.path,
                                      fit: BoxFit.cover)
                                  : Image.file(File(pickedMedia!.path),
                                      fit: BoxFit.cover),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_photo_alternate_rounded,
                                    color: AppTheme.primary, size: 36),
                                const SizedBox(height: 8),
                                Text(
                                    _isArabic
                                        ? 'اضغط لاختيار صورة أو فيديو للإعلان'
                                        : 'Tap to select ad image/video',
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: isUploading
                          ? null
                          : () async {
                              if (titleController.text.trim().isEmpty ||
                                  pickedMedia == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(_isArabic
                                          ? 'الرجاء إدخال العنوان واختيار الوسائط'
                                          : 'Please enter title and select media')),
                                );
                                return;
                              }

                              setModalState(() => isUploading = true);

                              try {
                                final bytes = await pickedMedia!.readAsBytes();
                                final fileName =
                                    'ad_${DateTime.now().millisecondsSinceEpoch}_${pickedMedia!.name}';

                                await Supabase.instance.client.storage
                                    .from('product_images')
                                    .uploadBinary(fileName, bytes);

                                final imageUrl = Supabase
                                    .instance.client.storage
                                    .from('product_images')
                                    .getPublicUrl(fileName);

                                await Supabase.instance.client
                                    .from('advertisements')
                                    .update({'is_active': false}).eq(
                                        'is_active', true);

                                await Supabase.instance.client
                                    .from('advertisements')
                                    .insert({
                                  'title': titleController.text.trim(),
                                  'image_url': imageUrl,
                                  'is_active': true,
                                  'created_at':
                                      DateTime.now().toIso8601String(),
                                });

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  if (mounted) _fetchActiveAdvertisement();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(_isArabic
                                          ? 'تم نشر الإعلان بنجاح'
                                          : 'Ad published successfully'),
                                      backgroundColor: AppTheme.success,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('خطأ: $e'),
                                        backgroundColor: AppTheme.error),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setModalState(() => isUploading = false);
                                }
                              }
                            },
                      child: isUploading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _isArabic
                                  ? 'نشر وتفعيل الإعلان'
                                  : 'Publish & Activate Ad',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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

      try {
        await Supabase.instance.client
            .rpc('increment_product_views', params: {'product_id': productId});
      } catch (_) {}

      if (mounted) {
        setState(() {
          _sellerPhones[productId] = phone.isNotEmpty
              ? phone
              : (_isArabic ? 'غير متوفر' : 'Not available');
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

  void _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.primary),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.support_agent_rounded,
                        color: AppTheme.warning, size: 32),
                    const SizedBox(width: 12),
                    Text(
                      _isArabic ? 'الدعم الفني' : 'Technical Support',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    children: [
                      ListTile(
                        leading:
                            Icon(Icons.email, color: AppTheme.primaryLight),
                        title: Text('sales@ghayarakjo.com',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                      Divider(color: Colors.white12, height: 1),
                      ListTile(
                        leading: Icon(Icons.phone, color: AppTheme.success),
                        title: Text('+962 7 9000 0000',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      _isArabic ? 'إغلاق' : 'Close',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openPersonalInfo() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PersonalInfoScreen(isArabic: _isArabic),
      ),
    ).then((_) => _fetchUserDataFromSupabase());
  }

  void _openSecurityScreen() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SecuritySettingsScreen(isArabic: _isArabic),
      ),
    );
  }

  Future<void> _openDashboard() async {
    Navigator.pop(context);

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      Navigator.pushNamed(context, '/login');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SellerDashboardScreen(),
      ),
    ).then((_) => _fetchAllProducts());
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        drawer: _buildCyberpunkDrawer(),
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          elevation: 0,
          leading: Builder(
            builder: (ctx) => Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: IconButton(
                icon: const Icon(Icons.menu_rounded,
                    color: AppTheme.primary, size: 22),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
          ),
          title: Align(
            alignment: _isArabic ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
              ),
              child: SvgPicture.asset(
                'assets/g-logo-v6-machined.svg',
                width: 32,
                height: 32,
                fit: BoxFit.contain,
                placeholderBuilder: (context) => const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.primary),
                ),
              ),
            ),
          ),
          actions: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_active_rounded,
                      color: AppTheme.warning, size: 22),
                  tooltip: _isArabic ? 'الإشعارات والعروض' : 'Notifications',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const NotificationsScreen()),
                    );
                  },
                ),
                if (_userRole == 'admin')
                  IconButton(
                    icon: const Icon(Icons.campaign,
                        color: AppTheme.success, size: 24),
                    tooltip: _isArabic ? 'إدارة الإعلانات' : 'Manage Ads',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const AdminDashboardScreen()),
                      ).then((_) => _fetchActiveAdvertisement());
                    },
                  ),
                InkWell(
                  onTap: () => setState(() => _isArabic = !_isArabic),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      _isArabic ? 'ENG' : 'عربي',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ActiveRequestProgressWidget(),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.surface, AppTheme.background],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.4),
                      width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      blurRadius: 20,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.primary, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: AppTheme.background,
                        child: Text(
                          _dbUsername.isNotEmpty
                              ? _dbUsername[0].toUpperCase()
                              : 'G',
                          style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isArabic
                                ? 'أهلاً بك، $_dbUsername'
                                : 'Welcome, $_dbUsername',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.bolt,
                                  color: AppTheme.warning, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                _isArabic
                                    ? 'منصة قطع الغيار الأولى في الأردن'
                                    : 'Jordan #1 Auto Parts',
                                style: TextStyle(
                                    color: Colors.grey.shade400, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (!_isLoadingAd) ...[
                if (_activeAd != null)
                  Container(
                    width: double.infinity,
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      image: _activeAd!['image_url'] != null
                          ? DecorationImage(
                              image: NetworkImage(_activeAd!['image_url']),
                              fit: BoxFit.cover,
                            )
                          : null,
                      color: AppTheme.surface,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.85)
                          ],
                        ),
                      ),
                      alignment: Alignment.bottomRight,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _activeAd!['title'] ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_userRole == 'admin')
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.black54,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: _showAddAdBottomSheet,
                              icon: const Icon(Icons.edit, size: 14),
                              label: Text(_isArabic ? 'تغيير' : 'Change',
                                  style: const TextStyle(fontSize: 11)),
                            ),
                        ],
                      ),
                    ),
                  )
                else if (_userRole == 'admin')
                  GestureDetector(
                    onTap: _showAddAdBottomSheet,
                    child: Container(
                      width: double.infinity,
                      height: 110,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.surface, AppTheme.background],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.primary, width: 1.5),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_photo_alternate_rounded,
                              color: AppTheme.primary, size: 34),
                          const SizedBox(height: 6),
                          Text(
                            _isArabic
                                ? '+ اضافة اعلان مميز'
                                : '+ Add Featured Ad',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
              ],
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SearchResultsScreen(
                            searchQuery: val.trim(),
                            isArabic: _isArabic,
                          ),
                        ),
                      );
                    }
                  },
                  decoration: InputDecoration(
                    hintText: _isArabic
                        ? 'ابحث برقم القطعة، الموديل، أو الاسم...'
                        : 'Search by part number, model, or name...',
                    hintStyle:
                        TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppTheme.primary),
                    suffixIcon: Container(
                      margin: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_forward_ios,
                            color: Colors.white, size: 14),
                        onPressed: () {
                          final val = _searchController.text.trim();
                          if (val.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SearchResultsScreen(
                                  searchQuery: val,
                                  isArabic: _isArabic,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isArabic ? 'الأقسام الرئيسية' : 'Main Categories',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (_selectedCategoryFilter != null)
                    TextButton(
                      onPressed: () {
                        setState(() => _selectedCategoryFilter = null);
                        _fetchAllProducts();
                      },
                      child: Text(
                        _isArabic ? 'إلغاء الفلترة' : 'Clear Filter',
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    )
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 115,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _allCategories.length,
                  itemBuilder: (context, index) {
                    final cat = _allCategories[index];
                    final isAll = cat['name'] == 'ALL';
                    final isSelected = isAll
                        ? _selectedCategoryFilter == null
                        : _selectedCategoryFilter == cat['name'];

                    final List<Color> gradientColors =
                        cat['gradient'] ?? [AppTheme.primary, Colors.orange];

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isAll) {
                            _selectedCategoryFilter = null;
                          } else {
                            _selectedCategoryFilter =
                                isSelected ? null : cat['name'] as String;
                          }
                        });
                        _fetchAllProducts();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 100,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isSelected
                                ? gradientColors
                                : [
                                    AppTheme.surface,
                                    AppTheme.surface.withValues(alpha: 0.8)
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.4)
                                : AppTheme.border.withValues(alpha: 0.6),
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected
                                  ? gradientColors.first.withValues(alpha: 0.45)
                                  : Colors.black.withValues(alpha: 0.15),
                              blurRadius: isSelected ? 12 : 6,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.2)
                                      : gradientColors.first
                                          .withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  cat['icon'] as IconData,
                                  color: isSelected
                                      ? Colors.white
                                      : gradientColors.first,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                (_isArabic ? cat['arName'] : cat['enName'])
                                    .toString(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.shade300,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 26),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isArabic ? 'ما الجديد' : 'New Arrivals',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.autorenew,
                            color: AppTheme.success, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          _isArabic ? 'مُحدث تلقائياً' : 'Auto-updated',
                          style: const TextStyle(
                              color: AppTheme.success,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildProductSection(products: _newArrivalsProducts),
              const SizedBox(height: 26),
              Text(
                _isArabic ? 'الأكثر مبيعاً وطلباً' : 'Best Sellers',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              _buildProductSection(products: _popularProducts),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) async {
              if (index == 1) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AddProductScreen()),
                );
                _fetchAllProducts();
              } else if (index == 2) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ConversationsScreen(),
                  ),
                );
              } else {
                setState(() => _currentIndex = 0);
              }
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: AppTheme.primary,
            unselectedItemColor: Colors.grey.shade400,
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_filled),
                label: _isArabic ? 'الرئيسية' : 'Home',
              ),
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.camera_alt,
                      color: Colors.white, size: 22),
                ),
                label: _isArabic ? 'اعرض منتجك' : 'Post Part',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: _isArabic ? 'الدردشة' : 'Chat',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCyberpunkDrawer() {
    return Drawer(
      backgroundColor: AppTheme.surface,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              color: AppTheme.background,
            ),
            currentAccountPicture: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primary, width: 2),
              ),
              child: CircleAvatar(
                backgroundColor: AppTheme.surface,
                child: Text(
                  _dbUsername.isNotEmpty ? _dbUsername[0].toUpperCase() : 'M',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            accountName: Text(
              _dbUsername,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
            accountEmail: Text(
              _dbEmail,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
          ),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildDrawerItem(
                  icon: Icons.person_outline_rounded,
                  title: _isArabic ? 'المعلومات الشخصية' : 'Personal Info',
                  onTap: _openPersonalInfo,
                ),
                _buildDrawerItem(
                  icon: Icons.lock_outline_rounded,
                  title: _isArabic
                      ? 'الحماية وباسورد الحساب'
                      : 'Security & Password',
                  onTap: _openSecurityScreen,
                ),
                if (_userRole == 'admin' || _enforcePostingLimits)
                  _buildDrawerItem(
                    icon: Icons.card_membership_rounded,
                    title: _isArabic ? 'العضوية والاشتراكات' : 'Membership',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              MembershipScreen(isArabic: _isArabic),
                        ),
                      );
                    },
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: Colors.white12),
                ),
                if (_userRole == 'mechanic' ||
                    _userRole == 'towing' ||
                    _userRole == 'admin')
                  _buildDrawerItem(
                    icon: Icons.account_balance_wallet_rounded,
                    title: _isArabic
                        ? 'المحفظة والأرباح (Wallet)'
                        : 'Wallet & Earnings',
                    color: AppTheme.success,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WalletScreen(),
                        ),
                      );
                    },
                  ),
                _buildDrawerItem(
                  icon: Icons.calendar_month_rounded,
                  title: _isArabic
                      ? 'حجز موعد في ورشة معتمدة'
                      : 'Book Workshop Appointment',
                  color: AppTheme.success,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const BookWorkshopScreen()),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.event_available_rounded,
                  title:
                      _isArabic ? 'مواعيدي وحجوزات الصيانة' : 'My Appointments',
                  color: AppTheme.primaryLight,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const MyAppointmentsScreen()),
                    );
                  },
                ),
                if (_userRole == 'user' ||
                    _userRole == 'mechanic' ||
                    _userRole == 'moderator' ||
                    _userRole == 'towing' ||
                    _userRole == 'admin')
                  _buildDrawerItem(
                    icon: Icons.car_repair_rounded,
                    title: _isArabic
                        ? 'طلب ميكانيكي أو ونش طوارئ'
                        : 'Request Mechanic / Tow',
                    color: AppTheme.warning,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const RequestMechanicScreen()),
                      );
                    },
                  ),
                if (_userRole == 'mechanic' ||
                    _userRole == 'towing' ||
                    _userRole == 'admin') ...[
                  _buildDrawerItem(
                    icon: Icons.notifications_active_rounded,
                    title: _isArabic
                        ? 'طلبات العملاء الواردة'
                        : 'Incoming Requests',
                    color: AppTheme.warning,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const MechanicRequestScreen()),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.build_circle_rounded,
                    title: _isArabic
                        ? 'لوحة تحكم الصيانة والأرباح'
                        : 'Mechanic / Towing Dashboard',
                    color: AppTheme.primary,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const MechanicDashboardScreen()),
                      );
                    },
                  ),
                ],
                if (_userRole == 'mechanic' || _userRole == 'admin')
                  _buildDrawerItem(
                    icon: Icons.store_rounded,
                    title: _isArabic
                        ? 'لوحة تحكم الورشة والمواعيد'
                        : 'Workshop Dashboard',
                    color: AppTheme.success,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const WorkshopDashboardScreen()),
                      );
                    },
                  ),
                if (_userRole == 'mechanic' ||
                    _userRole == 'towing' ||
                    _userRole == 'admin')
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(color: Colors.white12),
                  ),
                if (_userRole == 'user' ||
                    _userRole == 'mechanic' ||
                    _userRole == 'moderator' ||
                    _userRole == 'towing' ||
                    _userRole == 'admin')
                  _buildDrawerItem(
                    icon: Icons.dashboard_rounded,
                    title: _isArabic
                        ? 'لوحة تحكم البضاعة (Dashboard)'
                        : 'Sold Goods Dashboard',
                    color: AppTheme.success,
                    onTap: _openDashboard,
                  ),
                if (_userRole == 'moderator' || _userRole == 'admin') ...[
                  _buildDrawerItem(
                    icon: Icons.flash_on_rounded,
                    title: _isArabic
                        ? 'إدارة ومراجعة طلبات الكليك'
                        : 'Cliq Requests & History',
                    color: AppTheme.warning,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const CliqRequestsScreen()),
                      );
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(color: Colors.white12),
                  ),
                ],
                if (_userRole == 'admin') ...[
                  _buildDrawerItem(
                    icon: Icons.campaign_rounded,
                    title: _isArabic ? 'إدارة الإعلانات (Admin)' : 'Manage Ads',
                    color: AppTheme.success,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const AdminDashboardScreen()),
                      ).then((_) => _fetchActiveAdvertisement());
                    },
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.background,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Column(
              children: [
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: const Icon(Icons.support_agent_rounded,
                        color: AppTheme.warning),
                    title: Text(
                      _isArabic ? 'الدعم الفني' : 'Support',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onTap: () {
                      Navigator.pop(context);
                      _showSupportDialog();
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: Text(
                      _isArabic ? 'تسجيل الخروج' : 'Logout',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _logout,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = AppTheme.primaryLight,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13),
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _buildProductSection({required List<dynamic> products}) {
    if (_isLoadingProducts) {
      return const SizedBox(
        height: 295,
        child:
            Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    if (products.isEmpty) {
      return SizedBox(
        height: 100,
        child: Center(
          child: Text(
            _isArabic ? 'لا توجد قطع معروضة مطابقة' : 'No matching parts found',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      );
    }

    return SizedBox(
      height: 345,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          final List<dynamic> images = product['images'] ?? [];
          final imgUrl = images.isNotEmpty ? images[0] : '';
          final productId = product['id'].toString();
          final userId = product['user_id']?.toString().trim() ?? '';

          final customerData = product['customers'];
          bool isTrustedSeller = false;
          if (customerData != null) {
            final subStatus = customerData['subscription_status']
                    ?.toString()
                    .toLowerCase()
                    .trim() ??
                '';
            if (subStatus == 'approved' ||
                subStatus == 'active' ||
                subStatus.contains('approv')) {
              isTrustedSeller = true;
            }
          }

          if (!isTrustedSeller) {
            isTrustedSeller = _trustedSellers.contains(userId);
          }

          final isRevealed = _revealedPhones[productId] ?? false;
          final realPhone = _sellerPhones[productId] ??
              (_isArabic ? 'جاري جلب الرقم...' : 'Fetching phone...');

          return Container(
            width: 215,
            margin: const EdgeInsets.symmetric(horizontal: 7),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Material(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ProductDetailScreen(product: product),
                      ),
                    ).then((_) => _fetchAllProducts());
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.border, width: 1.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            imgUrl.isNotEmpty
                                ? Image.network(imgUrl,
                                    height: 125,
                                    width: double.infinity,
                                    fit: BoxFit.cover)
                                : Container(
                                    height: 125,
                                    color: AppTheme.background,
                                    child: const Icon(Icons.image,
                                        color: Colors.grey, size: 40)),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppTheme.border)),
                                child: Text(
                                  product['car_model'] ?? '',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            )
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product['title'] ?? '',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${product['car_name'] ?? ''}',
                                      style: const TextStyle(
                                          color: AppTheme.primaryLight,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isTrustedSeller)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.success,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.verified,
                                              color: Colors.white, size: 10),
                                          const SizedBox(width: 2),
                                          Text(
                                            _isArabic ? 'موثوق' : 'Trusted',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 34,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isRevealed
                                              ? AppTheme.success
                                              : AppTheme.background,
                                          padding: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                          side: BorderSide(
                                            color: isRevealed
                                                ? Colors.transparent
                                                : AppTheme.border,
                                          ),
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
                                              : (_isArabic
                                                  ? 'الهاتف'
                                                  : 'Phone'),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold),
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
                                  const SizedBox(width: 6),
                                  SizedBox(
                                    height: 34,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primary,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ChatScreen(
                                              receiverId: userId,
                                              receiverName: product['title'] ??
                                                  (_isArabic
                                                      ? 'البائع'
                                                      : 'Seller'),
                                              productId:
                                                  product['id'].toString(),
                                            ),
                                          ),
                                        );
                                      },
                                      child: const Icon(Icons.chat,
                                          size: 16, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // 🌟 زر الشراء الخارجي مطابق للزر الداخلي تماماً (لون أخضر + أيقونة عربة تسوق مع سهم + نص اشتري الآن)
                              SizedBox(
                                width: double.infinity,
                                height: 34,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.success,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                  icon: const Icon(Icons.add_shopping_cart,
                                      size: 16, color: Colors.white),
                                  label: const Text(
                                    'اشتري الآن (Buy Now)',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ProductDetailScreen(
                                                product: product),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ActiveRequestProgressWidget extends StatefulWidget {
  const ActiveRequestProgressWidget({super.key});

  @override
  State<ActiveRequestProgressWidget> createState() =>
      _ActiveRequestProgressWidgetState();
}

class _ActiveRequestProgressWidgetState
    extends State<ActiveRequestProgressWidget> {
  Map<String, dynamic>? _activeRequest;
  Map<String, dynamic>? _activeWorkshopAppt;
  bool _isLoading = true;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchActiveData();
    _pollingTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _fetchActiveData());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchActiveData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final mechanicRes = await Supabase.instance.client
          .from('mechanic_requests')
          .select()
          .eq('user_id', user.id)
          .neq('status', 'completed')
          .neq('status', 'cancelled')
          .order('created_at', ascending: false)
          .maybeSingle();

      final workshopRes = await Supabase.instance.client
          .from('workshop_appointments')
          .select('*, customers:workshop_id(username, phone)')
          .eq('user_id', user.id)
          .neq('status', 'completed')
          .neq('status', 'cancelled')
          .order('created_at', ascending: false)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _activeRequest = mechanicRes;
          _activeWorkshopAppt = workshopRes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox.shrink();

    if (_activeWorkshopAppt != null) {
      final appt = _activeWorkshopAppt!;
      final status = appt['status'] ?? 'pending';
      final workshopInfo = appt['customers'] ?? {};
      final workshopName = workshopInfo['username'] ?? 'الورشة المعتمدة';
      final apptDate = appt['appointment_date'] ?? '';
      final apptTime = appt['appointment_time'] ?? '';

      String statusText = 'قيد انتظار قبول الموعد من الورشة...';
      double progressVal = 0.25;
      Color cardColor = AppTheme.success;

      if (status == 'reschedule_suggested') {
        statusText =
            '⚠️ الورشة ممتلئة واقترحت عليك موعداً جديداً: $apptDate ($apptTime) - اضغط لمراجعة مواعيدي';
        progressVal = 0.4;
        cardColor = Colors.amber;
      } else if (status == 'accepted') {
        statusText =
            'تم قبول الموعد من $workshopName (موعدك: $apptDate - $apptTime)';
        progressVal = 0.5;
      } else if (status == 'repairing') {
        statusText = 'سيارتك الآن قيد الصيانة والتصليح داخل الورشة';
        progressVal = 0.8;
      } else if (status == 'completed') {
        statusText = 'تم الانتهاء من صيانة السيارة وجاهزة للاستلام!';
        progressVal = 1.0;
      }

      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const MyAppointmentsScreen()),
          );
        },
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: cardColor.withValues(alpha: 0.15),
                blurRadius: 12,
                spreadRadius: 2,
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                          status == 'reschedule_suggested'
                              ? Icons.notification_important
                              : Icons.calendar_month,
                          color: cardColor,
                          size: 20),
                      const SizedBox(width: 8),
                      Text(
                          status == 'reschedule_suggested'
                              ? 'تنبيه: اقتراح موعد جديد من $workshopName'
                              : 'متابعة حجز ورشة: $workshopName',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ],
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      color: Colors.grey, size: 14),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progressVal,
                backgroundColor: Colors.white12,
                color: cardColor,
                minHeight: 8,
              ),
              const SizedBox(height: 12),
              Text(statusText,
                  style: TextStyle(
                      color: status == 'reschedule_suggested'
                          ? Colors.amber
                          : AppTheme.warning,
                      fontWeight: FontWeight.w600,
                      fontSize: 12)),
            ],
          ),
        ),
      );
    }

    if (_activeRequest != null) {
      final req = _activeRequest!;
      final status = req['status'] ?? 'pending';
      final progressStep = req['progress_step'] ?? 'pending';
      final serviceType =
          req['service_type'] == 'towing' ? 'ونش سحب طوارئ' : 'ميكانيكي طوارئ';
      final estimatedTime = req['estimated_time'] ?? 'قيد التحديد';

      final String statusText;
      final double progressValue;

      if (status == 'accepted' || progressStep == 'accepted') {
        statusText = 'تم قبول الطلب، المزود في طريقه إليك أو تم تسليم السيارة';
        progressValue = 0.5;
      } else if (progressStep == 'in_progress') {
        statusText = 'السيارة قيد التصليح (الوقت المتوقع: $estimatedTime)';
        progressValue = 0.8;
      } else if (progressStep == 'completed') {
        statusText = 'تم الانتهاء من التصليح وجاهزة للاستلام';
        progressValue = 1.0;
      } else {
        statusText = 'قيد انتظار قبول الطلب من الميكانيكي أو الونش...';
        progressValue = 0.25;
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.15),
              blurRadius: 12,
              spreadRadius: 2,
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.car_repair,
                        color: AppTheme.warning, size: 20),
                    const SizedBox(width: 8),
                    Text('متابعة طلب: $serviceType',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progressValue,
              backgroundColor: Colors.white12,
              color: AppTheme.warning,
              minHeight: 8,
            ),
            const SizedBox(height: 12),
            Text(statusText,
                style: const TextStyle(
                    color: AppTheme.warning,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
