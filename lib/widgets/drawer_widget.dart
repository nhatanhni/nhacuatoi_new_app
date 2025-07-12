import 'package:flutter/material.dart';
import 'package:iot_app/repository/user_repository.dart';
import 'notification_list_widget.dart';
import '../screens/violation_statistics_screen.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({Key? key}) : super(key: key);

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  late Future<String> _username;

  @override
  void initState() {
    super.initState();
    _username = UserRepository().getUsername();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        // Important: Remove any padding from the ListView.
        padding: EdgeInsets.zero,
        children: [
          FutureBuilder<String>(
              future: _username,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return DrawerHeader(
                      decoration:
                          BoxDecoration(color: Theme.of(context).primaryColor),
                      child: const CircularProgressIndicator.adaptive());
                } else {
                  return DrawerHeader(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.waving_hand,
                          size: 100,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 10),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: snapshot.data != null
                                    ? 'Xin chào, '
                                    : 'Nhà của tôi',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 20),
                              ),
                              if (snapshot.data != null)
                                TextSpan(
                                  text: snapshot.data,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                        )
                      ],
                    ),
                  );
                }
              }),
          const ListTile(
            title: Text("Chức năng"),
          ),
          ListTile(
            leading: const Icon(
              Icons.supervisor_account,
            ),
            title: const Text('Cập nhật User'),
            onTap: () {
              // navigate to AddDeviceScreen
              Navigator.of(context).pop();
              Navigator.pushNamed(context, "/user_list");
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.devices_outlined,
            ),
            title: const Text('Danh sách thiết bị'),
            onTap: () {
              // navigate to AddDeviceScreen
              Navigator.of(context).pop();
              Navigator.pushNamed(context, "/device_list");
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.notifications,
            ),
            title: const Text('Lịch sử Thông báo'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationListWidget(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.analytics,
            ),
            title: const Text('Thống kê quan trắc vi phạm'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ViolationStatisticsScreen(),
                ),
              );
            },
          ),
          const Divider(),
          const ListTile(
            title: Text("Cài đặt"),
          ),
          ListTile(
            leading: const Icon(
              Icons.settings,
            ),
            title: const Text('Quản lý thiết bị'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, "/manage_device");
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.add_circle,
            ),
            title: const Text('Thêm thiết bị'),
            onTap: () {
              // navigate to AddDeviceScreen
              Navigator.of(context).pop();
              Navigator.pushNamed(context, "/add_device");
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.settings_input_component,
            ),
            title: const Text('Cài đặt Thiết bị IoT'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.pushNamed(context, "/iot_setup");
            },
          ),
          const Divider(),
          const ListTile(
            title: Text("Hệ thống"),
          ),
          ListTile(
            leading: const Icon(
              Icons.info,
            ),
            title: const Text('Nhà của tôi'),
            onTap: () {
              // navigate to AddDeviceScreen
              Navigator.of(context).pop();
              Navigator.pushNamedAndRemoveUntil(context, "/", (route) => false);
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.logout_sharp,
            ),
            title: const Text('Đăng xuất'),
            onTap: () {
              // show check for logout
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog.adaptive(
                    title: const Text("Đăng xuất"),
                    content: const Text("Bạn có chắc chắn muốn đăng xuất?"),
                    actions: <Widget>[
                      TextButton(
                        child: const Text("Hủy"),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        child: const Text("Đăng xuất"),
                        onPressed: () {
                          // logout
                          final userRepository = UserRepository();

                          // clear user data and login status
                          userRepository.clearUserData();
                          userRepository.clearLoginStatus();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Đăng xuất thành công!"),
                              backgroundColor: Theme.of(context).primaryColor,
                            ),
                          );
                          // then navigate to login screen
                          Navigator.of(context).pop();
                          Navigator.pushNamedAndRemoveUntil(
                              context, "/login", (route) => false);
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
