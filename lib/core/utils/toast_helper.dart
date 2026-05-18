// Toast helper để thay thế fluttertoast tạm thời cho iOS compatibility
import 'package:flutter/material.dart';

enum Toast {
  LENGTH_SHORT,
  LENGTH_LONG,
}

enum ToastGravity {
  TOP,
  CENTER,
  BOTTOM,
}

class Fluttertoast {
  static void showToast({
    required String msg,
    Toast? toastLength,
    ToastGravity? gravity,
    int? timeInSecForIosWeb,
    Color? backgroundColor,
    Color? textColor,
    double? fontSize,
  }) {
    // Tạm thời chỉ print message thay vì show toast
    print('Toast: $msg');
  }
}
