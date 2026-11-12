import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../app_theme.dart';

class AddProductScreen extends StatefulWidget {
  final Map<String, dynamic>? productToEdit;
  const AddProductScreen({super.key, this.productToEdit});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _carNameController = TextEditingController();
  final _carModelController = TextEditingController();
  final _chassisController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedMainCategory = 'المحرك وملحقاته (Engine)';
  String _selectedSubCategory = 'عام';
  bool _isLoading = false;
  List<String> _imageUrls = [];

  final Map<String, List<String>> _subCategoriesMap = {
    'المحرك وملحقاته (Engine)': [
      'عام',
      'بلوك المحرك (Engine Block)',
      'رأس المحرك (Cylinder Head)',
      'طرمبة الزيت والماء (Pumps)',
      'تيربو وشواحن هوائية (Turbocharger)',
      'سيور وبكرات (Belts & Pulleys)',
      'عمود الكرنك والشنابر (Crankshaft & Piston Rings)',
      'عمود الكامة - الكامشافت (Camshaft)',
      'صبابكات / بلوف (Valves)',
      'جوان رأس المحرك (Head Gasket)',
      'كارتير الزيت (Oil Pan)',
      'بواجي / شمعات الاحتراق (Spark Plugs)',
    ],
    'نظام التبريد (Cooling System)': [
      'عام',
      'راديتر الماء (Radiator)',
      'مروحة التبريد وحساساتها (Cooling Fan & Sensors)',
      'بلف الحرارة / ثرموستات (Thermostat)',
      'طرمبة الماء (Water Pump)',
      'خراطيم ومواسير التبريد (Coolant Hoses & Pipes)',
      'قربة الردياتير (Expansion Tank)',
      'ردياتير المكيف / الثلاجة (Condenser)',
    ],
    'نظام الوقود والعادم (Fuel & Exhaust)': [
      'عام',
      'بخاخات الوقود / إجكتورات (Fuel Injectors)',
      'طرمبة البنزين / الديزل (Fuel Pump)',
      'فلتر الهواء والبنزين (Air & Fuel Filters)',
      'دبات عادم / شكمان / دبة تروس (Exhaust & Muffler)',
      'حساس الأكسجين (O2 Sensor)',
      'منظم ضغط الوقود (Fuel Pressure Regulator)',
      'ثروتل / بوابة الهواء (Throttle Body)',
    ],
    'نظام التعليق والتوجيه (Suspension & Steering)': [
      'عام',
      'مساعدين / ممتص صدمات (Shock Absorbers)',
      'مقصات وبوشات (Control Arms & Bushings)',
      'علبة الديركسيون / الستيرينغ (Steering Rack)',
      'عمود التوازن وعصافير التوازن (Sway Bar & Links)',
      'رودات ومفاصل التوجيه (Tie Rod Ends)',
      'بربرين / رومان بلي العجل (Wheel Bearings)',
      'يايات / سبرنجات (Coil Springs)',
    ],
    'نظام الفرامل (Braking System)': [
      'عام',
      'ديسكات / هوبات الفرامل (Brake Rotors)',
      'فحمات / طراطيش الفرامل (Brake Pads)',
      'علبة الفرامل الرئيسية / الباكم (Master Cylinder & Booster)',
      'جهاز ABS ومضخه (ABS Module)',
      'كليبرات الفرامل (Brake Calipers)',
      'هاند برامل / فرامل اليد (Handbrake Cable)',
      'ليتات خراطيم الفرامل (Brake Hoses)',
    ],
    'الكهرباء والإلكترونيات (Electrical System)': [
      'عام',
      'دينامو الشحن (Alternator)',
      'سلف / مارش التشغيل (Starter Motor)',
      'حساسات المحرك المختلفة (Engine Sensors)',
      'كمبيوتر السيارة الأساسي (ECU / Computer)',
      'ضفيرة الأسلاك والفيوزات (Wiring Harness & Fuses)',
      'بطارية وكوابل التوصيل (Battery & Cables)',
      'موتورات المساحات (Wiper Motors)',
    ],
    'الإضاءة والرؤية (Lighting & Vision)': [
      'عام',
      'أضواء أمامية رئيسية (Headlights)',
      'أضواء خلفية (Taillights)',
      'كشافات ضباب (Fog Lights)',
      'مرايا جانبية (Side Mirrors)',
      'زجاج أمامي وخلفي (Windshield & Rear Glass)',
      'شفرات مساحات الزجاج (Wiper Blades)',
      'إضاءة صالون وتابلوه (Cabin & Dashboard Lights)',
    ],
    'نقل الحركة ونظام الدوران (Transmission & Drivetrain)': [
      'عام',
      'جير عادي أو أوتوماتيك كامل (Gearbox / Transmission)',
      'ديسك وبلاتين وفلنشة (Clutch Kit)',
      'عكس وكارونة وعمود كردان (Axles & Driveshaft)',
      'دفرنس / دفرنشل (Differential)',
      'قاعدة الجير والموتور (Engine & Gear Mounts)',
      'فلتر وزيت الجير (Transmission Filter & Fluid)',
    ],
    'جسم السيارة والديكور الخارجي (Body & Interior)': [
      'عام',
      'صدام أمامي وخلفي / اكصدام (Bumpers)',
      'أبواب وغطاء محرك وشنطة (Doors, Hood & Trunk)',
      'رفارف جانبية (Fenders)',
      'شبكة أمامية (Grille)',
      'طبلون وديكورات داخلية (Interior Trim & Dashboard)',
      'مقاعد السيارة (Seats)',
      'أحزمة الأمان (Seat Belts)',
    ],
    'التكييف والتدفئة (HVAC)': [
      'عام',
      'كمبريسور المكيف (AC Compressor)',
      'ثلاجة المكيف الداخلية (Evaporator)',
      'راديتر المكيف الخارجي (AC Condenser)',
      'مروحة المبرّد / البلاور (Blower Motor)',
      'صمام التمدد / إكسبانشن فالڤ (Expansion Valve)',
      'فلتر المكيف (Cabin Air Filter)',
    ],
    'الإطارات والجنوط (Tires & Wheels)': [
      'عام',
      'إطارات / تواير جديدة ومستعملة (Tires)',
      'جنوط رنجات ألومنيوم أو حديد (Rims / Wheels)',
      'غُطاء جنط / طاسة (Hubcaps)',
      'بوالين / حساسات ضغط الإطارات TPMS',
      'براغي ومقالي الجنط (Lug Nuts & Bolts)',
    ],
    'أخرى وعامة (General & Misc)': [
      'عام',
      'سوائل وزيوت المحرك والجير (Fluids & Oils)',
      'إكسسوارات عامة وتعديلات (General Accessories)',
      'قطع غيار عامة متنوعة (Miscellaneous Parts)',
    ],
  };

