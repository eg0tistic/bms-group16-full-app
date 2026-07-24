class AppConstants {
  static const String storeNameKey = 'store_name';
  static const String storeAddressKey = 'store_address';
  static const String storePhoneKey = 'store_phone';
  static const String taxIdKey = 'tax_id';
  static const String commercialRegistrationKey = 'commercial_registration';
  static const String vatEnabledKey = 'vat_enabled';
  static const String vatRateKey = 'vat_rate';
  static const String languageKey = 'language';
  static const String lastSyncedKey = 'last_synced_at';
  static const String supabaseUrlKey = 'supabase_url';
  static const String supabaseAnonKey = 'supabase_anon_key';

  static const double defaultVatRate = 0.17;
  static const String defaultLanguage = 'ar';
  static const String defaultStoreName = 'متجري';

  static const List<String> paymentMethods = [
    'Cash',
    'Bankak',
    'Bede',
    'Cashi',
    'Bank Transfer',
    'Hawala',
  ];

  static const List<String> invoiceStatuses = [
    'Draft',
    'Confirmed',
    'Paid',
    'Voided',
    'Closed',
  ];
}
