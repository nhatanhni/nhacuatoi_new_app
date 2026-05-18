import 'package:flutter/material.dart';

class PlaceholderBox extends StatelessWidget {
  const PlaceholderBox({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 100,
        color: Colors.grey[300],
      ),
    );
  }
}
