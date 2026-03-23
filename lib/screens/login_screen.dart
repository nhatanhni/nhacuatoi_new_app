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
      _showAlertDialog('Điều khoản dịch vụ', 'Bạn cần đồng ý với các điều khoản Nhà Của Tôi.');
      return;
    }

    context.read<AuthBloc>().add(AuthLoginRequested(
      username: username,
      password: password,
    ));
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
          body: SingleChildScrollView(
            child: Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.blue, Colors.blueAccent],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const SizedBox(height: 30),
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.white,
                    child: Text(
                      'NCT',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 50,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 5,
                          spreadRadius: 2,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        children: <Widget>[
                          TextFormField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              hintText: 'Tên đăng nhập',
                              icon: Icon(Icons.person),
                            ),
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.next,
                            validator: _validateUsername,
                            onFieldSubmitted: (_) {
                              FocusScope.of(context).requestFocus(_passwordFocusNode);
                            },
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _passwordController,
                            decoration: const InputDecoration(
                              hintText: 'Mật khẩu',
                              icon: Icon(Icons.lock),
                            ),
                            obscureText: true,
                            focusNode: _passwordFocusNode,
                            textInputAction: TextInputAction.done,
                            validator: _validatePassword,
                            onFieldSubmitted: (_) {
                              _login();
                            },
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: <Widget>[
                              Checkbox(
                                value: _isAgreed,
                                onChanged: (bool? value) {
                                  setState(() {
                                    _isAgreed = value ?? false;
                                  });
                                },
                              ),
                              GestureDetector(
                                onTap: _launchPrivacyPolicy,
                                child: Row(
                                  children: const [
                                    Text(
                                      'Đồng ý với các ',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    Text(
                                      'điều khoản',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.blue,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: _isButtonTapped ? null : _login,
                            child: Container(
                              alignment: Alignment.center,
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              decoration: BoxDecoration(
                                color: _isButtonTapped ? Colors.blueAccent : Colors.blue,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: _isButtonTapped
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      'Đăng nhập',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(context, '/register');
                            },
                            child: const Text(
                              'Chưa có tài khoản? Đăng ký ngay',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 16,
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
        ), // BlocListener
      ), // GestureDetector
    );
  }
}
