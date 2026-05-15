import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iot_app/bloc/auth/auth_bloc.dart';
import 'package:iot_app/bloc/auth/auth_state.dart';
class SplashScreen extends StatefulWidget {
	const SplashScreen({super.key});

	@override
	State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
		with SingleTickerProviderStateMixin {
	bool _minDurationPassed = false;
	bool _navigated = false;
	late AnimationController _waveController;

	@override
	void initState() {
		super.initState();
		_waveController = AnimationController(
			duration: const Duration(seconds: 4),
			vsync: this,
		)..repeat();
		_startSplashDelay();
	}

	@override
	void dispose() {
		_waveController.dispose();
		super.dispose();
	}

	void _startSplashDelay() {
		Timer(const Duration(milliseconds: 1600), () {
			if (!mounted) return;
			_minDurationPassed = true;
			_tryNavigate(context.read<AuthBloc>().state);
		});
	}

	void _tryNavigate(AuthState state) {
		if (!_minDurationPassed || _navigated || !mounted) return;

		if (state is AuthAuthenticated) {
			_navigated = true;
			Navigator.of(context).pushReplacementNamed('/home');
			return;
		}

		if (state is AuthUnauthenticated || state is AuthFailure) {
			_navigated = true;
			Navigator.of(context).pushReplacementNamed('/login');
		}
	}

	@override
	Widget build(BuildContext context) {
		return BlocListener<AuthBloc, AuthState>(
			listener: (context, state) => _tryNavigate(state),
			child: AnnotatedRegion<SystemUiOverlayStyle>(
				value: const SystemUiOverlayStyle(
					// Status bar ở vùng trắng → dùng icon tối
					statusBarIconBrightness: Brightness.dark,
					systemNavigationBarIconBrightness: Brightness.dark,
				),
				child: Scaffold(
					backgroundColor: Colors.white,
					body: Stack(
						children: [
							// Layer 1: Base blue – lấp đầy phần dưới, sóng uốn ở TRÊN
							ClipPath(
								clipper: SplashWaveClipper(animValue: 0),
								child: Container(
									width: double.infinity,
									height: double.infinity,
									decoration: const BoxDecoration(
										gradient: LinearGradient(
											begin: Alignment.topLeft,
											end: Alignment.bottomRight,
											colors: [
												Color(0xFF5B80CC),
												Color(0xFF3A5DA0),
											],
										),
									),
								),
							),

							// Layer 2: Animated wave – nhẹ hơn, dao động tạo hiệu ứng sóng
							AnimatedBuilder(
								animation: _waveController,
								builder: (context, _) {
									return ClipPath(
										clipper: SplashWaveClipper(
											animValue: _waveController.value,
											offset: 18,
										),
										child: Container(
											width: double.infinity,
											height: double.infinity,
											decoration: BoxDecoration(
												gradient: LinearGradient(
													begin: Alignment.topLeft,
													end: Alignment.bottomRight,
													colors: [
														const Color(0xFF7B9FEC).withOpacity(0.55),
														const Color(0xFF5070BC).withOpacity(0.35),
													],
												),
											),
										),
									);
								},
							),

							// Blur mềm tại viền sóng (tạo chiều sâu)
							AnimatedBuilder(
								animation: _waveController,
								builder: (context, _) {
									final h = MediaQuery.of(context).size.height;
									final wave = sin(_waveController.value * 2 * pi) * 15;
									return Positioned(
										top: h * 0.22 + wave +20, // đặt khoảng 22% chiều cao + dao động sóng
										left: 0,
										right: 0,
										height: 60,
										child: BackdropFilter(
											filter: ImageFilter.blur(sigmaX: 0, sigmaY: 12),
											child: const SizedBox.expand(),
										),
									);
								},
							),

							// Content
							SafeArea(
								child: Column(
									children: [
										// 2 phần khoảng trắng phía trên (vùng trắng của design)
										const Spacer(flex: 2),

										// Title block – nằm trong vùng xanh
										Padding(
											padding: const EdgeInsets.symmetric(horizontal: 20),
											child: Column(
												mainAxisSize: MainAxisSize.min,
												children: const [
													Text(
														'AIoT Platform',
														textAlign: TextAlign.center,
														style: TextStyle(
															fontSize: 40,
															fontWeight: FontWeight.w700,
															letterSpacing: 4,
															height: 1.25,
															color: Colors.white,
														),
													),
													SizedBox(height: 14),
													Text(
														'Hệ thống quản lý, giám sát & vận hành thiết bị',
														textAlign: TextAlign.center,
														style: TextStyle(
															fontSize: 15,
															fontWeight: FontWeight.w400,
															height: 1.4,
															color: Colors.white,
														),
													),
												],
											),
										),

										const Spacer(flex: 1),

										// Loading row
										Row(
											mainAxisAlignment: MainAxisAlignment.center,
											children: [
												SizedBox(
													width: 20,
													height: 20,
													child: CircularProgressIndicator(
														valueColor: AlwaysStoppedAnimation<Color>(
															Colors.white.withOpacity(0.85),
														),
														strokeWidth: 2,
													),
												),
												const SizedBox(width: 6),
												const Text(
													'Đang tải dữ liệu...',
													style: TextStyle(
														fontSize: 14,
														fontWeight: FontWeight.w400,
														color: Colors.white,
													),
												),
											],
										),

										const Spacer(flex: 1),

										// Home indicator
										Container(
											width: 134,
											height: 5,
											margin: const EdgeInsets.only(bottom: 8),
											decoration: BoxDecoration(
												color: Colors.black,
												borderRadius: BorderRadius.circular(100),
											),
										),
									],
								),
							),
						],
					),
				),
			),
		);
	}
}

/// Vẽ shape lấp đầy phần DƯỚI màn hình với đường sóng uốn ở TRÊN.
class SplashWaveClipper extends CustomClipper<Path> {
	final double animValue;
	final double offset;

	const SplashWaveClipper({this.animValue = 0, this.offset = 0});

	@override
	Path getClip(Size size) {
		final wave = sin(animValue * 2 * pi) * offset;

		final path = Path();

		// Bắt đầu từ góc dưới-trái
		path.moveTo(0, size.height);

		// Left edge ~18%: blue phủ phần lớn bên trái (giống Figma)
		path.lineTo(0, size.height * 0.18 + wave * 0.4);

		// Cubic bezier match Figma:
		// - ctrl1 ở (30%, -5%) → kéo lên mạnh tạo cung lồi (convex bump ~11%) ở x≈20%
		// - ctrl2 ở (65%, 40%) → kéo xuống tạo vũng lõm nadir ~29% ở x≈84%
		// - End ở (100%, 27%) → right edge kết thúc ở ~27%
		path.cubicTo(
			size.width * 0.30, -size.height * 0.05 - wave * 0.5, // ctrl1: lên cao (convex top-left)
			size.width * 0.65,  size.height * 0.40 + wave * 0.3, // ctrl2: xuống sâu (scoop top-right)
			size.width,          size.height * 0.27 + wave * 0.2, // điểm cuối phải ~27%
		);

		// Xuống góc dưới-phải rồi đóng path
		path.lineTo(size.width, size.height);
		path.close();

		return path;
	}

	@override
	bool shouldReclip(SplashWaveClipper oldClipper) {
		return oldClipper.animValue != animValue;
	}
}
