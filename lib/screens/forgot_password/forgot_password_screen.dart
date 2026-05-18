import 'package:flutter/material.dart';
import 'package:iot_app/core/theme/app_colors.dart';
import 'package:iot_app/core/utils/toast_helper.dart';
import 'forgot_password_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Màn hình Quên mật khẩu
// Bước 1: Tìm tài khoản bằng email/username
// Bước 2: Đổi mật khẩu mới
// ─────────────────────────────────────────────────────────────────────────────
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  // ── State
  int _step = 1; // 1 = Tìm tài khoản, 2 = Đổi mật khẩu
  bool _isLoading = false;
  String _errorText = '';

  // ── Controllers bước 1
  final _accountController = TextEditingController();

  // ── Controllers bước 2
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // ── Visibility toggles
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  // ── Focus nodes
  final _newPwdFocus = FocusNode();
  final _confirmPwdFocus = FocusNode();

  // ── Service
  final _service = ForgotPasswordService();

  // ── Animation
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();

    // Listen to changes in new password to update strength hint dynamically
    _newPasswordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _newPasswordController.removeListener(_onPasswordChanged);
    _fadeController.dispose();
    _accountController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _newPwdFocus.dispose();
    _confirmPwdFocus.dispose();
    super.dispose();
  }

  // ── Bước 1: Tìm tài khoản
  Future<void> _findAccount() async {
    final account = _accountController.text.trim();
    if (account.isEmpty) {
      setState(() => _errorText = 'Vui lòng nhập email hoặc tên đăng nhập.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = '';
    });

    try {
      await _service.findAccount(account);
      _fadeController.reset();
      setState(() => _step = 2);
      _fadeController.forward();
    } catch (e) {
      setState(() {
        _errorText = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Bước 2: Đổi mật khẩu
  Future<void> _changePassword() async {
    final current = _currentPasswordController.text;
    final newPwd = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (current.isEmpty || newPwd.isEmpty || confirm.isEmpty) {
      setState(() => _errorText = 'Vui lòng điền đầy đủ thông tin.');
      return;
    }
    if (newPwd != confirm) {
      setState(() => _errorText = 'Mật khẩu xác nhận không khớp.');
      return;
    }
    if (newPwd.length < 8) {
      setState(() => _errorText = 'Mật khẩu mới phải có ít nhất 8 ký tự.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = '';
    });

    try {
      await _service.changePassword(
        currentPassword: current,
        newPassword: newPwd,
      );

      if (!mounted) return;
      Fluttertoast.showToast(
        msg: 'Đổi mật khẩu thành công!',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: AppColors.success,
        textColor: Colors.white,
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _errorText = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Go back to step 1
  void _goBack() {
    if (_step == 2) {
      _fadeController.reset();
      setState(() {
        _step = 1;
        _errorText = '';
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });
      _fadeController.forward();
    } else {
      Navigator.pop(context);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/LoginScreen.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // ── Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _goBack,
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: _step == 1 ? _buildStep1() : _buildStep2(),
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

  // ─────────────────────────────────────────────────────────────────────────
  // BƯỚC 1 — TÌM TÀI KHOẢN
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        // Tiêu đề
        const Text(
          'Quên mật khẩu?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),

        const SizedBox(height: 20),

        // Step indicator placed directly under title
        _buildStepIndicator(currentStep: 1),

        const SizedBox(height: 36),

        // Label
        const Text(
          'Email hoặc tên đăng nhập',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),

        // Input field
        _buildTextField(
          controller: _accountController,
          hint: 'example@email.com',
          prefixIcon: Icons.person_search_outlined,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _findAccount(),
        ),

        // Error message
        if (_errorText.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildErrorBox(_errorText),
        ] else
          const SizedBox(height: 28),

        // Button
        _buildPrimaryButton(
          label: 'Tìm tài khoản',
          icon: Icons.search_rounded,
          onPressed: _findAccount,
        ),

        const SizedBox(height: 24),

        // Quay lại đăng nhập
        Center(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text.rich(
              TextSpan(
                text: 'Nhớ mật khẩu rồi? ',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                children: [
                  TextSpan(
                    text: 'Đăng nhập',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BƯỚC 2 — ĐỔI MẬT KHẨU
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        // Tiêu đề
        const Text(
          'Đặt mật khẩu mới',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),

        const SizedBox(height: 20),

        // Step indicator placed directly under title
        _buildStepIndicator(currentStep: 2),

        const SizedBox(height: 32),

        // Mật khẩu hiện tại
        const Text(
          'Mật khẩu hiện tại',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _currentPasswordController,
          hint: '••••••••',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: _obscureCurrent,
          isPassword: true,
          onToggleObscure: () =>
              setState(() => _obscureCurrent = !_obscureCurrent),
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => FocusScope.of(context).requestFocus(_newPwdFocus),
        ),

        const SizedBox(height: 20),

        // Mật khẩu mới
        const Text(
          'Mật khẩu mới',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _newPasswordController,
          hint: '••••••••',
          prefixIcon: Icons.lock_person_outlined,
          obscureText: _obscureNew,
          isPassword: true,
          focusNode: _newPwdFocus,
          onToggleObscure: () => setState(() => _obscureNew = !_obscureNew),
          textInputAction: TextInputAction.next,
          onSubmitted: (_) =>
              FocusScope.of(context).requestFocus(_confirmPwdFocus),
        ),

        // Password strength hint placed directly under the new password field
        _buildPasswordHint(),

        const SizedBox(height: 20),

        // Xác nhận mật khẩu mới
        const Text(
          'Xác nhận mật khẩu mới',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _confirmPasswordController,
          hint: 'Nhập lại mật khẩu mới',
          prefixIcon: Icons.verified_outlined,
          obscureText: _obscureConfirm,
          isPassword: true,
          focusNode: _confirmPwdFocus,
          onToggleObscure: () =>
              setState(() => _obscureConfirm = !_obscureConfirm),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _changePassword(),
        ),

        // Error message
        if (_errorText.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildErrorBox(_errorText),
        ] else
          const SizedBox(height: 28),

        // Button xác nhận
        _buildPrimaryButton(
          label: 'Xác nhận đổi mật khẩu',
          icon: Icons.check_circle_outline_rounded,
          onPressed: _changePassword,
        ),

        const SizedBox(height: 16),

        // Nút quay lại bước 1
        Center(
          child: TextButton(
            onPressed: _goBack,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text(
              'Quay lại',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white70,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGETS TÁCH
  // ─────────────────────────────────────────────────────────────────────────

  /// Step indicator (1 → 2)
  Widget _buildStepIndicator({required int currentStep}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _stepDot(label: '1', active: currentStep >= 1),
        _stepLine(active: currentStep >= 2),
        _stepDot(label: '2', active: currentStep >= 2),
      ],
    );
  }

  Widget _stepDot({required String label, required bool active}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? Colors.white : Colors.white.withOpacity(0.25),
        border: Border.all(
          color: active ? Colors.white : Colors.white38,
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: active ? AppColors.primary : Colors.white60,
          ),
        ),
      ),
    );
  }

  Widget _stepLine({required bool active}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 50,
      height: 2,
      color: active ? Colors.white : Colors.white30,
    );
  }

  /// Password strength hint row with 3 lines
  Widget _buildPasswordHint() {
    final pwd = _newPasswordController.text;
    final hasMinLength = pwd.length >= 8;
    final hasUpperLower =
        pwd.contains(RegExp(r'[A-Z]')) && pwd.contains(RegExp(r'[a-z]'));
    final hasNumberSpecial =
        pwd.contains(RegExp(r'[0-9]')) &&
        pwd.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHintItem('Ít nhất 8 ký tự', hasMinLength),
          const SizedBox(height: 6),
          _buildHintItem('Có chữ hoa & chữ thường', hasUpperLower),
          const SizedBox(height: 6),
          _buildHintItem('Có số & ký tự đặc biệt', hasNumberSpecial),
        ],
      ),
    );
  }

  Widget _buildHintItem(String text, bool isMet) {
    return Row(
      children: [
        Icon(
          isMet ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: 14,
          color: isMet ? Colors.greenAccent : Colors.white.withOpacity(0.5),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isMet ? Colors.greenAccent : Colors.white.withOpacity(0.6),
            fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  /// Error box
  Widget _buildErrorBox(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Primary action button
  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primary,
          disabledBackgroundColor: Colors.white60,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Shared TextField builder
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData prefixIcon,
    bool obscureText = false,
    bool isPassword = false,
    FocusNode? focusNode,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    Function(String)? onSubmitted,
    VoidCallback? onToggleObscure,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.55),
          fontSize: 14,
        ),
        prefixIcon: Icon(prefixIcon, color: Colors.white, size: 22),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscureText
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: onToggleObscure,
              )
            : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.22),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white, width: 1.5),
        ),
      ),
    );
  }
}
