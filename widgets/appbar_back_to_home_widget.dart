import 'package:flutter/material.dart';

class AppBarBackToHome extends StatelessWidget {
  const AppBarBackToHome({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
        onPressed: () {
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
        },
        icon: const Icon(Icons.arrow_back));
  }
}
