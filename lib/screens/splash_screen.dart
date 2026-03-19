import 'dart:async';

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

class _SplashScreenState extends State<SplashScreen> {
	bool _minDurationPassed = false;
	bool _navigated = false;

	@override
	void initState() {
		super.initState();
		_startSplashDelay();
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
					statusBarIconBrightness: Brightness.dark,
					systemNavigationBarIconBrightness: Brightness.dark,
				),
				child: Scaffold(
					backgroundColor: Colors.white,
					body: LayoutBuilder(
						builder: (context, constraints) {
							final width = constraints.maxWidth;
							final height = constraints.maxHeight;

							return Stack(
								children: [
									Positioned(
										left: -0.843 * width,
										top: 0.065 * height,
										width: 2.08 * width,
										height: 1.01 * height,
										child: IgnorePointer(
											child: Image.asset(
												'assets/images/splash_background.png',
												fit: BoxFit.fill,
											),
										),
									),
									Align(
										alignment: const Alignment(0, -0.03),
										child: SizedBox(
											width: width * 0.75,
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
															height: 1.21,
															color: Colors.white,
														),
													),
												],
											),
										),
									),
								],
							);
						},
					),
				),
			),
		);
	}
}
