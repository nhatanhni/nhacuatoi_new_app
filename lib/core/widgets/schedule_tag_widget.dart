import 'package:flutter/material.dart';

class ScheduleTag extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color textColor;
  final Color color;
  const ScheduleTag(
      {Key? key,
      required this.icon,
      required this.text,
      required this.textColor,
      required this.color})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: color,
      ),
      child: Row(
        children: [
          Icon(icon),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: textColor),
          ),
        ],
      ),
    );
  }
}
