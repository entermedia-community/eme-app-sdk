import 'package:flutter/material.dart';

class AppConfig {
  final String appTitle;
  final ThemeData? lightTheme;
  final ThemeData? darkTheme;

  const AppConfig({
    required this.appTitle,
    this.lightTheme,
    this.darkTheme,
  });
}
