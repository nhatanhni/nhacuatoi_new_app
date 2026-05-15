import 'package:equatable/equatable.dart';

abstract class ForgotPasswordEvent extends Equatable {
  const ForgotPasswordEvent();

  @override
  List<Object?> get props => [];
}

class ForgotPasswordEmailSubmitted extends ForgotPasswordEvent {
  final String email;

  const ForgotPasswordEmailSubmitted(this.email);

  @override
  List<Object?> get props => [email];
}

class ForgotPasswordOtpVerified extends ForgotPasswordEvent {
  final String email;
  final String otpCode;

  const ForgotPasswordOtpVerified({required this.email, required this.otpCode});

  @override
  List<Object?> get props => [email, otpCode];
}

class ForgotPasswordResetRequested extends ForgotPasswordEvent {
  final String email;
  final String resetToken;
  final String newPassword;

  const ForgotPasswordResetRequested({
    required this.email,
    required this.resetToken,
    required this.newPassword,
  });

  @override
  List<Object?> get props => [email, resetToken, newPassword];
}
