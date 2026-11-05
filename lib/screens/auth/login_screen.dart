import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../repositories/user_repository.dart';
import '../products/app_styles.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final UserRepository _userRepository = UserRepository();
  bool _isLoading = false;
  bool _isCheckingUsers = true;
  bool _needsInitialSetup = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _initializationError;

  @override
  void initState() {
    super.initState();
    _checkInitialSetup();
  }

  Future<void> _checkInitialSetup() async {
    try {
      final users = await _userRepository.getAllUsers();
      if (!mounted) return;
      setState(() {
        _needsInitialSetup = users.isEmpty;
        _isCheckingUsers = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _initializationError = 'تعذر التحقق من إعداد الحسابات: $error';
        _isCheckingUsers = false;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final user = await _userRepository.authenticate(
          _usernameController.text.trim(),
          _passwordController.text,
        );

        if (user != null) {
          await _openHome(user);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('اسم المستخدم أو كلمة السر غير صحيحة'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في تسجيل الدخول: $e'),
              backgroundColor: AppStyles.errorColor,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _createInitialAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = await _userRepository.createInitialAdmin(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
      );
      await _openHome(user);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر إعداد حساب المدير: $error'),
            backgroundColor: AppStyles.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openHome(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', user.id!);
    await prefs.setString('user_role', user.role.name);
    await prefs.setString('user_fullName', user.fullName);
    await prefs.setString('user_username', user.username);

    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppStyles.backgroundColor,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(32),
                child: _isCheckingUsers
                    ? const Center(child: CircularProgressIndicator())
                    : _initializationError != null
                    ? Text(
                        _initializationError!,
                        style: const TextStyle(color: Colors.red),
                      )
                    : Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.store,
                              size: 80,
                              color: AppStyles.primaryColor,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'سهل كاش',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppStyles.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'نظام إدارة النقاط البيع',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 32),
                            if (_needsInitialSetup) ...[
                              const Text(
                                'الإعداد الأولي: أنشئ حساب المدير بكلمة مرور قوية.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                key: const ValueKey('first-run-full-name'),
                                controller: _fullNameController,
                                decoration: const InputDecoration(
                                  labelText: 'الاسم الكامل',
                                  prefixIcon: Icon(Icons.badge),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'يرجى إدخال الاسم الكامل'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                            ],
                            TextFormField(
                              key: ValueKey(
                                _needsInitialSetup
                                    ? 'first-run-username'
                                    : 'login-username',
                              ),
                              controller: _usernameController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'اسم المستخدم',
                                prefixIcon: Icon(Icons.person),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'يرجى إدخال اسم المستخدم';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              key: ValueKey(
                                _needsInitialSetup
                                    ? 'first-run-password'
                                    : 'login-password',
                              ),
                              controller: _passwordController,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                if (!_isLoading) _login();
                              },
                              decoration: InputDecoration(
                                labelText: 'كلمة السر',
                                prefixIcon: const Icon(Icons.lock),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                border: const OutlineInputBorder(),
                              ),
                              obscureText: _obscurePassword,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'يرجى إدخال كلمة السر';
                                }
                                if (_needsInitialSetup && value.length < 12) {
                                  return 'كلمة السر يجب ألا تقل عن 12 حرفًا';
                                }
                                return null;
                              },
                            ),
                            if (_needsInitialSetup) ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                key: const ValueKey(
                                  'first-run-confirm-password',
                                ),
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                decoration: InputDecoration(
                                  labelText: 'تأكيد كلمة السر',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureConfirmPassword =
                                          !_obscureConfirmPassword,
                                    ),
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                                validator: (value) =>
                                    value != _passwordController.text
                                    ? 'كلمتا السر غير متطابقتين'
                                    : null,
                              ),
                            ],
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading
                                    ? null
                                    : _needsInitialSetup
                                    ? _createInitialAdmin
                                    : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppStyles.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : Text(
                                        _needsInitialSetup
                                            ? 'إنشاء حساب المدير والدخول'
                                            : 'تسجيل الدخول',
                                        style: TextStyle(
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
        ),
      ),
    );
  }
}
