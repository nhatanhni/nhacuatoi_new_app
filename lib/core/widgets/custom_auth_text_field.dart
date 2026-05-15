import 'package:flutter/material.dart';
import 'package:iot_app/core/theme/app_colors.dart';
import 'package:iot_app/core/theme/app_styles.dart';

class CustomAuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData? prefixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final FocusNode? focusNode;
  final Function(String)? onSubmitted;
  final Widget? suffixIcon;
  final bool hasError;

  const CustomAuthTextField({
    Key? key,
    required this.controller,
    required this.hintText,
    this.prefixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.focusNode,
    this.onSubmitted,
    this.suffixIcon,
    this.hasError = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: AppStyles.authBody,
      cursorColor: AppColors.textWhite,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppStyles.authHint,
        prefixIcon: prefixIcon != null
            ? Icon(
                prefixIcon,
                color: hasError ? AppColors.error : AppColors.inputBorder,
                size: 20,
              )
            : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppStyles.spacingMd,
          vertical: AppStyles.spacingMd,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppStyles.radiusMd),
          borderSide: BorderSide(
            color: hasError ? AppColors.error : AppColors.inputBorder,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppStyles.radiusMd),
          borderSide: BorderSide(
            color: hasError ? AppColors.error : AppColors.inputFocusedBorder,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
