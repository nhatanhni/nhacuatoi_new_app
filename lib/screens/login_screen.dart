import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart'; // Import package for launching URLs
import 'package:iot_app/repository/api_service.dart';
import 'package:iot_app/repository/user_repository.dart';

class LoginScreen extends StatefulWidget {
  LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();

  bool _isButtonTapped = false;
  bool _isAgreed = false; // Trạng thái của checkbox

  bool _isLoginError = false;
  String _errorText = '';

  final _apiService = ApiService();
  final _userRepository = UserRepository();

  // Function to launch the privacy policy URL
  void _launchPrivacyPolicy() async {
    const url = 'http://nhacuatoi.com.vn:5001/index.php/services/privacy';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<void> _login() async {
    final username = _usernameController.text;
    final password = _passwordController.text;

    if (!_isAgreed) {
      _showAlertDialog('Điều khoản dịch vụ', 'Bạn cần đồng ý với các điều khoản Nhà Của Tôi.');
      return;
    }

    setState(() {
      _isButtonTapped = true;
    });

    try {
      final result = await _apiService.login(username, password);
      final data = result['Data'];

      if (data != null) {
        final accessToken = data['AccessToken'] as String?;
        final userId = data['UserId'] as String?;
        final userName = data['UserName'] as String?;

        await _userRepository.saveUserData(data);
        await _userRepository.saveLoginStatus(true);

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('accessToken', accessToken ?? '');

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
      } else {
        throw Exception('Dữ liệu trả về không hợp lệ.');
      }
    } catch (e) {
      setState(() {
        _isLoginError = true;
        _errorText = e.toString().replaceFirst('Exception: ', '');
      });

      _showAlertDialog('Lỗi đăng nhập', 'Chi tiết: $_errorText');
    } finally {
      setState(() {
        _isButtonTapped = false;
      });
    }
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
                  child: Column(
                    children: <Widget>[
                      TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          hintText: 'Tên đăng nhập',
                          icon: Icon(Icons.person),
                        ),
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) {
                          FocusScope.of(context).requestFocus(_passwordFocusNode);
                        },
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          hintText: 'Mật khẩu',
                          icon: Icon(Icons.lock),
                        ),
                        obscureText: true,
                        focusNode: _passwordFocusNode,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
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
                              children: [
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
                        onTap: () {
                          _login();
                        },
                        child: Container(
                          alignment: Alignment.center,
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            color: _isButtonTapped ? Colors.blueAccent : Colors.blue,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
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
                        child: Text(
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
