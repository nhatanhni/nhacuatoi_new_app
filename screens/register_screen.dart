// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:iot_app/repository/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class RegisterScreen extends StatefulWidget {
  RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isButtonTapped = false;
  bool _isRegisterError = false;
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

  final _apiService = ApiService();

  // function to sign up
  Future<void> _signUp() async {
    final fullName = _fullNameController.text;
    final userName = _userNameController.text;
    final passWord = _passWordController.text;
    final email = _emailController.text;
    final phone = _phoneController.text;
    final address = _addressController.text;

    if (!_isTermsAccepted) {
      // If terms are not accepted, show error toast
      Fluttertoast.showToast(
        msg: "Bạn phải đồng ý với các điều khoản Nhà Của Tôi",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

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
    } catch (e) {
      // Handle the error here
      print("Error: $e");
      _isRegisterError = true;
      _result = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _isButtonTapped = false; // Reset the button color
      });
    }
  }

  void _launchURL() async {
    const url = 'http://nhacuatoi.com.vn:5001/index.php/services/privacy';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  void dispose() {
    _userNameFocusNode.dispose();
    _passWordFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    _addressFocusNode.dispose();
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
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập họ và tên';
                          }
                          if (!RegExp(r'^[\p{L}\p{M}\p{Z}\p{P}]+$',
                              unicode: true)
                              .hasMatch(value)) {
                            return 'Họ và tên chỉ có thể chứa các ký tự chữ';
                          }
                          return null;
                        },
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
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập tài khoản người dùng';
                          }
                          // only allow alphanumeric characters
                          if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(value)) {
                            return 'Tài khoản người dùng chỉ có thể chứa các ký tự chữ và số, không dấu, không cách';
                          }
                          return null;
                        },
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
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập mật khẩu';
                          }
                          return null;
                        },
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
                onTapDown: (details) {
                  setState(() {
                    _isButtonTapped = true;
                  });
                },
                onTapUp: (details) async {
                  if (_formKey.currentState?.validate() ?? false) {
                    await _signUp();
                    // show alert dialog
                    if (_isRegisterError) {
                      showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog.adaptive(
                              title: const Text('Lỗi đăng nhập'),
                              content: Text("Chi tiết: _result"),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _isRegisterError = false;
                                  },
                                  child: const Text('OK'),
                                )
                              ],
                            );
                          });
                    } else {
                      Fluttertoast.showToast(
                          msg: "Đăng ký thành công!",
                          toastLength: Toast.LENGTH_SHORT,
                          gravity: ToastGravity.BOTTOM,
                          timeInSecForIosWeb: 1,
                          backgroundColor: Theme.of(context).primaryColor,
                          textColor: Colors.white,
                          fontSize: 16.0);
                      Navigator.pushNamed(context, '/login');
                    }
                  } else {
                    Fluttertoast.showToast(
                        msg: "Vui lòng điền đầy đủ thông tin!",
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.BOTTOM,
                        timeInSecForIosWeb: 1,
                        backgroundColor: Colors.red,
                        textColor: Colors.white,
                        fontSize: 16.0);
                  }
                },
                onTapCancel: () {
                  setState(() {
                    _isButtonTapped = false;
                  });
                },
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
                  child: const Text("Đăng ký",
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
