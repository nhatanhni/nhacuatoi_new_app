// ignore_for_file: avoid_print

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iot_app/repository/api_service.dart';
// import 'package:fluttertoast/fluttertoast.dart';
import '../utils/toast_helper.dart';
import 'package:iot_app/main.dart';
import 'package:url_launcher/url_launcher.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isButtonTapped = false;
  bool _isTermsAccepted = false;
  String _result = '';

  // focus nodes to jump to the next field
  final _userNameFocusNode = FocusNode();
  final _passWordFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _addressFocusNode = FocusNode();

  // fullName, userName, passWord, email, phone, address
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _passWordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  ApiService get _apiService => MyApp.apiService;

  static final RegExp _fullNameRegex = RegExp(
    r"^[\p{L}\p{M}\s\.,\-']+$",
    unicode: true,
  );
  static final RegExp _userNameRegex = RegExp(r'^[a-zA-Z0-9._-]+$');
  static final RegExp _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final RegExp _phoneRegex = RegExp(r'^(\+84|0)(3|5|7|8|9)\d{8}$');

  String? _validateFullName(String? value) {
    final fullName = value?.trim() ?? '';

    if (fullName.isEmpty) {
      return 'Vui lòng nhập họ và tên';
    }
    if (fullName.length < 2 || fullName.length > 60) {
      return 'Họ và tên phải từ 2 đến 60 ký tự';
    }
    if (!_fullNameRegex.hasMatch(fullName)) {
      return 'Họ và tên chứa ký tự không hợp lệ';
    }

    return null;
  }

  String? _validateUserName(String? value) {
    final userName = value?.trim() ?? '';

    if (userName.isEmpty) {
      return 'Vui lòng nhập tài khoản người dùng';
    }
    if (userName.length < 4 || userName.length > 30) {
      return 'Tài khoản phải từ 4 đến 30 ký tự';
    }
    if (!_userNameRegex.hasMatch(userName)) {
      return 'Tài khoản chỉ gồm chữ, số, dấu chấm, gạch dưới hoặc gạch ngang';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    final passWord = value ?? '';

    if (passWord.isEmpty) {
      return 'Vui lòng nhập mật khẩu';
    }
    if (passWord.length < 8 || passWord.length > 64) {
      return 'Mật khẩu phải từ 8 đến 64 ký tự';
    }
    if (!RegExp(r'[A-Z]').hasMatch(passWord) ||
        !RegExp(r'[a-z]').hasMatch(passWord) ||
        !RegExp(r'\d').hasMatch(passWord)) {
      return 'Mật khẩu cần có chữ hoa, chữ thường và số';
    }

    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Vui lòng nhập email';
    }
    if (!_emailRegex.hasMatch(email)) {
      return 'Email không hợp lệ';
    }

    return null;
  }

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';

    if (phone.isEmpty) {
      return 'Vui lòng nhập số điện thoại';
    }
    if (!_phoneRegex.hasMatch(phone)) {
      return 'Số điện thoại không hợp lệ (VD: 09xxxxxxxx hoặc +849xxxxxxxx)';
    }

    return null;
  }

  String? _validateAddress(String? value) {
    final address = value?.trim() ?? '';

    if (address.isEmpty) {
      return 'Vui lòng nhập địa chỉ';
    }
    if (address.length < 5 || address.length > 200) {
      return 'Địa chỉ phải từ 5 đến 200 ký tự';
    }

    return null;
  }

  // function to sign up
  Future<bool> _signUp() async {
    final fullName = _fullNameController.text.trim();
    final userName = _userNameController.text.trim();
    final passWord = _passWordController.text;
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();

    try {
      final result = await _apiService.signUp({
        'fullName': fullName,
        'userName': userName,
        'passWord': passWord,
        'email': email,
        'phone': phone,
        'address': address,
      });
      print(result);
      // await _userRepository.saveUserData(result['Data']);
      // await _userRepository.saveLoginStatus(true); // Save login status
      _result = '';
      return true;
    } on TimeoutException {
      _result = 'Yêu cầu đăng ký bị timeout. Vui lòng thử lại.';
      return false;
    } on FormatException {
      _result = 'Dữ liệu trả về không hợp lệ. Vui lòng thử lại sau.';
      return false;
    } catch (e) {
      print("Error: $e");
      _result = e.toString().replaceFirst('Exception: ', '');
      return false;
    }
  }

  Future<void> _launchURL() async {
    const url = 'http://nhacuatoi.com.vn:5001/index.php/services/privacy';
    final uri = Uri.tryParse(url);

    if (uri == null) {
      Fluttertoast.showToast(
        msg: 'Liên kết điều khoản không hợp lệ',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        _showErrorDialog('Không thể mở điều khoản', 'Vui lòng thử lại sau.');
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showErrorDialog('Lỗi mở liên kết', 'Không thể mở trang điều khoản.');
    }
  }

  Future<void> _handleRegister() async {
    if (_isButtonTapped) {
      return;
    }

    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      Fluttertoast.showToast(
        msg: 'Vui lòng kiểm tra lại dữ liệu đăng ký',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    if (!_isTermsAccepted) {
      Fluttertoast.showToast(
        msg: 'Bạn phải đồng ý với các điều khoản Nhà Của Tôi',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    setState(() {
      _isButtonTapped = true;
    });

    final success = await _signUp();
    if (!mounted) {
      return;
    }

    setState(() {
      _isButtonTapped = false;
    });

    if (success) {
      Fluttertoast.showToast(
        msg: 'Đăng ký thành công!',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Theme.of(context).primaryColor,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      Navigator.pushNamed(context, '/login');
      return;
    }

    _showErrorDialog('Đăng ký thất bại', 'Chi tiết: $_result');
  }

  void _showErrorDialog(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog.adaptive(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _userNameFocusNode.dispose();
    _passWordFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    _addressFocusNode.dispose();
    _fullNameController.dispose();
    _userNameController.dispose();
    _passWordController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Đăng ký tài khoản")),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextFormField(
                        controller: _fullNameController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          labelText: 'Họ và tên',
                        ),
                        validator: _validateFullName,
                        onFieldSubmitted: (_) =>
                            _userNameFocusNode.requestFocus(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextFormField(
                        focusNode: _userNameFocusNode,
                        controller: _userNameController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          labelText: 'Tài khoản dùng',
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._-]')),
                        ],
                        validator: _validateUserName,
                        onFieldSubmitted: (_) =>
                            _passWordFocusNode.requestFocus(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextFormField(
                        obscureText: true,
                        focusNode: _passWordFocusNode,
                        controller: _passWordController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          labelText: 'Mật khẩu',
                        ),
                        validator: _validatePassword,
                        onFieldSubmitted: (_) => _emailFocusNode.requestFocus(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextFormField(
                        keyboardType: TextInputType.emailAddress,
                        focusNode: _emailFocusNode,
                        controller: _emailController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          labelText: 'Email',
                        ),
                        validator: _validateEmail,
                        onFieldSubmitted: (_) => _phoneFocusNode.requestFocus(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextFormField(
                        keyboardType: TextInputType.phone,
                        focusNode: _phoneFocusNode,
                        controller: _phoneController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          labelText: 'Số điện thoại',
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                        ],
                        validator: _validatePhone,
                        onFieldSubmitted: (_) =>
                            _addressFocusNode.requestFocus(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextFormField(
                        controller: _addressController,
                        focusNode: _addressFocusNode,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          labelText: 'Địa chỉ',
                        ),
                        validator: _validateAddress,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _isTermsAccepted,
                            onChanged: (bool? value) {
                              setState(() {
                                _isTermsAccepted = value ?? false;
                              });
                            },
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: _launchURL,
                              child: const Text(
                                'Bạn đồng ý với các điều khoản Nhà Của Tôi',
                                style: TextStyle(
                                  decoration: TextDecoration.underline,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _isButtonTapped ? null : _handleRegister,
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width * 0.2,
                      vertical: MediaQuery.of(context).size.height * 0.02),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: (_isButtonTapped)
                        ? Theme.of(context).highlightColor
                        : Theme.of(context).primaryColor,
                  ),
                  child: _isButtonTapped
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text("Đăng ký",
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
