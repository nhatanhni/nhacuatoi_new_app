import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iot_app/bloc/forgot_password/forgot_password_event.dart';
import 'package:iot_app/bloc/forgot_password/forgot_password_state.dart';
import 'package:iot_app/core/services/api_service.dart';

class ForgotPasswordBloc
    extends Bloc<ForgotPasswordEvent, ForgotPasswordState> {
  final ApiService apiService;

  ForgotPasswordBloc({required this.apiService})
      : super(ForgotPasswordInitial()) {
    on<ForgotPasswordEmailSubmitted>(_onEmailSubmitted);
    on<ForgotPasswordOtpVerified>(_onOtpVerified);
    on<ForgotPasswordResetRequested>(_onResetRequested);
  }

  Future<void> _onEmailSubmitted(
    ForgotPasswordEmailSubmitted event,
    Emitter<ForgotPasswordState> emit,
  ) async {
    emit(ForgotPasswordLoading());
    try {
      await apiService.forgotPassword(event.email);
      emit(ForgotPasswordEmailSent(event.email));
    } catch (e) {
      emit(ForgotPasswordFailure(
        e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> _onOtpVerified(
    ForgotPasswordOtpVerified event,
    Emitter<ForgotPasswordState> emit,
  ) async {
    emit(ForgotPasswordLoading());
    try {
      final resetToken = await apiService.verifyForgotPasswordOtp(
        event.email,
        event.otpCode,
      );
      emit(ForgotPasswordOtpSuccess(
        email: event.email,
        resetToken: resetToken,
      ));
    } catch (e) {
      emit(ForgotPasswordFailure(
        e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> _onResetRequested(
    ForgotPasswordResetRequested event,
    Emitter<ForgotPasswordState> emit,
  ) async {
    emit(ForgotPasswordLoading());
    try {
      await apiService.resetPassword(
        email: event.email,
        resetToken: event.resetToken,
        newPassword: event.newPassword,
      );
      emit(ForgotPasswordResetSuccess());
    } catch (e) {
      emit(ForgotPasswordFailure(
        e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }
}
