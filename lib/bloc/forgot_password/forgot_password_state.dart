import 'package:equatable/equatable.dart';

abstract class ForgotPasswordState extends Equatable {
  const ForgotPasswordState();

  @override
  List<Object?> get props => [];
}

class ForgotPasswordInitial extends ForgotPasswordState {}

class ForgotPasswordLoading extends ForgotPasswordState {}

/// OTP đã được gửi tới email — chuyển sang màn xác thực OTP.
class ForgotPasswordEmailSent extends ForgotPasswordState {
  final String email;

  const ForgotPasswordEmailSent(this.email);

  @override
  List<Object?> get props => [email];
}

/// OTP hợp lệ — chuyển sang màn đặt lại mật khẩu.
class ForgotPasswordOtpSuccess extends ForgotPasswordState {
  final String email;
  final String resetToken;

  const ForgotPasswordOtpSuccess({
    required this.email,
    required this.resetToken,
  });

  @override
  List<Object?> get props => [email, resetToken];
}

/// Mật khẩu đã được đặt lại thành công — điều hướng về login.
class ForgotPasswordResetSuccess extends ForgotPasswordState {}

class ForgotPasswordFailure extends ForgotPasswordState {
  final String message;

  const ForgotPasswordFailure(this.message);

  @override
  List<Object?> get props => [message];
}
