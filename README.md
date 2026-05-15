# 🏠 Nhà Của Tôi — IoT App

> **Flutter mobile application** quản lý, giám sát và điều khiển thiết bị IoT thông minh trong gia đình.

- **Package name:** `vn.acstech.nhacuatoi`
- **Flutter SDK:** `>=3.8.1 <4.0.0`
- **Version:** `2.1.0+18`
- **Platform:** Android 15 (SDK 35), iOS 13+

---

## 📋 Mục lục

1. [Tính năng chính](#tính-năng-chính)
2. [Kiến trúc](#kiến-trúc)
3. [Cấu trúc thư mục](#cấu-trúc-thư-mục)
4. [Màn hình & Chức năng](#màn-hình--chức-năng)
5. [Core Layer](#core-layer)
6. [Dependencies](#dependencies)
7. [Hướng dẫn build](#hướng-dẫn-build)

---

## ✨ Tính năng chính

| Nhóm | Tính năng |
|---|---|
| **Xác thực** | Đăng nhập, Đăng ký tài khoản |
| **Thiết bị** | Xem danh sách, thêm/xóa/quản lý thiết bị IoT |
| **Giám sát** | Xem chi tiết trạng thái thiết bị real-time qua MQTT |
| **Lịch hẹn** | Cài đặt lịch bật/tắt tự động cho thiết bị |
| **Trạm bơm** | Quản lý, điều khiển, lịch sử máy bơm & cổng phai |
| **Cảnh báo** | Nhận thông báo local notification khi có alarm từ thiết bị |
| **WiFi Setup** | Quét QR code, cấu hình WiFi cho thiết bị mới |
| **Quản lý user** | Xem và xóa người dùng (admin) |
| **Báo cáo** | Thống kê vi phạm ngưỡng cảm biến |

---

## 🏛️ Kiến trúc

Project áp dụng kiến trúc **2-File Screen-Based** với nguyên tắc:

```
Mỗi màn hình = 1 thư mục gồm:
  ├── *_screen.dart   → StatefulWidget: UI + setState() quản lý state
  └── *_service.dart  → Tầng logic: gọi API, DB, MQTT
```

**Quy tắc:**
- **Không dùng Provider / BLoC** — state quản lý trực tiếp bằng `setState()`
- Logic dùng chung → đưa vào `lib/core/`
- Màn hình con (popup, sub-screen) → thư mục con của màn hình cha
- Kết nối MQTT khởi tạo tại `main.dart`, chia sẻ qua tham số constructor

---

## 📁 Cấu trúc thư mục

```
nhacuatoi_new_app/
├── lib/
│   ├── main.dart                          ← Entry point, routing, MQTT init, notification
│   │
│   ├── core/                              ← Tầng dùng chung toàn app
│   │   ├── models/                        ← Data classes
│   │   │   ├── device.dart                ← Device, SubDevice, WaterLevelSensor,
│   │   │   │                                 PumpStationDevice, PumpStatus, GateStatus,
│   │   │   │                                 PumpHistory, GateHistory, WastewaterMonitoringData
│   │   │   ├── switch_event.dart          ← SwitchEvent (log bật/tắt thiết bị)
│   │   │   └── violation_report.dart      ← ViolationReport (báo cáo vi phạm ngưỡng)
│   │   │
│   │   ├── services/                      ← Services dùng chung
│   │   │   ├── api_service.dart           ← HTTP client: login, signUp, getUserInfo, fetchWaterMeterData
│   │   │   ├── user_repository.dart       ← SharedPreferences: lưu/đọc thông tin user & trạng thái login
│   │   │   ├── database_helper.dart       ← SQLite (sqflite): CRUD thiết bị, lịch sử, sub-device, relay
│   │   │   ├── web_database_helper.dart   ← Web stub thay thế SQLite trên Flutter Web
│   │   │   ├── mqtt_manager.dart          ← MQTT client: kết nối, subscribe, publish, stream message
│   │   │   └── scheduler_repository.dart  ← HTTP: CRUD lịch hẹn qua REST API
│   │   │
│   │   ├── theme/                         ← Design system
│   │   │   ├── app_colors.dart            ← Màu sắc toàn app (primary, background, error, text…)
│   │   │   └── app_styles.dart            ← Typography, spacing, radius constants (AppStyles)
│   │   │
│   │   ├── utils/                         ← Tiện ích
│   │   │   ├── toast_helper.dart          ← Hiển thị toast message (fluttertoast)
│   │   │   ├── qr_code_helper.dart        ← Xử lý QR code data (parse SSID, password)
│   │   │   ├── permission_helper.dart     ← Xin quyền camera, location, WiFi
│   │   │   ├── credentials.dart           ← Hằng số credentials mặc định
│   │   │   └── web_stubs.dart             ← Stub các API không có trên Web
│   │   │
│   │   └── widgets/                       ← Shared UI components
│   │       ├── appbar_back_to_home_widget.dart      ← AppBar với nút back về Home
│   │       ├── appbar_dropdown_widget.dart           ← AppBar với dropdown menu
│   │       ├── custom_auth_text_field.dart           ← TextField cho màn hình xác thực
│   │       ├── custom_button_widget.dart             ← Nút bấm tái sử dụng
│   │       ├── custom_primary_button.dart            ← Nút primary (login, register…)
│   │       ├── device_alarm_widget.dart              ← Widget hiển thị cảnh báo thiết bị
│   │       ├── device_detail_button_widget.dart      ← Nút điều khiển trong màn hình chi tiết
│   │       ├── device_sensor_reading_widget.dart     ← Hiển thị chỉ số cảm biến
│   │       ├── drawer_widget.dart                    ← Navigation drawer toàn app
│   │       ├── duration_picker_widget.dart           ← Picker chọn thời lượng (phút/giây)
│   │       ├── notification_service.dart             ← Khởi tạo & hiển thị local notification
│   │       ├── placeholder_box_widget.dart           ← Shimmer loading placeholder
│   │       ├── schedule_tag_widget.dart              ← Tag hiển thị thông tin lịch hẹn
│   │       └── sensor_readings_card_widget.dart      ← Card tổng hợp chỉ số cảm biến
│   │
│   ├── scheduler/
│   │   └── scheduler.dart                 ← Background alarm manager (Android)
│   │
│   └── screens/                           ← Các màn hình (2-file pattern)
│       │
│       ├── splash/
│       │   └── splash_screen.dart         ← Màn hình khởi động, kiểm tra login → điều hướng
│       │
│       ├── login/
│       │   ├── login_screen.dart          ← UI đăng nhập
│       │   └── login_service.dart         ← Gọi ApiService.login(), lưu token
│       │
│       ├── register/
│       │   ├── register_screen.dart       ← UI đăng ký tài khoản
│       │   └── register_service.dart      ← Gọi ApiService.signUp()
│       │
│       ├── home/
│       │   ├── home_screen.dart           ← Dashboard: danh sách thiết bị, MQTT status, drawer
│       │   └── home_service.dart          ← Lấy user data, load danh sách thiết bị từ DB
│       │
│       ├── user_list/
│       │   ├── user_list_screen.dart      ← Danh sách user (admin), xóa user
│       │   └── user_list_service.dart     ← Lấy token, gọi ApiService.deleteUserById()
│       │
│       ├── wifi_setup/
│       │   └── wifi_setup_screen.dart     ← Quét QR code → parse SSID/password → kết nối WiFi
│       │                                     → gửi cấu hình đến thiết bị qua HTTP
│       │
│       ├── device_list/
│       │   ├── device_list_screen.dart    ← Danh sách thiết bị, filter theo loại, MQTT status
│       │   ├── device_list_service.dart   ← Query DB, fetchWaterMeterData
│       │   │
│       │   ├── add_device/
│       │   │   ├── add_device_screen.dart    ← Form thêm thiết bị mới (tên, serial, loại…)
│       │   │   └── add_device_service.dart   ← Lưu thiết bị vào SQLite
│       │   │
│       │   ├── manage_device/
│       │   │   ├── manage_device_screen.dart    ← Xem & xóa thiết bị đã lưu
│       │   │   └── manage_device_service.dart   ← Query & delete từ SQLite
│       │   │
│       │   └── device_detail/
│       │       ├── device_detail_screen.dart    ← Chi tiết thiết bị: trạng thái real-time,
│       │       │                                   biểu đồ, điều khiển bật/tắt qua MQTT,
│       │       │                                   lịch sử sự kiện, vi phạm ngưỡng
│       │       ├── device_detail_service.dart   ← fetchWaterMeterData từ API
│       │       │
│       │       └── device_scheduling/
│       │           ├── device_scheduling_screen.dart   ← UI đặt lịch hẹn bật/tắt tự động
│       │           └── device_scheduling_service.dart  ← CRUD lịch qua SchedulerRepository
│       │
│       └── pump_station/
│           ├── pump_station_screen.dart        ← Giám sát trạm bơm: trạng thái máy bơm,
│           │                                     cổng phai, mực nước, điều khiển qua MQTT
│           ├── pump_station_service.dart        ← fetchWaterMeterData từ API
│           │
│           └── pump_station_management/
│               ├── pump_station_management_screen.dart   ← Cấu hình sub-devices (bơm, cổng,
│               │                                            cảm biến mực nước), quản lý relay
│               └── pump_station_management_service.dart  ← fetchWaterMeterData từ API
│
├── assets/
│   └── images/                            ← Hình ảnh, icon
├── icons/
│   └── app_logo.jpg                       ← Icon ứng dụng
├── .env                                   ← Biến môi trường (MQTT host, API base URL…)
├── pubspec.yaml
└── README.md
```

---

## 📱 Màn hình & Chức năng

### 1. 💫 Splash Screen
- Kiểm tra trạng thái đăng nhập từ `SharedPreferences`
- Điều hướng tự động: → `LoginScreen` hoặc → `HomeScreen`

### 2. 🔐 Login Screen
- Form nhập username / password
- Gọi API xác thực → lưu `accessToken` & thông tin user
- Điều hướng đến `HomeScreen` khi thành công

### 3. 📝 Register Screen
- Form đăng ký: username, password, email, phone
- Validate client-side trước khi gửi API
- Link tới trang Terms & Conditions qua `url_launcher`

### 4. 🏠 Home Screen
- Dashboard chính của app
- Hiển thị danh sách thiết bị từ SQLite local DB
- Nhận MQTT message real-time, cập nhật trạng thái kết nối
- Navigation Drawer: truy cập các tính năng, đăng xuất
- Điều hướng tới `DeviceDetailScreen` hoặc `PumpStationScreen` theo loại thiết bị

### 5. 📋 Device List Screen
- Danh sách toàn bộ thiết bị đã lưu
- Filter theo loại thiết bị (IoT, Pump Station, Water Meter…)
- Hiển thị trạng thái kết nối (Online/Offline) qua MQTT

### 6. ➕ Add Device Screen
- Form thêm thiết bị mới: Tên, Serial number, Loại thiết bị, Ngưỡng cảm biến
- Lưu vào SQLite local database

### 7. 🗑️ Manage Device Screen
- Danh sách thiết bị với slide-to-delete
- Xóa thiết bị khỏi local DB

### 8. 🔍 Device Detail Screen *(màn hình phức tạp nhất)*
- Real-time data từ MQTT (subscribe topic `NhaCuaToi_{serial}`)
- Biểu đồ chỉ số cảm biến (fl_chart)
- Đồng hồ đo (syncfusion_flutter_gauges)
- Điều khiển bật/tắt relay qua MQTT publish
- Lịch sử sự kiện bật/tắt
- Danh sách cảnh báo vi phạm ngưỡng
- Điều hướng đến `DeviceSchedulingScreen`

### 9. ⏰ Device Scheduling Screen
- Xem danh sách lịch hẹn của thiết bị
- Tạo / sửa / xóa lịch hẹn qua REST API (`scheduler_repository`)
- Chọn thời gian, thời lượng, lặp lại hàng ngày

### 10. 🚰 Pump Station Screen
- Giám sát trạm bơm tổng hợp
- Trạng thái từng máy bơm (Pump 1, 2, 3…): đang chạy / dừng / lỗi
- Trạng thái cổng phai (Gate): mở / đóng
- Mực nước sensor (WaterLevelSensor)
- Lịch sử bơm & cổng
- Điều hướng đến `PumpStationManagementScreen`

### 11. ⚙️ Pump Station Management Screen
- Cấu hình sub-devices: số lượng bơm, cổng, cảm biến mực nước
- Thiết lập serial và tên cho từng sub-device
- Quản lý trạng thái relay trong SQLite

### 12. 📡 WiFi Setup Screen
- Quét QR code bằng camera để đọc SSID & password
- Xin quyền camera và location runtime
- Kết nối WiFi tự động qua `wifi_iot` / `plugin_wifi_connect`
- Gửi cấu hình đến thiết bị qua HTTP local

### 13. 👥 User List Screen *(Admin only)*
- Danh sách toàn bộ người dùng
- Xóa người dùng qua API (cần `accessToken`)

---

## 🧱 Core Layer

### Models

| Class | Mô tả |
|---|---|
| `Device` | Thiết bị IoT chính: serial, name, type, status, connection, schedule info |
| `SubDevice` | Thiết bị con (máy bơm, cổng phai) thuộc một Device cha |
| `WaterLevelSensor` | Cảm biến mực nước: waterLevel, maxCapacity, min/maxThreshold |
| `PumpStationDevice` | Cấu hình trạm bơm: danh sách SubDevice & WaterLevelSensor |
| `PumpStatus` | Trạng thái máy bơm: isRunning, hasWater, timestamp |
| `GateStatus` | Trạng thái cổng phai: isOpen, timestamp |
| `PumpHistory` | Lịch sử hoạt động máy bơm |
| `GateHistory` | Lịch sử hoạt động cổng phai |
| `WastewaterMonitoringData` | Dữ liệu quan trắc nước thải từ API |
| `SwitchEvent` | Sự kiện bật/tắt thiết bị (timestamp, isSwitched) |
| `ViolationReport` | Báo cáo vi phạm: deviceSerial, parameterName, violationValue, thresholdValue |

### Services

| Service | Mô tả |
|---|---|
| `ApiService` | HTTP client tới backend `nhacuatoi.com.vn:3000`: login, signUp, getUserInfo, fetchWaterMeterData, deleteUserById |
| `UserRepository` | SharedPreferences wrapper: lưu/đọc/xóa token, username, trạng thái login |
| `DatabaseHelper` | SQLite singleton (sqflite): quản lý 8 bảng — smart_device, switchEvents, violation_reports, pump_history, gate_history, sub_devices, water_level_sensors, relay_states |
| `MQTTManager` | MQTT client (mqtt_client): connect/disconnect, subscribe/unsubscribe, publish, Stream<MqttReceivedMessage> |
| `SchedulerRepository` | REST API CRUD lịch hẹn: getSchedules, getScheduleBySerial, createSchedule, updateSchedule, deleteSchedule |
| `WebDatabaseHelper` | Stub thay thế DatabaseHelper trên Flutter Web (localStorage) |

### Database Schema (SQLite v10)

| Bảng | Mục đích |
|---|---|
| `smart_device` | Danh sách thiết bị IoT đã lưu cục bộ |
| `switchEvents` | Lịch sử sự kiện bật/tắt từng thiết bị |
| `violation_reports` | Báo cáo vi phạm ngưỡng cảm biến |
| `pump_history` | Lịch sử hoạt động máy bơm |
| `gate_history` | Lịch sử hoạt động cổng phai |
| `sub_devices` | Thiết bị con (bơm, cổng) của trạm bơm |
| `water_level_sensors` | Cảm biến mực nước |
| `relay_states` | Trạng thái relay của từng sub-device |

---

## 📦 Dependencies

| Package | Phiên bản | Mục đích |
|---|---|---|
| `sqflite` | ^2.3.3 | SQLite local database |
| `mqtt_client` | ^10.2.0 | MQTT protocol client |
| `http` | ^1.2.1 | HTTP REST API calls |
| `shared_preferences` | ^2.2.2 | Lưu trữ token, cài đặt |
| `flutter_dotenv` | ^5.1.0 | Load biến môi trường từ `.env` |
| `flutter_local_notifications` | ^19.3.0 | Local push notification |
| `workmanager` | ^0.8.0 | Background task (Android) |
| `android_alarm_manager_plus` | ^4.0.4 | Background scheduler (Android) |
| `fl_chart` | ^0.69.0 | Biểu đồ dữ liệu cảm biến |
| `syncfusion_flutter_gauges` | ^30.1.38 | Đồng hồ đo (gauge widget) |
| `flutter_slidable` | ^4.0.0 | Slide-to-delete cho list items |
| `shimmer` | ^3.0.0 | Loading skeleton animation |
| `fluttertoast` | ^9.0.0 | Toast messages |
| `intl` | ^0.20.2 | Format ngày giờ, số |
| `url_launcher` | ^6.0.20 | Mở link external |
| `wifi_scan` | ^0.4.0 | Quét danh sách WiFi |
| `wifi_iot` | ^0.3.18 | Kết nối WiFi programmatically |
| `plugin_wifi_connect` | ^2.0.1 | Kết nối WiFi (iOS support) |
| `numberpicker` | ^2.1.2 | Picker số cho duration |

---

## ⚙️ Hướng dẫn build

### 1. Cài đặt dependencies
```sh
flutter pub get
```

### 2. Cấu hình môi trường
Tạo file `.env` ở root project:
```env
MQTT_HOST=your_mqtt_broker_host
MQTT_PORT=1883
API_BASE_URL=http://nhacuatoi.com.vn:3000
```

### 3. Chạy development
```sh
flutter run
```

### 4. Build iOS (không codesign)
```sh
flutter build ios --no-codesign
```

### 5. Build Android
```sh
flutter build apk --release
# hoặc
flutter build appbundle --release
```

### 6. Phân tích lỗi
```sh
flutter analyze
```

---

## 🔗 Routing

Routing được định nghĩa trong `lib/main.dart`:

| Route | Screen |
|---|---|
| `/` | `SplashScreen` |
| `/login` | `LoginScreen` |
| `/register` | `RegisterScreen` |
| `/home` | `HomeScreen` |
| `/device_list` | `DeviceListScreen` |
| `/add_device` | `AddDeviceScreen` |
| `/manage_device` | `ManageDeviceScreen` |
| `/user_list` | `UserListScreen` |
| `DeviceDetailScreen.routeName` | `DeviceDetailScreen` (nhận `Device` argument) |
| `DeviceSchedulingScreen.routeName` | `DeviceSchedulingScreen` (nhận `Device` argument) |
| `/pump_station` | `PumpStationScreen` (nhận `Device` argument) |

---

## 📐 Quy ước phát triển

- **State management:** `setState()` — không dùng Provider, BLoC, Riverpod
- **Thêm màn hình mới:** Tạo thư mục `lib/screens/{tên_màn_hình}/` với 2 file `_screen.dart` + `_service.dart`
- **Logic dùng chung:** Đặt vào `lib/core/services/` hoặc `lib/core/utils/`
- **Widget tái sử dụng:** Đặt vào `lib/core/widgets/`
- **Import:** Luôn dùng `package:iot_app/...` (tuyệt đối), không dùng `../` (tương đối)
- **MQTT topics:** Format `NhaCuaToi_{serial}` cho data, `NhaCuaToi_{serial}_alarm` cho alarm
