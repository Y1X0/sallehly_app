import 'package:flutter/material.dart';

import '../features/auth/screens/login_screen.dart';
import '../features/layout/admin_layout.dart';
import '../features/layout/customer_layout.dart';
import '../features/layout/technician_layout.dart';
import '../models/user_model.dart';

class RouteGuard {
  RouteGuard._();

  static Widget homeForUser(UserModel? user) {
    if (user == null) {
      return const LoginScreen();
    }

    if (user.isAdmin) {
      return const AdminLayout();
    }

    if (user.isTechnician) {
      return const TechnicianLayout();
    }

    return const CustomerLayout();
  }
}