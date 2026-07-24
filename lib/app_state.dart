import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/app_user.dart';
import 'data/database_helper.dart';

class AppState extends ChangeNotifier {
  String _language = 'ar';
  AppUser? _currentUser;

  String get language => _language;
  bool get isArabic => _language == 'ar';
  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.role == 'admin';

  Future<void> loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    _language = prefs.getString('language') ?? 'ar';
    final userJson = prefs.getString('current_user');
    if (userJson != null) {
      try {
        final saved = AppUser.fromJson(
          jsonDecode(userJson) as Map<String, dynamic>,
        );
        final current = saved.id == null
            ? null
            : await DatabaseHelper.instance.getUserById(saved.id!);
        if (current == null || !current.isActive) {
          await prefs.remove('current_user');
        } else {
          _currentUser = current;
          await prefs.setString('current_user', jsonEncode(current.toJson()));
        }
      } catch (_) {
        await prefs.remove('current_user');
      }
    }
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    if (_language == lang) return;
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', lang);
    notifyListeners();
  }

  Future<void> setCurrentUser(AppUser user) async {
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user', jsonEncode(user.toJson()));
    notifyListeners();
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
    notifyListeners();
  }
}
