import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iot_app/bloc/station/station_bloc.dart';
import 'package:iot_app/bloc/station/station_event.dart';
import 'package:iot_app/bloc/station/station_state.dart';
import 'package:iot_app/core/state/station_camera_preferences_provider.dart';
import 'package:iot_app/models/station_from_api.dart';
import 'package:iot_app/widgets/drawer_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class StationCameraScreen extends ConsumerStatefulWidget {
  static const routeName = '/station_cameras';

  const StationCameraScreen({super.key});

  @override
  ConsumerState<StationCameraScreen> createState() =>
      _StationCameraScreenState();
}

class _StationCameraScreenState extends ConsumerState<StationCameraScreen> {
  final TextEditingController _urlController = TextEditingController();
  static const _defaultTestCameraUrl =
      'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';

  @override
  void initState() {
    super.initState();

    final stationState = context.read<StationBloc>().state;
    if (stationState is! StationLoaded) {
      context.read<StationBloc>().add(StationLoadAll());
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _saveManualUrl(StationApi station) async {
    final url = _urlController.text.trim();
    final provider = ref.read(stationCameraUrlsProvider.notifier);

    if (url.isEmpty) {
      await provider.removeUrl(station.id);

      _showMessage('Da xoa URL camera cho ${station.stationName}.');
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      _showMessage('URL khong hop le. Vi du: https://... hoac rtsp://...');
      return;
    }

    await provider.saveUrl(stationId: station.id, url: url);

    _showMessage('Da luu URL camera cho ${station.stationName}.');
  }

  String? _effectiveUrl({
    required StationApi station,
    required Map<String, String> manualCameraUrls,
  }) {
    final manual = manualCameraUrls[station.id]?.trim();
    if (manual != null && manual.isNotEmpty) {
      return manual;
    }

    final fromApi = station.preferredCameraUrl?.trim();
    if (fromApi != null && fromApi.isNotEmpty) {
      return fromApi;
    }

    return null;
  }

  bool _supportsEmbeddedWebView() {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  bool _canEmbed(String url) {
    final uri = Uri.tryParse(url);
    final scheme = uri?.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  Future<void> _openExternally(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showMessage('Không thể mở URL này');
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showMessage('Không mở được camera URL trên thiết bị này');
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final cameraUrlsState = ref.watch(stationCameraUrlsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Giám sát camera'),
        actions: [
          IconButton(
            tooltip: 'Tải lại danh sách trạm',
            onPressed: () => context.read<StationBloc>().add(StationLoadAll()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: BlocBuilder<StationBloc, StationState>(
        builder: (context, state) {
          if (cameraUrlsState.isLoading || state is StationLoading) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (cameraUrlsState.hasError) {
            return _ErrorState(
              message: 'Khong the tai URL camera da luu.',
              onRetry: () {
                ref.invalidate(stationCameraUrlsProvider);
                context.read<StationBloc>().add(StationLoadAll());
              },
            );
          }

          if (state is StationError) {
            return _ErrorState(
              message: state.message,
              onRetry: () => context.read<StationBloc>().add(StationLoadAll()),
            );
          }

          if (state is! StationLoaded || state.stations.isEmpty) {
            return _EmptyState(
              onRetry: () => context.read<StationBloc>().add(StationLoadAll()),
            );
          }

          final stations = state.stations;
          final manualCameraUrls =
              cameraUrlsState.value ?? const <String, String>{};
          final selectedStationId = ref.watch(stationCameraSelectedIdProvider);

          final safeSelectedStationId =
              selectedStationId != null &&
                  stations.any((station) => station.id == selectedStationId)
              ? selectedStationId
              : stations.first.id;

          if (safeSelectedStationId != selectedStationId) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(stationCameraSelectedIdProvider.notifier).state =
                  safeSelectedStationId;
            });
          }

          final selectedStation = stations.firstWhere(
            (station) => station.id == safeSelectedStationId,
            orElse: () => stations.first,
          );

          final selectedUrl =
              _effectiveUrl(
                station: selectedStation,
                manualCameraUrls: manualCameraUrls,
              ) ??
              _defaultTestCameraUrl;

          if (_urlController.text.trim() != selectedUrl.trim()) {
            _urlController.text = selectedUrl;
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final previewHeight = constraints.maxHeight >= 700
                  ? 420.0
                  : constraints.maxHeight * 0.45;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: selectedStation.id,
                      decoration: const InputDecoration(
                        labelText: 'Chọn trạm',
                        border: OutlineInputBorder(),
                      ),
                      selectedItemBuilder: (context) {
                        return stations.map((station) {
                          final label = station.stationCode?.isNotEmpty == true
                              ? '${station.stationName} (${station.stationCode})'
                              : station.stationName;

                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList();
                      },
                      items: stations
                          .map(
                            (station) => DropdownMenuItem<String>(
                              value: station.id,
                              child: SizedBox(
                                width: double.infinity,
                                child: Text(
                                  station.stationCode?.isNotEmpty == true
                                      ? '${station.stationName} (${station.stationCode})'
                                      : station.stationName,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (nextId) {
                        if (nextId == null) {
                          return;
                        }
                        ref
                                .read(stationCameraSelectedIdProvider.notifier)
                                .state =
                            nextId;
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'URL camera của trạm',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _urlController,
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              hintText: 'https://camera-stream...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () => _saveManualUrl(selectedStation),
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('Luu'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _openExternally(selectedUrl),
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Mở camera bên ngoài (nếu cần)'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: previewHeight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Builder(
                            builder: (_) {
                              if (selectedUrl.isEmpty) {
                                return const _CameraPlaceholder(
                                  message:
                                      'Tram nay chua co URL camera. Vui long nhap URL de bat dau giam sat.',
                                );
                              }

                              if (_supportsEmbeddedWebView() &&
                                  _canEmbed(selectedUrl)) {
                                return _CameraWebView(url: selectedUrl);
                              }

                              return _UnsupportedPreview(
                                url: selectedUrl,
                                onOpenExternal: () =>
                                    _openExternally(selectedUrl),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CameraWebView extends StatefulWidget {
  final String url;

  const _CameraWebView({required this.url});

  @override
  State<_CameraWebView> createState() => _CameraWebViewState();
}

class _CameraWebViewState extends State<_CameraWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  void didUpdateWidget(covariant _CameraWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _controller.loadRequest(Uri.parse(widget.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        Positioned(
          top: 8,
          right: 8,
          child: Material(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(30),
            child: IconButton(
              tooltip: 'Tai lai camera',
              onPressed: () => _controller.reload(),
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRetry;

  const _EmptyState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_rounded, size: 42),
            const SizedBox(height: 12),
            const Text(
              'Chưa có trạm nào để giám sát camera',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tải lại'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thu lai'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraPlaceholder extends StatelessWidget {
  final String message;

  const _CameraPlaceholder({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_rounded, color: Colors.white, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnsupportedPreview extends StatelessWidget {
  final String url;
  final VoidCallback onOpenExternal;

  const _UnsupportedPreview({required this.url, required this.onOpenExternal});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.live_tv_rounded, color: Colors.white, size: 48),
            const SizedBox(height: 12),
            const Text(
              'URL camera này không hỗ trợ nhúng trực tiếp trên màn hình này',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              url,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onOpenExternal,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Mở bên ngoài'),
            ),
          ],
        ),
      ),
    );
  }
}