  @override
  void initState() {
    super.initState();
    if (widget.productToEdit != null) {
      final p = widget.productToEdit!;
      _titleController.text = p['title'] ?? '';
      _carNameController.text = p['car_name'] ?? '';
      _carModelController.text = p['car_model'] ?? '';
      _chassisController.text = p['chassis_number'] ?? '';
      _priceController.text = (p['price'] ?? '').toString();
      _descriptionController.text = p['description'] ?? '';
      _selectedMainCategory = p['main_category'] ?? 'المحرك وملحقاته (Engine)';
      _selectedSubCategory = p['sub_category'] ?? 'عام';
      if (p['images'] != null) {
        _imageUrls = List<String>.from(p['images']);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _carNameController.dispose();
    _carModelController.dispose();
    _chassisController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      try {
        final bytes = await image.readAsBytes();
        final fileName =
            'product_${DateTime.now().millisecondsSinceEpoch}_${image.name}';
        await Supabase.instance.client.storage
            .from('product_images')
            .uploadBinary(fileName, bytes);

        final imageUrl = Supabase.instance.client.storage
            .from('product_images')
            .getPublicUrl(fileName);

        setState(() {
          _imageUrls = [imageUrl, ..._imageUrls];
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('فشل رفع الصورة: $e'),
                backgroundColor: AppTheme.error),
          );
        }
      }
    }
  }

