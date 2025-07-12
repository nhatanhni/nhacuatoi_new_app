# Nhà Của Tôi - IoT App

Ứng dụng Flutter quản lý thiết bị IoT (Android/iOS)

---

## 🏠 Giới thiệu
- Ứng dụng "Nhà Của Tôi" giúp bạn quản lý, giám sát và cấu hình các thiết bị IoT trong gia đình.
- Hỗ trợ quét QR code để thêm thiết bị, cấu hình WiFi, nhận cảnh báo, thống kê vi phạm, và nhiều tính năng thông minh khác.
- Tương thích Android 15 (SDK 35), iOS 13+, hỗ trợ edge-to-edge, tối ưu hiệu năng và bảo mật.

---

## 🚀 Tính năng chính
- Quản lý danh sách thiết bị IoT, xem chi tiết trạng thái, lịch sử sự kiện.
- Thêm thiết bị mới bằng QR code (scan SSID, cấu hình WiFi tự động).
- Thống kê vi phạm, cảnh báo, báo cáo sự cố.
- Nhận thông báo real-time qua MQTT và local notification.
- Hỗ trợ đa nền tảng: Android, iOS, Web, Desktop.
- Giao diện hiện đại, dễ sử dụng, tối ưu cho cả điện thoại và máy tính bảng.

---

## ⚙️ Hướng dẫn build & chạy

### 1. Cài đặt dependencies
```sh
flutter pub get
```

### 2. Build & chạy trên Android
```sh
flutter run -d <android_device_id>
```
- Build release APK:
```sh
flutter build apk --release
```
- Build AAB cho Google Play:
```sh
flutter build appbundle --release
```

### 3. Build & chạy trên iOS
```sh
flutter run -d <ios_device_id>
```
- Nếu gặp lỗi provisioning, hãy mở `ios/Runner.xcworkspace` bằng Xcode, chọn thiết bị thật và nhấn Run.
- Build release cho TestFlight/App Store:
```sh
flutter build ios --release
```

### 4. Đóng gói & phát hành
- Android: Upload file `.aab` lên Google Play Console.
- iOS: Upload bản release qua Xcode hoặc Transporter lên App Store Connect.

---

## 📝 Lưu ý kỹ thuật
- Đã tối ưu cho Android 15: edge-to-edge, 16KB page size, loại bỏ API lỗi thời.
- Đã khai báo đầy đủ quyền camera, location, notification cho iOS (Info.plist).
- QR scan SSID chỉ hiển thị thông báo 1 lần, tự động ẩn, tránh gây khó chịu.
- Có thể mở rộng thêm module, tích hợp MQTT, REST API, v.v.

---

## 📂 Cấu trúc thư mục
- `lib/` - mã nguồn chính Flutter
- `android/` - cấu hình native Android
- `ios/` - cấu hình native iOS
- `assets/` - hình ảnh, icon
- `database/` - helper SQLite
- `screens/` - các màn hình chính
- `widgets/` - widget tái sử dụng

---

## 📞 Liên hệ & hỗ trợ
- Tác giả: [nhatanhni](https://github.com/nhatanhni)
- Email: [liên hệ qua GitHub]
- Đóng góp, báo lỗi, hoặc đề xuất: tạo issue hoặc pull request trên repo này.

---

Chúc bạn sử dụng app hiệu quả và thành công với các dự án IoT! 🚀
