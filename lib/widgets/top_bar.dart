import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FigmaTopBar extends StatefulWidget implements PreferredSizeWidget {
  final GlobalKey<ScaffoldState>? scaffoldKey;

  const FigmaTopBar({super.key, this.scaffoldKey});

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  State<FigmaTopBar> createState() => _FigmaTopBarState();
}

class _FigmaTopBarState extends State<FigmaTopBar> {
  String _userName = 'Minh Anh';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('userName')?.trim();
    if (!mounted) return;

    setState(() {
      _userName = (savedName == null || savedName.isEmpty)
          ? 'Minh Anh'
          : savedName;
    });
  }

  void _openDrawer() {
    widget.scaffoldKey?.currentState?.openDrawer();
  }

  void _onMenuSelected(String result) {
    switch (result) {
      case 'add_device':
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/add_device',
          (Route<dynamic> route) => false,
        );
        break;
      case 'manage_device':
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/manage_device',
          (Route<dynamic> route) => false,
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF403AB7);

    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 72,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.white,
      backgroundColor: Colors.white,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            IconButton(
              onPressed: _openDrawer,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 24, height: 24),
              icon: const Icon(Icons.menu_rounded, size: 24, color: primaryColor),
              tooltip: 'Mở menu',
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Xin chào, $_userName!',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.27,
                  color: primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            PopupMenuButton<String>(
              onSelected: _onMenuSelected,
              itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'add_device',
                  child: Text('Thêm thiết bị'),
                ),
                PopupMenuItem<String>(
                  value: 'manage_device',
                  child: Text('Quản lý thiết bị'),
                ),
              ],
              child: Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/topbar_avatar.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFE5E7EB),
                      ),
                      child: Icon(Icons.person, size: 28, color: Color(0xFF6B7280)),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
