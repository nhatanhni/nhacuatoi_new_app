# 📱 Nhà Của Tôi — Hướng Dẫn Dành Cho Developer Mới

> Tài liệu này giúp bạn hiểu nhanh kiến trúc, convention và quy trình làm việc của dự án Flutter IoT **Nhà Của Tôi**.

---

## 📋 Mục lục

1. [Tổng quan kiến trúc](#1-tổng-quan-kiến-trúc)
2. [Cấu trúc thư mục](#2-cấu-trúc-thư-mục)
3. [BLoC là gì và tại sao dùng?](#3-bloc-là-gì-và-tại-sao-dùng)
4. [Cách BLoC được tổ chức trong dự án](#4-cách-bloc-được-tổ-chức-trong-dự-án)
5. [Singleton MQTT Manager](#5-singleton-mqtt-manager)
6. [Cấu hình môi trường (.env)](#6-cấu-hình-môi-trường-env)
7. [Convention đặt tên](#7-convention-đặt-tên)
8. [Luồng dữ liệu từ đầu đến cuối](#8-luồng-dữ-liệu-từ-đầu-đến-cuối)
9. [Hướng dẫn thêm tính năng mới](#9-hướng-dẫn-thêm-tính-năng-mới)
10. [Chiến lược Hybrid BLoC + Riverpod](#10-chiến-lược-hybrid-bloc--riverpod)
11. [Các lỗi thường gặp](#11-các-lỗi-thường-gặp)

---

## 1. Tổng quan kiến trúc

Dự án sử dụng kiến trúc **BLoC (Business Logic Component)** kết hợp với **Repository Pattern**:

```
UI (Screens/Widgets)
        │  add Event / listen State
        ▼
    BLoC Layer          ← Toàn bộ business logic ở đây
        │  gọi phương thức
        ▼
  Repository Layer      ← Giao tiếp API, MQTT, Database
        │
   ┌────┴────┐
   ▼         ▼
 API      MQTT / SQLite
```

**Nguyên tắc cốt lõi:**
- **Screen/Widget không chứa business logic** — chỉ hiển thị UI và gửi event.
- **BLoC không biết về UI** — chỉ nhận event, xử lý, emit state.
- **Repository** là lớp trung gian duy nhất được phép gọi network/database.

---

## 2. Cấu trúc thư mục

```
lib/
├── bloc/                    # ← BLoC: toàn bộ business logic
│   ├── auth/
│   │   ├── auth_bloc.dart
│   │   ├── auth_event.dart
│   │   └── auth_state.dart
│   ├── device/
│   │   ├── device_bloc.dart
│   │   ├── device_event.dart
│   │   └── device_state.dart
│   └── mqtt/
│       ├── mqtt_bloc.dart
│       ├── mqtt_event.dart
│       └── mqtt_state.dart
│
├── core/
│   └── config/
│       └── app_config.dart  # ← Đọc biến môi trường từ .env
│
├── database/
│   └── database_helper.dart # ← SQLite local database
│
├── models/                  # ← Data models (POCO classes)
│   ├── device.dart
│   └── switch_event.dart
│
├── repository/              # ← Giao tiếp với server/MQTT
│   ├── api_service.dart
│   ├── mqtt_manager.dart    # ← Singleton MQTT connection
│   ├── user_repository.dart
│   └── scheduler_repository.dart
│
├── screens/                 # ← UI: mỗi màn hình 1 file
│   ├── home_screen.dart
│   ├── login_screen.dart
│   ├── device_list_screen.dart
│   ├── device_detail_screen.dart
│   └── ...
│
├── widgets/                 # ← Widget tái sử dụng
│   ├── drawer_widget.dart
│   ├── notification_service.dart
│   └── ...
│
├── utils/                   # ← Helper functions
│   └── toast_helper.dart
│
└── main.dart                # ← Entry point, setup MultiBlocProvider
```

---

## 3. BLoC là gì và tại sao dùng?

### Khái niệm cơ bản

BLoC (**B**usiness **Lo**gic **C**omponent) là pattern quản lý state dựa trên luồng **Event → BLoC → State**:

```
          add(Event)           emit(State)
  Widget ──────────► BLoC ─────────────► Widget rebuild
```

| Thành phần | Vai trò | Ví dụ trong dự án |
|---|---|---|
| **Event** | Hành động người dùng / trigger | `AuthLoginRequested`, `DeviceLoadAll` |
| **BLoC** | Xử lý event, gọi repository, emit state | `AuthBloc`, `DeviceBloc` |
| **State** | Trạng thái UI cần render | `AuthAuthenticated`, `DeviceLoaded` |

### Tại sao dùng BLoC?

- **Tách biệt hoàn toàn** UI và logic → dễ test, dễ maintain.
- **Dễ debug**: mọi thay đổi state đều có thể trace qua event.
- **Tái sử dụng** BLoC ở nhiều màn hình khác nhau.
- **Predictable**: cùng event luôn cho cùng kết quả.

---

## 4. Cách BLoC được tổ chức trong dự án

### 4.1 Cấu trúc 3 file cho 1 BLoC

Mỗi BLoC gồm đúng **3 file**:

```
auth_event.dart   → Định nghĩa các Event (input)
auth_state.dart   → Định nghĩa các State (output)
auth_bloc.dart    → Xử lý logic: event → state
```

### 4.2 Event — định nghĩa hành động

```dart
// lib/bloc/auth/auth_event.dart
abstract class AuthEvent extends Equatable {
  const AuthEvent();
}

// Mỗi hành động là 1 class riêng
class AuthLoginRequested extends AuthEvent {
  final String username;
  final String password;

  const AuthLoginRequested({required this.username, required this.password});

  @override
  List<Object?> get props => [username, password];
}

class AuthLogoutRequested extends AuthEvent {}
```

> **Convention:** Tên event dùng dạng `<Tên BLoC><Hành động>` — ví dụ: `AuthLoginRequested`, `DeviceLoadAll`.

### 4.3 State — định nghĩa trạng thái

```dart
// lib/bloc/auth/auth_state.dart
abstract class AuthState extends Equatable {
  const AuthState();
}

class AuthInitial extends AuthState {}        // Khởi tạo
class AuthLoading extends AuthState {}        // Đang xử lý
class AuthAuthenticated extends AuthState {}  // Đã đăng nhập
class AuthUnauthenticated extends AuthState {}
class AuthFailure extends AuthState {
  final String message;
  const AuthFailure(this.message);
  @override
  List<Object?> get props => [message];
}
```

> **Convention:** Tên state dùng dạng `<Tên BLoC><Trạng thái>` — ví dụ: `AuthLoading`, `DeviceLoaded`, `MqttConnected`.

### 4.4 BLoC — xử lý logic

```dart
// lib/bloc/auth/auth_bloc.dart
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final ApiService apiService;
  final UserRepository userRepository;

  AuthBloc({required this.apiService, required this.userRepository})
      : super(AuthInitial()) {
    on<AuthLoginRequested>(_onLoginRequested);  // Đăng ký handler
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());   // 1. Báo đang xử lý
    try {
      final data = await apiService.login(event.username, event.password);
      await userRepository.saveUserData(data['Data']);
      emit(AuthAuthenticated());  // 2. Thành công
    } catch (e) {
      emit(AuthFailure(e.toString()));  // 3. Thất bại
    }
  }
}
```

### 4.5 Dùng BLoC trong Screen

```dart
// Gửi Event vào BLoC
context.read<AuthBloc>().add(AuthLoginRequested(
  username: _usernameController.text,
  password: _passwordController.text,
));

// Lắng nghe State để điều hướng / hiển thị toast
BlocListener<AuthBloc, AuthState>(
  listener: (context, state) {
    if (state is AuthAuthenticated) {
      Navigator.pushNamed(context, '/home');
    } else if (state is AuthFailure) {
      showDialog(...);
    }
  },
  child: ...,
)

// Rebuild UI theo State
BlocBuilder<DeviceBloc, DeviceState>(
  builder: (context, state) {
    if (state is DeviceLoading) return CircularProgressIndicator();
    if (state is DeviceLoaded) return ListView(...);
    if (state is DeviceError) return Text(state.message);
    return Container();
  },
)
```

### 4.6 Setup BLoC ở gốc app (main.dart)

Tất cả BLoC được khởi tạo 1 lần duy nhất trong `MultiBlocProvider` ở `main.dart`:

```dart
return MultiBlocProvider(
  providers: [
    BlocProvider<AuthBloc>(
      create: (_) => AuthBloc(
        apiService: apiService,
        userRepository: userRepository,
      )..add(AuthCheckRequested()),  // Tự động kiểm tra đăng nhập khi khởi động
    ),
    BlocProvider<DeviceBloc>(
      create: (_) => DeviceBloc(databaseHelper: databaseHelper),
    ),
    BlocProvider<MqttBloc>(
      create: (_) => MqttBloc(
        mqttManager: mqttManager,
        notificationService: notificationService,
      )..add(MqttConnectRequested()),  // Tự kết nối MQTT khi khởi động
    ),
  ],
  child: MaterialApp(...),
);
```

> **Lưu ý quan trọng:** Không tạo BLoC mới trong từng screen. Luôn dùng `context.read<XxxBloc>()` để truy cập BLoC đã được provide từ trên.

---

## 5. Singleton MQTT Manager

MQTT connection được quản lý tập trung qua **MQTTManager.instance** — toàn bộ app dùng chung 1 connection duy nhất.

### Cách dùng

```dart
// Lấy instance (không tạo mới)
final manager = MQTTManager.instance;

// Đảm bảo đã kết nối trước khi dùng
await manager.ensureConnected();

// Subscribe topic
manager.subscribe('NhaCuaToi_ABC123_status');

// Publish message
await manager.publish('NhaCuaToi_ABC123_control', '{"cmd":"on"}');

// Nghe message stream
manager.messageStream.listen((msg) {
  // xử lý message
});
```

### Quy tắc QUAN TRỌNG

| ✅ Nên làm | ❌ Không làm |
|---|---|
| Dùng `MQTTManager.instance` | Tạo `MQTTManager()` mới trong từng screen |
| Gọi `ensureConnected()` trước khi subscribe/publish | Gọi trực tiếp `connect()` trong screen |
| Subscribe/Unsubscribe trong BLoC | Gọi MQTT trực tiếp trong widget build |
| Để `MqttBloc` xử lý toàn bộ MQTT logic | Dispose MQTT trong screen |

### Cấu trúc Topic MQTT

```
NhaCuaToi_{deviceSerial}_status  → Nhận trạng thái thiết bị (online/offline)
NhaCuaToi_{deviceSerial}_alarm   → Nhận cảnh báo
NhaCuaToi_{deviceSerial}_control → Gửi lệnh điều khiển
```

---

## 6. Cấu hình môi trường (.env)

Mọi giá trị nhạy cảm (URL, credentials) đều được lưu trong file `.env` ở root project và **không được commit lên git**.

### File `.env` (tạo thủ công, không commit)

```env
API_BASE_URL=https://your-api.com
MQTT_SERVER=your-mqtt-server.com
MQTT_PORT=8004
MQTT_USERNAME=your_username
MQTT_PASSWORD=your_password
PRIVACY_POLICY_URL=https://your-policy-url.com
```

### Truy cập config trong code

```dart
// ❌ Sai: hardcode trực tiếp
final url = 'https://nhacuatoi.com.vn';

// ✅ Đúng: qua AppConfig
import 'package:iot_app/core/config/app_config.dart';

final url = AppConfig.apiBaseUrl;
final mqttServer = AppConfig.mqttServer;
```

> **Thêm biến mới:** Thêm vào `.env` → thêm getter vào `AppConfig` → dùng qua `AppConfig.newValue`.

---

## 7. Convention đặt tên

### Files

| Loại | Convention | Ví dụ |
|---|---|---|
| Screen | `snake_case_screen.dart` | `device_list_screen.dart` |
| Widget | `snake_case_widget.dart` | `drawer_widget.dart` |
| BLoC | `snake_case_bloc/event/state.dart` | `auth_bloc.dart` |
| Model | `snake_case.dart` | `device.dart` |
| Repository | `snake_case_repository/service.dart` | `api_service.dart` |

### Classes

| Loại | Convention | Ví dụ |
|---|---|---|
| BLoC class | `PascalCaseBloc` | `AuthBloc` |
| Event | `PascalCaseBlocActionVerb` | `AuthLoginRequested` |
| State | `PascalCaseBlocStateNoun` | `AuthAuthenticated` |
| Screen | `PascalCaseScreen` | `DeviceListScreen` |
| Widget | `PascalCaseWidget` | `AppDrawer` |
| Model | `PascalCase` | `Device` |

### Route names (trong main.dart)

```dart
'/login'         → LoginScreen
'/'              → HomeScreen
'/device_list'   → DeviceListScreen
'/add_device'    → AddDeviceScreen
```

---

## 8. Luồng dữ liệu từ đầu đến cuối

### Ví dụ: Người dùng nhấn Đăng nhập

```
1. LoginScreen
   └─ _login() gọi:
      context.read<AuthBloc>().add(AuthLoginRequested(...))

2. AuthBloc._onLoginRequested()
   ├─ emit(AuthLoading())             → UI hiển thị loading spinner
   ├─ await apiService.login(...)     → Gọi REST API
   ├─ await userRepository.save(...)  → Lưu token vào SharedPreferences
   └─ emit(AuthAuthenticated())       → UI điều hướng đến HomeScreen

3. LoginScreen (BlocListener)
   └─ state is AuthAuthenticated
      └─ Navigator.pushNamed(context, '/home')
```

### Ví dụ: Nhận cảnh báo từ MQTT

```
1. MQTTManager (Singleton)
   └─ messageStream phát ra message mới

2. MqttBloc._listenToMessages()
   └─ add(MqttMessageReceived(topic, message))

3. MqttBloc._onMessageReceived()
   ├─ Decode JSON
   ├─ notificationService.showNotification(...)  → Hiển thị push notification
   └─ emit(MqttMessageState(topic, message))     → Cập nhật UI nếu cần
```

---

## 9. Hướng dẫn thêm tính năng mới

### Ví dụ: Thêm tính năng "Xem lịch sử sử dụng nước"

#### Bước 1: Thêm model (nếu cần)

```dart
// lib/models/water_history.dart
class WaterHistory {
  final DateTime timestamp;
  final double liters;
  // ...
}
```

#### Bước 2: Thêm method vào Repository

```dart
// lib/repository/api_service.dart
Future<List<WaterHistory>> fetchWaterHistory(String serial) async {
  final token = await _getToken();
  final response = await http.get(
    Uri.parse('${AppConfig.apiBaseUrl}/api/Water/History/$serial'),
    headers: {'Authorization': 'Bearer $token'},
  );
  // ...
}
```

#### Bước 3: Tạo BLoC

```dart
// lib/bloc/water/water_event.dart
class WaterHistoryLoadRequested extends WaterEvent {
  final String serial;
  const WaterHistoryLoadRequested(this.serial);
}

// lib/bloc/water/water_state.dart
class WaterHistoryLoaded extends WaterState {
  final List<WaterHistory> history;
  const WaterHistoryLoaded(this.history);
}

// lib/bloc/water/water_bloc.dart
class WaterBloc extends Bloc<WaterEvent, WaterState> {
  WaterBloc({required this.apiService}) : super(WaterInitial()) {
    on<WaterHistoryLoadRequested>(_onHistoryLoadRequested);
  }
  // ...
}
```

#### Bước 4: Đăng ký BLoC vào MultiBlocProvider (main.dart)

```dart
BlocProvider<WaterBloc>(
  create: (_) => WaterBloc(apiService: apiService),
),
```

#### Bước 5: Tạo Screen và dùng BLoC

```dart
// lib/screens/water_history_screen.dart
BlocBuilder<WaterBloc, WaterState>(
  builder: (context, state) {
    if (state is WaterHistoryLoaded) {
      return ListView.builder(...);
    }
    return CircularProgressIndicator();
  },
)
```

#### Bước 6: Thêm route (main.dart)

```dart
'/water_history': (context) => WaterHistoryScreen(),
```

---

## 10. Chiến lược Hybrid BLoC + Riverpod

Từ phiên bản hiện tại, dự án áp dụng mô hình **hybrid state management**:
- **BLoC** cho luồng nghiệp vụ có side-effect (API, MQTT, DB, flow nhiều bước).
- **Riverpod** cho state global nhẹ, state UI chia sẻ và state local có persistence đơn giản.

### 10.1 Quy tắc chọn công cụ

| Trường hợp | Nên dùng | Lý do |
|---|---|---|
| Gọi API, retry, pagination, error mapping | BLoC | Event/state rõ ràng, dễ trace và test flow |
| MQTT stream, subscribe/unsubscribe, background handling | BLoC | Có lifecycle và side-effect phức tạp |
| Global UI state (tab index, filter, sort, toggle) | Riverpod | Nhẹ, ít ceremony, dễ dùng xuyên màn hình |
| Key-value persistence đơn giản (SharedPreferences) | Riverpod Notifier/AsyncNotifier | Tách logic lưu/đọc khỏi widget, tránh setState rải rác |

### 10.2 Rule bắt buộc khi dùng hybrid

- Không thay thế BLoC hiện có nếu feature đang ổn định và liên quan API/MQTT.
- Không gọi API trực tiếp từ Riverpod provider trong app này (giữ API tập trung qua Repository + BLoC).
- Widget không đọc `SharedPreferences` trực tiếp; ưu tiên đi qua Riverpod notifier/repository để tái sử dụng.
- Khi state cần chia sẻ giữa nhiều màn, đặt provider dưới `lib/core/state/`.

### 10.3 Cấu trúc đã thêm

```text
lib/
  core/
    state/
      app_shell_provider.dart
      station_camera_preferences_provider.dart
```

- `app_shell_provider.dart`: global state cho tab index của main shell.
- `station_camera_preferences_provider.dart`: quản lý URL camera theo station (load/save/remove qua SharedPreferences).

### 10.4 Bootstrap Riverpod

App được bọc `ProviderScope` ở `main.dart`, sau đó vẫn giữ nguyên `MultiBlocProvider` cho các luồng nghiệp vụ hiện tại.

```dart
runApp(const ProviderScope(child: MyApp(initialRoute: '/')));
```

### 10.5 Ví dụ chuẩn trong dự án

- `MainShell`: dùng Riverpod cho tab index (global UI state).
- `StationCameraScreen`: vẫn dùng `StationBloc` để load danh sách trạm, nhưng dùng Riverpod để quản lý camera URL preferences và selected station.

Mẫu phối hợp đúng:

```dart
final cameraUrlsState = ref.watch(stationCameraUrlsProvider);

body: BlocBuilder<StationBloc, StationState>(
  builder: (context, state) {
    // BLoC: data từ API
    // Riverpod: state nhẹ + persistence
  },
)
```

### 10.6 Checklist khi thêm feature mới

1. Feature có API/MQTT/DB hoặc flow nhiều bước? => Tạo/đổi BLoC.
2. Feature chỉ là state UI chia sẻ hoặc key-value nhẹ? => Tạo Riverpod provider.
3. Nếu feature có cả hai: dùng BLoC cho business data, Riverpod cho presentation state.
4. Viết test theo đúng lớp: bloc test cho luồng nghiệp vụ, provider test cho state nhẹ.

---

## 11. Các lỗi thường gặp

### `Could not find the correct Provider<XxxBloc>`

**Nguyên nhân:** Dùng BLoC nhưng chưa provide ở trên cây widget.

**Cách sửa:** Đảm bảo BLoC đã được khai báo trong `MultiBlocProvider` ở `main.dart`, hoặc wrap widget với `BlocProvider` cục bộ.

---

### `MqttPublishMessage is imported from both...`

**Nguyên nhân:** Trùng tên class giữa `mqtt_client` và custom event của project.

**Cách sửa:** Dùng import alias:
```dart
import 'package:mqtt_client/mqtt_client.dart' as mqtt;
// Sau đó dùng: mqtt.MqttPublishMessage
```

---

### `compileSdk` conflicts với plugin

**Nguyên nhân:** Một số plugin (fluttertoast, shared_preferences_android) yêu cầu compileSdk cao hơn.

**Cách sửa:** Tăng `compileSdk` trong `android/app/build.gradle.kts`:
```kotlin
android {
    compileSdk = 36  // Luôn dùng version cao nhất mà plugin yêu cầu
}
```

---

### MQTT không nhận được message

**Checklist:**
1. Đã gọi `await manager.ensureConnected()` chưa?
2. Topic có đúng format `NhaCuaToi_{serial}_status` không?
3. Kiểm tra `MQTT_SERVER`, `MQTT_PORT`, `MQTT_USERNAME`, `MQTT_PASSWORD` trong `.env`.
4. Xem log: `flutter run` sẽ in `MQTT Connected` khi kết nối thành công.

---

### State không cập nhật sau khi emit

**Nguyên nhân thường gặp:** Emit state giống hệt state hiện tại — BLoC bỏ qua nếu state không thay đổi.

**Cách sửa:** Đảm bảo class State implement `Equatable` đúng cách, hoặc luôn emit state mới (không reuse cùng object).

---

## 📚 Tài liệu tham khảo

- [flutter_bloc documentation](https://bloclibrary.dev)
- [BLoC pattern concepts](https://bloclibrary.dev/architecture/)
- [MQTT Client for Flutter](https://pub.dev/packages/mqtt_client)
- [flutter_dotenv](https://pub.dev/packages/flutter_dotenv)
