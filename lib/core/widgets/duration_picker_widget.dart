import 'package:flutter/material.dart';

class DurationPicker extends StatefulWidget {
  const DurationPicker({super.key});

  @override
  _DurationPickerState createState() => _DurationPickerState();
}

class _DurationPickerState extends State<DurationPicker> {
  int _duration = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text('Điều chỉnh khoảng thời gian'),
        const SizedBox(height: 16.0), // Add some spacing
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: () {
                setState(() {
                  if (_duration > 0) _duration--;
                });
              },
            ),
            Text('$_duration h'),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                setState(() {
                  if (_duration < 24) _duration++;
                });
              },
            ),
          ],
        ),
      ],
    );
  }
}
