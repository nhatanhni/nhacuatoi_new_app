// ignore_for_file: must_be_immutable

import 'package:flutter/material.dart';

class SensorReadingsCardWidget extends StatelessWidget {
  String title;
  String value;
  Color backgroundColor;
  Color textColor;
  SensorReadingsCardWidget(
      {Key? key,
      required this.title,
      required this.value,
      required this.backgroundColor,
      required this.textColor})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.all(10),
        height: MediaQuery.of(context).size.height * 0.20,
        decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF000000).withOpacity(1),
                offset: const Offset(0, 5),
                blurRadius: 0,
                spreadRadius: 2,
              ),
            ]),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(color: textColor, fontSize: 20),
              ),
              Text(
                value,
                style: TextStyle(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
