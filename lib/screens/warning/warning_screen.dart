import 'package:flutter/material.dart';

class WarningScreen extends StatefulWidget {
  const WarningScreen({Key? key}) : super(key: key);

  @override
  State<WarningScreen> createState() => _WarningScreenState();
}

class _WarningScreenState extends State<WarningScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Custom Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 50, // Added padding for status bar
              left: 20,
              right: 20,
              bottom: 20,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF28356A), // Dark blue
                  Color(0xFF8B9DC9), // Light blue
                ],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(0),
                bottomRight: Radius.circular(0),
              )
            ),
            child: Column(
              children: [
                // Search Bar
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Tìm thiết bị...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                      prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Chips
                Row(
                  children: [
                    _buildTopChip(Icons.tune, 'Lọc'),
                    const SizedBox(width: 12),
                    _buildTopChip(Icons.swap_vert, 'Mới nhất'),
                  ],
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: Container(
              color: Colors.white,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildGroupHeader('ĐƠN VỊ A — TRẠM QUAN TRẮC NƯỚC'),
                  const SizedBox(height: 16),
                  _buildWarningCard(
                    code: 'MD01',
                    level: 'Mức độ 1',
                    time: '14:30:25',
                    date: '02/04/2026',
                    icon: Icons.thermostat,
                    title: 'Nhiệt độ cao · Nhiệt độ',
                    assigneeInitials: 'NA',
                    assigneeName: 'Nguyễn Văn A',
                    status: 'Đang xử lý',
                    severityColor: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  _buildWarningCard(
                    code: 'MD01',
                    level: 'Mức độ 1',
                    time: '14:30:25',
                    date: '02/04/2026',
                    icon: Icons.thermostat,
                    title: 'Nhiệt độ cao · Nhiệt độ',
                    assigneeInitials: 'NA',
                    assigneeName: 'Nguyễn Văn A',
                    status: 'Đang xử lý',
                    severityColor: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  _buildWarningCard(
                    code: 'MD02',
                    level: 'Mức độ 2',
                    time: '14:30:25',
                    date: '02/04/2026',
                    icon: Icons.water_drop_outlined,
                    title: 'Độ ẩm vượt ngưỡng · Độ ẩm',
                    assigneeInitials: null,
                    assigneeName: null,
                    status: 'Chưa xử lý',
                    severityColor: Colors.orange.shade400,
                  ),
                  const SizedBox(height: 16),
                  _buildWarningCard(
                    code: 'MD02',
                    level: 'Mức độ 2',
                    time: '14:30:25',
                    date: '02/04/2026',
                    icon: Icons.water_drop_outlined,
                    title: 'Độ ẩm vượt ngưỡng · Độ ẩm',
                    assigneeInitials: null,
                    assigneeName: null,
                    status: 'Chưa xử lý',
                    severityColor: Colors.orange.shade400,
                  ),
                  const SizedBox(height: 16),
                  _buildWarningCard(
                    code: 'MD03',
                    level: 'Mức độ 3',
                    time: '14:30:25',
                    date: '02/04/2026',
                    icon: Icons.show_chart,
                    title: 'COD vượt ngưỡng · COD',
                    assigneeInitials: null,
                    assigneeName: null,
                    status: 'Chưa xử lý',
                    severityColor: Colors.amber.shade500,
                  ),
                  const SizedBox(height: 24),
                  // Xem thêm button
                  Center(
                    child: TextButton(
                      onPressed: () {},
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Xem thêm 10 cảnh báo',
                            style: TextStyle(
                              color: Colors.blue.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.blue.shade600,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.black87),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupHeader(String title) {
    return Row(
      children: [
        const Icon(Icons.business, color: Colors.grey, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildWarningCard({
    required String code,
    required String level,
    required String time,
    required String date,
    required IconData icon,
    required String title,
    String? assigneeInitials,
    String? assigneeName,
    required String status,
    required Color severityColor,
  }) {
    Color darkTextColor = Colors.brown.shade700;
    if (severityColor == Colors.red.shade400) darkTextColor = Colors.red.shade900;
    if (severityColor == Colors.orange.shade400) darkTextColor = Colors.deepOrange.shade900;
    if (severityColor == Colors.amber.shade500) darkTextColor = Colors.brown.shade800;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: severityColor.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: severityColor.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Tags and Time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: severityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      code,
                      style: TextStyle(
                        color: darkTextColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: severityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      level,
                      style: TextStyle(
                        color: darkTextColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      color: severityColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    date,
                    style: TextStyle(
                      color: severityColor.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Middle Row: Title
          Row(
            children: [
              Icon(icon, color: severityColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: severityColor,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Bottom Row: Assignee and Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Assignee
              Row(
                children: [
                  if (assigneeInitials != null)
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        assigneeInitials,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    Icon(Icons.person_outline, color: Colors.grey.shade400, size: 24),
                  
                  const SizedBox(width: 8),
                  Text(
                    assigneeName ?? 'Chưa phân công',
                    style: TextStyle(
                      color: assigneeName != null ? Colors.grey.shade800 : Colors.grey.shade500,
                      fontSize: 13,
                      fontStyle: assigneeName != null ? FontStyle.normal : FontStyle.italic,
                    ),
                  ),
                ],
              ),
              // Status
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: status == 'Đang xử lý' ? severityColor : Colors.grey.shade400,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: status == 'Đang xử lý' ? severityColor : Colors.grey.shade400,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          status,
                          style: TextStyle(
                            color: status == 'Đang xử lý' ? severityColor : Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
