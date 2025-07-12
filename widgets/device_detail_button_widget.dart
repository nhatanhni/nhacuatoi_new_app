// ignore_for_file: use_key_in_widget_constructors

import 'package:flutter/material.dart';

class DeviceDetailButton extends StatefulWidget {
  final Color color;
  final IconData icon;
  bool? shouldDisplayDotIndicator;
  Color? dotIndicatorColor;
  String? title;
  final VoidCallback onTap;
  VoidCallback? onLongPress;

  DeviceDetailButton({
    required this.color,
    required this.icon,
    this.shouldDisplayDotIndicator,
    this.dotIndicatorColor,
    this.title,
    required this.onTap,
    this.onLongPress,
  });

  @override
  _DeviceDetailButtonState createState() => _DeviceDetailButtonState();
}

class _DeviceDetailButtonState extends State<DeviceDetailButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        setState(() {
          _isPressed = true;
        });
      },
      onTapUp: (details) {
        setState(() {
          _isPressed = false;
        });
        widget.onTap();
      },
      onLongPress: () {
        if (widget.onLongPress != null) {
          widget.onLongPress!();
        }
      },
      child: Container(
        height: MediaQuery.of(context).size.height * 0.1,
        width: MediaQuery.of(context).size.width * 0.25,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(widget.icon, color: Colors.white, size: 25),
                  (widget.title != null)
                      ? Text(
                          widget.title!,
                          style: const TextStyle(color: Colors.white),
                        )
                      : Container(),
                ],
              ),
            ),
            (widget.shouldDisplayDotIndicator != null)
                ? Positioned(
                    top: 5,
                    right: 5,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: widget.dotIndicatorColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : Container(),
          ],
        ),
      ),
    );
  }
}
