import 'package:flutter/material.dart';
// import 'package:fluttertoast/fluttertoast.dart';
import '../utils/toast_helper.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:iot_app/bloc/auth/auth_bloc.dart';
import 'package:iot_app/bloc/auth/auth_event.dart';
import 'package:iot_app/bloc/auth/auth_state.dart';
import 'package:iot_app/core/config/app_config.dart';

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
  bool _isAgreed = false;
  bool _obscurePassword = true;

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

  Future<void> _launchPrivacyPolicy() async {
    final policyUri = Uri.tryParse(AppConfig.privacyPolicyUrl);
    if (policyUri == null) {
      Fluttertoast.showToast(
        msg: 'Đường dẫn điều khoản không hợp lệ',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    try {
      final launched = await launchUrl(
        policyUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        _showAlertDialog('Không thể mở liên kết', 'Vui lòng thử lại sau.');
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showAlertDialog('Lỗi mở liên kết', 'Không thể mở điều khoản dịch vụ.');
    }
  }

  void _login() {
    if (_isButtonTapped) {
      return;
    }

    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      Fluttertoast.showToast(
        msg: 'Vui lòng kiểm tra lại thông tin đăng nhập',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (!_isAgreed) {
      _showAlertDialog(
        'Điều khoản dịch vụ',
        'Bạn cần đồng ý với các điều khoản Nhà Của Tôi.',
      );
      return;
    }

    context.read<AuthBloc>().add(
      AuthLoginRequested(username: username, password: password),
    );
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
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
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
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (!mounted) {
            return;
          }

          if (state is AuthLoading) {
            setState(() => _isButtonTapped = true);
          } else if (state is AuthAuthenticated) {
            setState(() => _isButtonTapped = false);
            Fluttertoast.showToast(
              msg: "Đăng nhập thành công!",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              timeInSecForIosWeb: 1,
              backgroundColor: Colors.green,
              textColor: Colors.white,
              fontSize: 16.0,
            );
            Navigator.pushNamed(context, '/home');
          } else if (state is AuthFailure) {
            setState(() => _isButtonTapped = false);
            _showAlertDialog('Lỗi đăng nhập', 'Chi tiết: ${state.message}');
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF071A2B),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF071A2B),
                  Color(0xFF0E2F47),
                  Color(0xFF155E78),
                ],
              ),
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      Positioned(
                        top: -80,
                        right: -40,
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            color: const Color(0xFF38D9FF).withOpacity(0.18),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -120,
                        left: -60,
                        child: Container(
                          width: 260,
                          height: 260,
                          decoration: BoxDecoration(
                            color: const Color(0xFF74F8D4).withOpacity(0.14),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - 34,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Container(
                                width: 104,
                                height: 104,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x4D05131F),
                                      blurRadius: 24,
                                      offset: Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(28),
                                  child: Image.asset(
                                    'assets/images/imghome.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Data Monitoring Platform',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Điều khiển thiết bị IoT an toàn, nhanh chóng',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFFC7E8FF),
                                  fontSize: 15,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Container(
                                width: double.infinity,
                                constraints: const BoxConstraints(
                                  maxWidth: 460,
                                ),
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  22,
                                  18,
                                  16,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF6FCFF),
                                  borderRadius: BorderRadius.circular(26),
                                  border: Border.all(
                                    color: const Color(0xFFBEE7F7),
                                    width: 1.2,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x33051725),
                                      blurRadius: 28,
                                      offset: Offset(0, 16),
                                    ),
                                  ],
                                ),
                                child: Form(
                                  key: _formKey,
                                  autovalidateMode:
                                      AutovalidateMode.onUserInteraction,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      const Text(
                                        'Đăng nhập',
                                        style: TextStyle(
                                          color: Color(0xFF0B2A43),
                                          fontSize: 25,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Sử dụng tài khoản của bạn để tiếp tục',
                                        style: TextStyle(
                                          color: Color(0xFF4E7089),
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      TextFormField(
                                        controller: _usernameController,
                                        keyboardType: TextInputType.text,
                                        textInputAction: TextInputAction.next,
                                        validator: _validateUsername,
                                        decoration: InputDecoration(
                                          labelText: 'Tên đăng nhập',
                                          hintText: 'Nhập tên đăng nhập',
                                          prefixIcon: const Icon(
                                            Icons.person_outline_rounded,
                                          ),
                                          filled: true,
                                          fillColor: const Color(0xFFECF7FE),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFF0B87C9),
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                        onFieldSubmitted: (_) {
                                          FocusScope.of(
                                            context,
                                          ).requestFocus(_passwordFocusNode);
                                        },
                                      ),
                                      const SizedBox(height: 14),
                                      TextFormField(
                                        controller: _passwordController,
                                        obscureText: _obscurePassword,
                                        focusNode: _passwordFocusNode,
                                        textInputAction: TextInputAction.done,
                                        validator: _validatePassword,
                                        decoration: InputDecoration(
                                          labelText: 'Mật khẩu',
                                          hintText: 'Nhập mật khẩu',
                                          prefixIcon: const Icon(
                                            Icons.lock_outline_rounded,
                                          ),
                                          suffixIcon: IconButton(
                                            onPressed: () {
                                              setState(() {
                                                _obscurePassword =
                                                    !_obscurePassword;
                                              });
                                            },
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons
                                                        .visibility_off_outlined
                                                  : Icons.visibility_outlined,
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: const Color(0xFFECF7FE),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFF0B87C9),
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                        onFieldSubmitted: (_) {
                                          _login();
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Checkbox(
                                            value: _isAgreed,
                                            activeColor: const Color(
                                              0xFF0D7BB3,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            ),
                                            onChanged: (bool? value) {
                                              setState(() {
                                                _isAgreed = value ?? false;
                                              });
                                            },
                                          ),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                top: 11,
                                              ),
                                              child: Wrap(
                                                children: [
                                                  const Text(
                                                    'Đồng ý với các ',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Color(0xFF35536A),
                                                    ),
                                                  ),
                                                  GestureDetector(
                                                    onTap: _launchPrivacyPolicy,
                                                    child: const Text(
                                                      'điều khoản dịch vụ',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Color(
                                                          0xFF0A7DBA,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        decoration:
                                                            TextDecoration
                                                                .underline,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: Material(
                                          color: Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: Ink(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              gradient: LinearGradient(
                                                begin: Alignment.centerLeft,
                                                end: Alignment.centerRight,
                                                colors: _isButtonTapped
                                                    ? const [
                                                        Color(0xFF5C9BBE),
                                                        Color(0xFF6FA9C8),
                                                      ]
                                                    : const [
                                                        Color(0xFF0E7EB7),
                                                        Color(0xFF06A6D7),
                                                      ],
                                              ),
                                            ),
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              onTap: _isButtonTapped
                                                  ? null
                                                  : _login,
                                              child: SizedBox(
                                                height: 52,
                                                child: Center(
                                                  child: _isButtonTapped
                                                      ? const SizedBox(
                                                          height: 24,
                                                          width: 24,
                                                          child: CircularProgressIndicator(
                                                            valueColor:
                                                                AlwaysStoppedAnimation<
                                                                  Color
                                                                >(Colors.white),
                                                            strokeWidth: 2.8,
                                                          ),
                                                        )
                                                      : const Text(
                                                          'Đăng nhập',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 17,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            letterSpacing: 0.2,
                                                          ),
                                                        ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Center(
                                        child: GestureDetector(
                                          onTap: () {
                                            Navigator.pushNamed(
                                              context,
                                              '/register',
                                            );
                                          },
                                          child: const Text(
                                            'Chưa có tài khoản? Đăng ký ngay',
                                            style: TextStyle(
                                              color: Color(0xFF0D84BE),
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ), // BlocListener
      ), // GestureDetector
    );
  }
}
