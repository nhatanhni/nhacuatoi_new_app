import 'package:flutter/material.dart';

class CustomButton extends StatefulWidget {
  final Future<void> Function() onTap;
  final String label;
  final bool isButtonTapped;

  const CustomButton({
    Key? key,
    required this.onTap,
    required this.label,
    this.isButtonTapped = false,
  }) : super(key: key);

  @override
  _CustomButtonState createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _isTapped = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        setState(() {
          _isTapped = true;
        });
      },
      onTapUp: (details) async {
        await widget.onTap();
        setState(() {
          _isTapped = false;
        });
      },
      onTapCancel: () {
        setState(() {
          _isTapped = false;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.2,
            vertical: MediaQuery.of(context).size.height * 0.02),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: (_isTapped || widget.isButtonTapped)
              ? Theme.of(context).highlightColor
              : Theme.of(context).primaryColor,
        ),
        child: Text(widget.label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
