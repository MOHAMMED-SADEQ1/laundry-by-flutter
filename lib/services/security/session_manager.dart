import 'package:shared_preferences/shared_preferences.dart';
import 'package:laundry/config/constants.dart';

class SessionManager {
  static int? _currentUserId;
  static String? _currentUsername;
  static String? _currentRole;

  static int? get currentUserId => _currentUserId;
  static String? get currentUsername => _currentUsername;
  static String? get currentRole => _currentRole;
  static bool get isAdmin => _currentRole == 'admin';
  static bool get isManager =>
      _currentRole == 'manager' || _currentRole == 'admin';
  static bool get isCashier => _currentRole == 'cashier';

  static Future<void> login(int userId, String username, String role) async {
    _currentUserId = userId;
    _currentUsername = username;
    _currentRole = role;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', userId);
    await prefs.setString(AppConstants.spUsername, username);
    await prefs.setString(AppConstants.spUserRole, role);
    await prefs.setBool(AppConstants.spLogin, true);
  }

  static Future<void> logout() async {
    _currentUserId = null;
    _currentUsername = null;
    _currentRole = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove(AppConstants.spUsername);
    await prefs.remove(AppConstants.spUserRole);
    await prefs.remove(AppConstants.spLogin);
    await prefs.remove(AppConstants.spShiftActive);
    await prefs.remove(AppConstants.spActiveShiftId);
    await prefs.remove(AppConstants.spShiftStartTimeQuery);
    await prefs.remove(AppConstants.spShiftStartTimeDisplay);
  }

  static Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getInt('user_id');
    _currentUsername = prefs.getString(AppConstants.spUsername);
    _currentRole = prefs.getString(AppConstants.spUserRole);
  }

  // Permission checks
  static bool canCreateInvoice() => true; // All users can create invoices
  static bool canDeleteInvoice() => isAdmin || isManager;
  static bool canManageCategories() => isAdmin || isManager;
  static bool canManageCustomers() => isAdmin || isManager;
  static bool canManageInventory() => isAdmin || isManager;
  static bool canManageExpenses() => isAdmin || isManager;
  static bool canViewReports() => isAdmin || isManager;
  static bool canManageEmployees() => isAdmin;
  static bool canManageSettings() => isAdmin;
  static bool canPerformBackup() => isAdmin;
  static bool canManageDiscounts() => isAdmin || isManager;
  static bool canManageShifts() => isAdmin || isManager;
  static bool canDeleteData() => isAdmin;
}
