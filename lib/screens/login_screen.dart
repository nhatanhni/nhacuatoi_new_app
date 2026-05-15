import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iot_app/bloc/auth/auth_bloc.dart';
import 'package:iot_app/bloc/auth/auth_event.dart';
import 'package:iot_app/bloc/auth/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();

  bool _isButtonTapped = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricStatus();
  }

  Future<void> _checkBiometricStatus() async {
    final repo = context.read<AuthBloc>().biometricRepository;
    final available = await repo.isBiometricAvailable();
    final enabled = await repo.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _isBiometricAvailable = available;
        _isBiometricEnabled = enabled;
      });
    }
  }

  String? _validateUsername(String? value) {
    final username = value?.trim() ?? '';

    if (username.isEmpty) {
      return 'Vui lòng nhập tên đăng nhập';
    }
    if (username.length < 3 || username.length > 50) {
      return 'Tên đăng nhập phải từ 3 đến 50 ký tự';
    }
    if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(username)) {
      return 'Tên đăng nhập chỉ gồm chữ, số, dấu chấm, gạch dưới hoặc gạch ngang';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'Vui lòng nhập mật khẩu';
    }
    if (password.length < 6 || password.length > 64) {
      return 'Mật khẩu phải từ 6 đến 64 ký tự';
    }

    return null;
  }

  void _login() {
    if (_isButtonTapped) {
      return;
    }

    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng kiểm tra lại thông tin đăng nhập')),
      );
      return;
    }

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    context.read<AuthBloc>().add(
      AuthLoginRequested(username: username, password: password),
    );
  }

  void _loginWithBiometric() {
    context.read<AuthBloc>().add(AuthBiometricLoginRequested());
  }

  void _showForgotPassword() {
    Navigator.of(context).pushNamed('/forgot-password');
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _showAlertDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        );
      },
    );
  }

  void _showEnableBiometricDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.fingerprint, color: Color(0xFF3459AE), size: 28),
              SizedBox(width: 8),
              Text('Đăng nhập vân tay'),
            ],
          ),
          content: const Text(
            'Bạn có muốn bật đăng nhập bằng vân tay cho những lần sau không?',
          ),
          actions: [
            TextButton(
              child: const Text('Không', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3459AE),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Bật vân tay',
                  style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(ctx).pop();
                context.read<AuthBloc>().add(AuthBiometricEnableRequested());
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (!mounted) {
            return;
          }

          if (state is AuthLoading) {
            setState(() => _isButtonTapped = true);
          } else if (state is AuthUnauthenticated) {
            // Xảy ra khi user huỷ xác thực vân tay hoặc xác thực thất bại
            setState(() => _isButtonTapped = false);
          } else if (state is AuthAuthenticated) {
            setState(() => _isButtonTapped = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đăng nhập thành công')),
            );
            Navigator.pushNamed(context, '/home');
          } else if (state is AuthPromptBiometricEnable) {
            // Không reset _isButtonTapped vì vẫn đang trong cùng login flow
            _showEnableBiometricDialog();
          } else if (state is AuthBiometricEnabled) {
            setState(() {
              _isBiometricAvailable = true;
              _isBiometricEnabled = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã bật đăng nhập vân tay'),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is AuthFailure) {
            setState(() => _isButtonTapped = false);
            // Refresh trạng thái vân tay — có thể đã bị clearAll() trong BLoC
            _checkBiometricStatus();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Lỗi đăng nhập: ${state.message}'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: const Color(0xFF29478B),
          body: Stack(
            children: [
              _buildTopDecoration(),
              SafeArea(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height -
                          MediaQuery.of(context).padding.top -
                          MediaQuery.of(context).padding.bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildBrandingSection(),
                        const SizedBox(height: 36),
                        _buildForm(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Helper widgets ───────────────────────────────────────────────────────

  Widget _buildTopDecoration() {
    return SizedBox(
      width: double.infinity,
      height: 220,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            top: -60,
            right: -50,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                color: const Color(0xFF1E3579),
                borderRadius: BorderRadius.circular(120),
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 40,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFF3459AE).withOpacity(0.65),
                borderRadius: BorderRadius.circular(75),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandingSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 110),
      child: Column(
        children: const [
          Text(
            'AIoT Platform',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Hệ thống quản lý, giám sát\n& vận hành thiết bị',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required Widget prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFECF1FD), fontSize: 14),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFE3EAFC).withOpacity(0.5),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE3EAFC), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE3EAFC), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFC5D5F8), width: 1.25),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.25),
      ),
      errorStyle: const TextStyle(color: Color(0xFFFFB3B3), fontSize: 11),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tên đăng nhập',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _usernameController,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            validator: _validateUsername,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: _fieldDecoration(
              hint: 'Nhập tên đăng nhập',
              prefixIcon: const Icon(
                Icons.person_outline_rounded,
                color: Color(0xFFECF1FD),
                size: 20,
              ),
            ),
            onFieldSubmitted: (_) =>
                FocusScope.of(context).requestFocus(_passwordFocusNode),
          ),
          const SizedBox(height: 25),
          const Text(
            'Mật khẩu',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            focusNode: _passwordFocusNode,
            textInputAction: TextInputAction.done,
            validator: _validatePassword,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: _fieldDecoration(
              hint: 'Mật khẩu',
              prefixIcon: const Icon(
                Icons.lock_outline_rounded,
                color: Color(0xFFECF1FD),
                size: 20,
              ),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: const Color(0xFFECF1FD),
                  size: 20,
                ),
              ),
            ),
            onFieldSubmitted: (_) => _login(),
          ),
          const SizedBox(height: 25),
          Row(
            children: [
              Checkbox(
                value: _rememberMe,
                onChanged: (v) => setState(() => _rememberMe = v ?? false),
                activeColor: const Color(0xFF3459AE),
                checkColor: Colors.white,
                side: const BorderSide(color: Color(0xFF45556C), width: 1.7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              const Text(
                'Ghi nhớ',
                style: TextStyle(color: Color(0xFFCAD5E2), fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 25),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isButtonTapped ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                disabledBackgroundColor: Colors.white.withOpacity(0.7),
                foregroundColor: const Color(0xFF3459AE),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _isButtonTapped
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF3459AE),
                        ),
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Đăng nhập',
                      style: TextStyle(
                        color: Color(0xFF3459AE),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: _showForgotPassword,
              child: const Text(
                'Quên mật khẩu?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (_isBiometricAvailable && _isBiometricEnabled) ...[
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _loginWithBiometric,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3EAFC).withOpacity(0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE3EAFC).withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.fingerprint,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Đăng nhập bằng vân tay',
                    style: TextStyle(
                      color: Color(0xFFCAD5E2),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_isBiometricAvailable && !_isBiometricEnabled) ...[
            const SizedBox(height: 20),
            Center(
              child: GestureDetector(
                onTap: () async {
                  // Cần refreshToken → chỉ kích hoạt được sau khi đã đăng nhập
                  final repo = context.read<AuthBloc>().biometricRepository;
                  final token = await repo.getRefreshToken();
                  // Nếu chưa có token, yêu cầu đăng nhập bằng user/pass trước
                  if (!mounted) return;
                  if (token == null || token.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Vui lòng đăng nhập bằng tài khoản trước để thiết lập vân tay',
                        ),
                        duration: Duration(seconds: 3),
                      ),
                    );
                    return;
                  }
                  _showEnableBiometricDialog();
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.fingerprint, color: Color(0xFF8AABF0), size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Thiết lập đăng nhập vân tay',
                      style: TextStyle(
                        color: Color(0xFF8AABF0),
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFF8AABF0),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
