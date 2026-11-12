import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../app_theme.dart';

class SecuritySettingsScreen extends StatefulWidget {
  final bool isArabic;
  const SecuritySettingsScreen({super.key, this.isArabic = true});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  bool _showPasswordBox = false;
  bool _showEmailBox = false;
  bool _twoFactorEnabled = false;
  bool _isLoading2FA = false;

  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkMfaStatus();
  }

  Future<void> _checkMfaStatus() async {
    try {
      final factors = await Supabase.instance.client.auth.mfa.listFactors();
      final totpFactors = factors.totp;
      if (totpFactors.isNotEmpty && mounted) {
        setState(() {
          _twoFactorEnabled = true;
        });
      }
    } catch (e) {
      debugPrint('Error checking MFA: $e');
    }
  }

  Future<void> _toggle2FA(bool value) async {
    setState(() => _isLoading2FA = true);
    try {
      if (value) {
        try {
          final existingFactors =
              await Supabase.instance.client.auth.mfa.listFactors();
          for (final factor in existingFactors.totp) {
            if (factor.friendlyName?.startsWith('Ghayarak_2FA_') ?? false) {
              await Supabase.instance.client.auth.mfa.unenroll(factor.id);
            }
          }
        } catch (_) {}

        final uniqueName =
            'Ghayarak_2FA_${DateTime.now().millisecondsSinceEpoch}';
        final res = await Supabase.instance.client.auth.mfa.enroll(
          factorType: FactorType.totp,
          friendlyName: uniqueName,
        );

        final factorId = res.id;
        final totp = res.totp;
        if (totp == null) {
          throw Exception(widget.isArabic
              ? 'تعذر إنشاء رمز المصادقة'
              : 'Could not create authenticator code');
        }

        final secret = totp.secret;
        final qrCodeUri = totp.uri;

        if (mounted) {
          _showTotpDialog(factorId, secret, qrCodeUri);
        }
      } else {
        final factors = await Supabase.instance.client.auth.mfa.listFactors();
        for (final factor in factors.totp) {
          if (factor.friendlyName?.startsWith('Ghayarak_2FA_') ?? false) {
            await Supabase.instance.client.auth.mfa.unenroll(factor.id);
          }
        }
        if (mounted) {
          setState(() => _twoFactorEnabled = false);
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
                content: Text(widget.isArabic
                    ? 'تم إيقاف التحقق الثنائي'
                    : '2FA disabled')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.error),
        );
        setState(() => _twoFactorEnabled = false);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading2FA = false);
      }
    }
  }

  void _showTotpDialog(String factorId, String secret, String qrCodeUri) {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          widget.isArabic
              ? 'ربط تطبيق المصادقة (2FA)'
              : 'Link Authenticator App',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.isArabic
                      ? 'امسح رمز الاستجابة السريعة (QR Code) باستخدام تطبيق المصادقة:'
                      : 'Scan the QR code using your authenticator app:',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: QrImageView(
                    data: qrCodeUri,
                    version: QrVersions.auto,
                    size: 150.0,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.isArabic
                      ? 'أو أدخل المفتاح السري يدويًا:'
                      : 'Or enter secret manually:',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    secret,
                    style: const TextStyle(
                      color: AppTheme.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: widget.isArabic
                        ? 'رمز التحقق (6 أرقام)'
                        : '6-digit Code',
                    labelStyle: const TextStyle(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.background,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (Navigator.of(dialogContext, rootNavigator: true).canPop()) {
                Navigator.of(dialogContext, rootNavigator: true).pop();
              }
              if (mounted) {
                setState(() => _twoFactorEnabled = false);
              }
            },
            child: Text(widget.isArabic ? 'إلغاء' : 'Cancel',
                style: const TextStyle(color: AppTheme.error)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () async {
              try {
                final challenge = await Supabase.instance.client.auth.mfa
                    .challenge(factorId: factorId);
                await Supabase.instance.client.auth.mfa.verify(
                  factorId: factorId,
                  challengeId: challenge.id,
                  code: codeController.text.trim(),
                );

                if (!mounted) return;
                setState(() => _twoFactorEnabled = true);
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                if (!mounted) return;
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  SnackBar(
                      content: Text(widget.isArabic
                          ? 'تم تفعيل التحقق الثنائي بنجاح'
                          : '2FA Enabled Successfully')),
                );
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.maybeOf(dialogContext)?.showSnackBar(
                    SnackBar(
                        content: Text('الرمز غير صحيح: $e'),
                        backgroundColor: AppTheme.error),
                  );
                }
              }
            },
            child: Text(widget.isArabic ? 'تأكيد' : 'Verify',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          title: Text(
            widget.isArabic ? 'الحماية والباسورد' : 'Security & Password',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Material(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () =>
                    setState(() => _showPasswordBox = !_showPasswordBox),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_reset,
                          color: AppTheme.success, size: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                widget.isArabic
                                    ? 'تغيير كلمة المرور'
                                    : 'Change Password',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(
                                widget.isArabic
                                    ? 'تحديث كلمة المرور الخاصة بحسابك'
                                    : 'Update your account password',
                                style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                      Icon(
                          _showPasswordBox
                              ? Icons.keyboard_arrow_up
                              : Icons.arrow_forward_ios,
                          color: AppTheme.textSecondary,
                          size: 16),
                    ],
                  ),
                ),
              ),
            ),
            if (_showPasswordBox) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: widget.isArabic
                            ? 'كلمة المرور الجديدة'
                            : 'New Password',
                        labelStyle:
                            const TextStyle(color: AppTheme.textSecondary),
                        filled: true,
                        fillColor: AppTheme.background,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            padding: const EdgeInsets.symmetric(vertical: 12)),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.maybeOf(context);
                          try {
                            await Supabase.instance.client.auth.updateUser(
                                UserAttributes(
                                    password: _passwordController.text.trim()));
                            if (!mounted) return;
                            messenger?.showSnackBar(const SnackBar(
                                content: Text('تم تحديث كلمة المرور بنجاح')));
                            setState(() => _showPasswordBox = false);
                          } catch (e) {
                            if (mounted) {
                              messenger?.showSnackBar(
                                  SnackBar(content: Text('خطأ: $e')));
                            }
                          }
                        },
                        child: Text(
                            widget.isArabic
                                ? 'حفظ كلمة المرور'
                                : 'Save Password',
                            style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Material(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _showEmailBox = !_showEmailBox),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.mark_email_unread_outlined,
                          color: AppTheme.primaryLight, size: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                widget.isArabic
                                    ? 'تغيير البريد الإلكتروني'
                                    : 'Change Email',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(
                                widget.isArabic
                                    ? 'إرسال رابط تأكيد للبريد الجديد'
                                    : 'Send verification link',
                                style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                      Icon(
                          _showEmailBox
                              ? Icons.keyboard_arrow_up
                              : Icons.arrow_forward_ios,
                          color: AppTheme.textSecondary,
                          size: 16),
                    ],
                  ),
                ),
              ),
            ),
            if (_showEmailBox) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    TextField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: widget.isArabic
                            ? 'البريد الإلكتروني الجديد'
                            : 'New Email',
                        labelStyle:
                            const TextStyle(color: AppTheme.textSecondary),
                        filled: true,
                        fillColor: AppTheme.background,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryLight,
                            padding: const EdgeInsets.symmetric(vertical: 12)),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.maybeOf(context);
                          try {
                            await Supabase.instance.client.auth.updateUser(
                                UserAttributes(
                                    email: _emailController.text.trim()));
                            if (!mounted) return;
                            messenger?.showSnackBar(const SnackBar(
                                content: Text(
                                    'تم إرسال رابط التأكيد للبريد الجديد')));
                            setState(() => _showEmailBox = false);
                          } catch (e) {
                            if (mounted) {
                              messenger?.showSnackBar(
                                  SnackBar(content: Text('خطأ: $e')));
                            }
                          }
                        },
                        child: Text(
                            widget.isArabic
                                ? 'حفظ البريد الجديد'
                                : 'Save New Email',
                            style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.security,
                          color: AppTheme.warning, size: 28),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              widget.isArabic
                                  ? 'التحقق الثنائي (2FA)'
                                  : 'Two-Factor Auth',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                              widget.isArabic
                                  ? 'حماية إضافية لحسابك'
                                  : 'Extra security via Supabase',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  _isLoading2FA
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Switch(
                          value: _twoFactorEnabled,
                          activeThumbColor: AppTheme.primary,
                          onChanged: _toggle2FA),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