  Future<void> _submitProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('يرجى تسجيل الدخول أولاً');
      }

      // تحويل السعر بشكل آمن (اختياري)
      double? parsedPrice;
      if (_priceController.text.trim().isNotEmpty) {
        parsedPrice = double.tryParse(_priceController.text.trim());
      }

      final productData = {
        'user_id': user.id,
        'title': _titleController.text.trim(),
        'car_name': _carNameController.text.trim(),
        'car_model': _carModelController.text.trim(),
        'chassis_number': _chassisController.text.trim().isNotEmpty
            ? _chassisController.text.trim().toUpperCase()
            : null,
        'price': parsedPrice,
        'description': _descriptionController.text.trim(),
        'main_category': _selectedMainCategory,
        'sub_category': _selectedSubCategory,
        'images': _imageUrls,
        'is_hidden': false,
      };

      if (widget.productToEdit == null) {
        await Supabase.instance.client.from('products').insert(productData);
      } else {
        await Supabase.instance.client
            .from('products')
            .update(productData)
            .eq('id', widget.productToEdit!['id']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.productToEdit == null
                ? 'تمت إضافة القطعة بنجاح'
                : 'تم تحديث القطعة بنجاح'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.productToEdit != null;
    final currentSubCategories =
        _subCategoriesMap[_selectedMainCategory] ?? ['عام'];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          title: Text(
            isEditing ? 'تعديل القطعة' : 'إضافة قطعة جديدة',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // اختيار صورة القطعة في الأعلى
                  Center(
                    child: GestureDetector(
                      onTap: _pickAndUploadImage,
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primary),
                        ),
                        child: _imageUrls.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(_imageUrls.first,
                                    fit: BoxFit.cover),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.add_a_photo,
                                      color: AppTheme.primary, size: 32),
                                  SizedBox(height: 6),
                                  Text(
                                    'اضغط لإضافة صورة القطعة',
                                    style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'عنوان القطعة (مثال: دينامو أصلي)',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.background,
                    ),
                    validator: (val) =>
                        val!.isEmpty ? 'يرجى إدخال عنوان القطعة' : null,
                  ),
                  const SizedBox(height: 16),
                  // القسم الرئيسي
                  DropdownButtonFormField<String>(
                    initialValue: _selectedMainCategory,
                    dropdownColor: AppTheme.surface,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'القسم الرئيسي',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.background,
                    ),
                    items: _subCategoriesMap.keys.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(cat,
                            style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedMainCategory = val!;
                        final subs =
                            _subCategoriesMap[_selectedMainCategory] ?? ['عام'];
                        _selectedSubCategory = subs.first;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // القسم الفرعي / الملّحقات المتكاملة
                  DropdownButtonFormField<String>(
                    initialValue:
                        currentSubCategories.contains(_selectedSubCategory)
                            ? _selectedSubCategory
                            : currentSubCategories.first,
                    dropdownColor: AppTheme.surface,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'القسم الفرعي / الملحقات',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.background,
                    ),
                    items: currentSubCategories.map((subCat) {
                      return DropdownMenuItem(
                        value: subCat,
                        child: Text(subCat,
                            style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setState(() => _selectedSubCategory = val!),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _carNameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'نوع السيارة (مثال: مرسيدس)',
                            labelStyle:
                                TextStyle(color: AppTheme.textSecondary),
                            filled: true,
                            fillColor: AppTheme.background,
                          ),
                          validator: (val) => val!.isEmpty ? 'حقل مطلوب' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _carModelController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'الموديل/السنة (مثال: 2022)',
                            labelStyle:
                                TextStyle(color: AppTheme.textSecondary),
                            filled: true,
                            fillColor: AppTheme.background,
                          ),
                          validator: (val) => val!.isEmpty ? 'حقل مطلوب' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // رقم الشاصي (اختياري مع التوضيح المطلوب)
                  TextFormField(
                    controller: _chassisController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText:
                          'رقم الشصي (إذا كانت القطعة تملك رقم شصي الرجاء وضعه هنا)',
                      labelStyle: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12),
                      filled: true,
                      fillColor: AppTheme.background,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // السعر (اختياري)
                  TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'السعر (دينار) - اختياري',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.background,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'وصف القطعة وملاحظات الحالة',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.background,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isLoading ? null : _submitProduct,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              isEditing ? 'حفظ التعديلات' : 'نشر القطعة الآن',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
