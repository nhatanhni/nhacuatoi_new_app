import 'package:flutter/material.dart';

class AppBarDropdown extends StatelessWidget {
  const AppBarDropdown({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (String result) {
        switch (result) {
          case 'add_device':
            Navigator.of(context).pushNamedAndRemoveUntil(
                '/add_device', (Route<dynamic> route) => false);
            break;
          case 'manage_device':
            Navigator.of(context).pushNamedAndRemoveUntil(
                '/manage_device', (Route<dynamic> route) => false);
            break;
          // Add more cases here for other menu items
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'add_device',
          child: Text('Thêm thiết bị'),
        ),
        const PopupMenuItem<String>(
          value: 'manage_device',
          child: Text('Quản lý thiết bị'),
        ),
        // Add more entries here for other menu items
      ],
    );
  }
}
