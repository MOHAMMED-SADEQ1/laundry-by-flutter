class AppConstants {
  static const String appName = 'مغاسل النظارة';
  static const String dbName = 'laundry_pos.db';
  static const int dbVersion = 4;

  // Default admin credentials
  static const String defaultAdminUsername = 'admin';
  static const String defaultAdminPassword = 'laundry123456';

  // Invoice counter start
  static const int invoiceCounterStart = 100;

  // Invoice auto-delete after days
  static const int invoiceAutoDeleteDays = 60;

  // Pagination
  static const int defaultPageSize = 12;

  // Loyalty points rate (1 point per X riyals)
  static const int loyaltyPointsRate = 10; // 1 point per 10 riyals

  // Tax rate (VAT)
  static const double taxRate = 0.15; // 15%

  // Shift default start time
  static const String shiftStartTime = 'shift_start_time';

  // SharedPreferences Keys
  static const String spLogin = 'login';
  static const String spUsername = 'username';
  static const String spUserRole = 'user_role';
  static const String spCounterInvoice = 'counterinvoice';
  static const String spShiftActive = 'is_shift_active';
  static const String spActiveShiftId = 'active_shift_id';
  static const String spShiftStartTimeQuery = 'shift_start_time_query';
  static const String spShiftStartTimeDisplay = 'shift_start_time_display';
  static const String spBackupPath = 'backup_path';
  static const String spLastBackup = 'last_backup';
  static const String spDarkMode = 'dark_mode';
  static const String spFontSize = 'font_size';
}
