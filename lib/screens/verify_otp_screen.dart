import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iot_app/bloc/forgot_password/forgot_password_bloc.dart';
import 'package:iot_app/bloc/forgot_password/forgot_password_event.dart';
import 'package:iot_app/bloc/forgot_password/forgot_password_state.dart';
import 'package:iot_app/screens/reset_password_screen.dart';

class VerifyOtpScreen extends StatefulWidget {
  final String email;

  const VerifyOtpScreen({super.key, required this.email});

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  String? _validateOtp(String? value) {
    final otp = value?.trim() ?? '';
    if (otp.isEmpty) return 'Vui lòng nhập mã OTP';
    if (otp.length != 6 || !RegExp(r'^\d{6}$').hasMatch(otp)) {
      return 'Mã OTP gồm đúng 6 chữ số';
    }
    return null;
  }

  void _submit(BuildContext context) {
    FocusScope.of(context).unfocus();
    final otp = _otpController.text.trim();
    if (_validateOtp(otp) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đúng mã OTP 6 chữ số')),
      );
      return;
    }
    context.read<ForgotPasswordBloc>().add(
          ForgotPasswordOtpVerified(email: widget.email, otpCode: otp),
        );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: BlocConsumer<ForgotPasswordBloc, ForgotPasswordState>(
        listener: (context, state) {
          if (state is ForgotPasswordOtpSuccess) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<ForgotPasswordBloc>(),
                  child: ResetPasswordScreen(
                    email: state.email,
                    resetToken: state.resetToken,
                  ),
                ),
              ),
            );
          } else if (state is ForgotPasswordFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is ForgotPasswordLoading;
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.black87, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text(
                'Xác thực OTP',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.mark_email_read_outlined,
                      size: 56,
                      color: Color(0xFF3459AE),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Kiểm tra email của bạn',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                          height: 1.5,
                        ),
                        children: [
                          const TextSpan(
                              text: 'Mã OTP 6 chữ số đã được gửi tới\n'),
                          TextSpan(
                            text: widget.email,
                            style: const TextStyle(
                              color: Color(0xFF3459AE),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const TextSpan(
                              text: '\nMã có hiệu lực trong 5 phút.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Mã OTP',
                      style: TextStyle(
                        color: Color(0xFF4A5568),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onFieldSubmitted: (_) => _submit(context),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 8,
                        color: Color(0xFF3459AE),
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '------',
                        hintStyle: const TextStyle(
                          color: Color(0xFFD1D5DB),
                          fontSize: 24,
                          letterSpacing: 8,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF0F4FF),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Color(0xFF3459AE), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : () => _submit(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3459AE),
                          disabledBackgroundColor:
                              const Color(0xFF3459AE).withOpacity(0.6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Xác nhận',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
