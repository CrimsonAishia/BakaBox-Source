import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'package:flutter_portal/flutter_portal.dart';

import 'screens/web_server_list_page.dart';
import 'theme/web_theme.dart';

/// Web 端应用入口
class WebApp extends StatelessWidget {
  const WebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Portal(
      child: MaterialApp(
        title: 'BakaBox Web',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
        theme: WebTheme.lightTheme,
        darkTheme: WebTheme.darkTheme,
        home: const WebServerListPage(),
      ),
    );
  }
}
