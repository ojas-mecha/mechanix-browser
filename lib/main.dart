import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:show_fps/show_fps.dart';

import 'core/routes/app_routes.dart';
import 'core/utils/app_theme.dart';
import 'features/browser/bloc/browser_bloc.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final showFps = Platform.environment['SHOW_FPS'] == 'true';

    return MultiBlocProvider(
      providers: [
        BlocProvider<BrowserBloc>(
          create: (context) => BrowserBloc(),
        ),
      ],
      child: MaterialApp(
        title: 'Mechanix Browser',
        themeMode: ThemeMode.dark,
        darkTheme: AppTheme.dark,
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        initialRoute: AppRoutes.home,
        onGenerateRoute: AppRoutes.onGenerateRoute,
        builder: showFps
            ? (context, child) {
                return ShowFPS(
                  visible: showFps,
                  showChart: false,
                  child: child!,
                );
              }
            : null,
      ),
    );
  }
}
