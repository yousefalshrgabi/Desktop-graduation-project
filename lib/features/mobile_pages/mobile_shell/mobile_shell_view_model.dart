import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:academic_affairs_management/features/authentiction/login_view_model.dart';

class MobileShellViewModel extends ChangeNotifier {
  final AppSession _session = AppSession();
  final LoginViewModel _loginViewModel = LoginViewModel();

  int _currentIndex = 0;

  int get currentIndex => _currentIndex;
  AppSession get session => _session;
  LoginViewModel get loginViewModel => _loginViewModel;

  String get roleDisplayName => _session.roleDisplayName;
  String get userName => _session.userName;
  List<String> get extraRoleKeys => _session.extraRoleKeys;

  void changeTab(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  String roleKeyToLabel(String roleKey) => _session.roleKeyToLabel(roleKey);

  /// تسجيل الخروج: يرجع [true] عند النجاح، [false] عند الفشل مع رسالة خطأ في [loginViewModel.errorMessage]
  Future<bool> logout() async {
    return await _loginViewModel.logout();
  }

  String get logoutErrorMessage => _loginViewModel.errorMessage;
}
