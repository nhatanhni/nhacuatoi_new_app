# Android 15 Compatibility Updates

## Tổng quan
Ứng dụng đã được cập nhật để tương thích hoàn toàn với Android 15, bao gồm:
1. Edge-to-edge display support
2. Loại bỏ các API lỗi thời
3. Hỗ trợ 16KB page size

## Các thay đổi chính

### 1. Edge-to-Edge Display Support

#### MainActivity.kt
- Thêm `enableEdgeToEdge()` để kích hoạt edge-to-edge display
- Sử dụng `WindowCompat.setDecorFitsSystemWindows(window, false)`
- Cấu hình system bars với modern APIs

#### AndroidManifest.xml
- Thêm `android:enableOnBackInvokedCallback="true"` cho application và activity
- Hỗ trợ Android 15 back navigation

#### styles.xml
- Thêm edge-to-edge support cho cả light và dark themes
- Cấu hình `windowLayoutInDisplayCutoutMode` cho notch support
- Sử dụng transparent colors cho status bar và navigation bar

### 2. Loại bỏ API lỗi thời

#### Flutter Code (main.dart)
- Loại bỏ `statusBarColor`, `systemNavigationBarColor`, `systemNavigationBarDividerColor`
- Sử dụng `SystemUiMode.edgeToEdge` thay vì các API cũ
- Cập nhật `SystemUiOverlayStyle` với các thuộc tính mới

#### Dependencies
- Cập nhật AndroidX libraries lên phiên bản mới nhất
- Thêm `androidx.activity:activity-compose:1.9.0`
- Thêm `androidx.lifecycle:lifecycle-runtime-ktx:2.8.0`

### 3. 16KB Page Size Support

#### build.gradle.kts
- Cấu hình `packagingOptions` với `useLegacyPackaging = false`
- Thêm `nativeLibs` configuration
- Bật `bundle` splits cho language, density, và ABI

#### proguard-rules.pro
- Thêm rules cho Android 15 compatibility
- Tối ưu hóa cho 16KB page size
- Bảo vệ các class cần thiết cho edge-to-edge

## Testing

### Edge-to-Edge Display
1. Chạy ứng dụng trên thiết bị Android 15
2. Kiểm tra xem ứng dụng có hiển thị tràn viền không
3. Kiểm tra system bars có hoạt động đúng không
4. Test trên các thiết bị có notch

### 16KB Page Size
1. Build AAB với cấu hình mới
2. Test trên thiết bị có 16KB page size
3. Kiểm tra performance và stability

### API Compatibility
1. Kiểm tra không có warning về deprecated APIs
2. Verify edge-to-edge behavior hoạt động đúng
3. Test back navigation trên Android 15

## Build Commands

```bash
# Clean và rebuild
flutter clean
flutter pub get

# Build debug
flutter build apk --debug

# Build release AAB
flutter build appbundle --release

# Build cho specific architecture
flutter build apk --release --target-platform android-arm64
```

## Troubleshooting

### Edge-to-Edge không hoạt động
- Kiểm tra `enableEdgeToEdge()` được gọi trước `super.onCreate()`
- Verify `WindowCompat.setDecorFitsSystemWindows(window, false)`
- Kiểm tra styles.xml có cấu hình đúng không

### 16KB Page Size Issues
- Kiểm tra `useLegacyPackaging = false` trong packagingOptions
- Verify proguard rules không conflict
- Test trên thiết bị thật có 16KB page size

### API Deprecation Warnings
- Kiểm tra không sử dụng `setStatusBarColor`, `setNavigationBarColor`
- Verify sử dụng `SystemUiMode.edgeToEdge`
- Kiểm tra Flutter dependencies đã cập nhật

## Notes
- Ứng dụng target SDK 35 (Android 15)
- Sử dụng Java 17
- Hỗ trợ edge-to-edge trên tất cả Android versions từ API 21+
- Tương thích ngược với các thiết bị Android cũ hơn 