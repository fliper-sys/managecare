import 'package:cloud_firestore/cloud_firestore.dart';

/// Receipt customization model for Pro users
/// Stores business-specific receipt templates and settings
class ReceiptSettingsModel {
  final String id;
  final String businessId;

  // Header customization
  final String? headerLogo; // URL to uploaded business logo/photo
  final String? headerNote; // Custom header message

  // Receipt details display options
  final bool showOrderId;
  final bool showCustomerName;
  final bool showCustomerPhone;
  final bool showDate;
  final bool showTime;
  final bool showPaymentMethod;
  final bool showCashier;

  // Footer customization
  final String? footerMessage; // Custom footer/thank you message
  final String? bankAccountNo;
  final String? bankName;
  final String? address;
  final String? phone;
  final String? website;
  final String? taxId;

  // Restaurant-specific fields
  final bool showTableNo;
  final bool showNumberOfPersons;
  final bool showWaiterName;

  // Invoice options (for retail/drinks large orders)
  final bool enableInvoices;
  final String invoicePrefix; // e.g., "INV-"
  final int nextInvoiceNumber;

  // Subscription receipt styling
  final String subscriptionHeaderColor; // Hex color
  final bool highlightSubscriptionReceipts;

  // Style presets
  final String stylePreset; // 'minimal' | 'professional' | 'colorful'
  final String? accentColor; // Hex like '#2C3E50'

  // Printing options
  final int paperWidth; // 58mm, 80mm for thermal printers
  final bool autoConnectBluetooth;
  final String? defaultPrinterMac;

  // Email options
  final bool enableEmailReceipts;
  final String? emailTemplateId;
  final String? dunningTriggerUrl;

  // General options
  final bool showQrCode; // QR code linking to order details
  final String? receiptUrlBase; // Base URL for generating QR code links (e.g., https://example.com/receipt)
  final String receiptTemplateType; // 'simple', 'detailed', 'invoice'

  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>?
      additionalPreferences; // For thermal printer customizations

  ReceiptSettingsModel({
    required this.id,
    required this.businessId,
    this.headerLogo,
    this.headerNote,
    this.showOrderId = true,
    this.showCustomerName = false,
    this.showCustomerPhone = false,
    this.showDate = true,
    this.showTime = true,
    this.showPaymentMethod = true,
    this.showCashier = false,
    this.footerMessage,
    this.bankAccountNo,
    this.bankName,
    this.address,
    this.phone,
    this.website,
    this.taxId,
    this.showTableNo = false,
    this.showNumberOfPersons = false,
    this.showWaiterName = false,
    this.enableInvoices = false,
    this.invoicePrefix = 'INV-',
    this.nextInvoiceNumber = 1000,
    this.subscriptionHeaderColor = '#2196F3',
    this.highlightSubscriptionReceipts = true,
    this.stylePreset = 'professional',
    this.accentColor = '#2C3E50',
    this.paperWidth = 58,
    this.autoConnectBluetooth = false,
    this.defaultPrinterMac,
    this.enableEmailReceipts = true,
    this.emailTemplateId,
    this.dunningTriggerUrl,
    this.showQrCode = false,
    this.receiptUrlBase,
    this.receiptTemplateType = 'simple',
    required this.createdAt,
    required this.updatedAt,
    this.additionalPreferences,
});

  // Factory for creating default settings
  factory ReceiptSettingsModel.defaultSettings({required String businessId}) {
    final now = DateTime.now();
    return ReceiptSettingsModel(
      id: businessId,
      businessId: businessId,
      paperWidth: 58,
      stylePreset: 'professional',
      accentColor: '#2C3E50',
      createdAt: now,
      updatedAt: now,
    );
  }

  

  // Firestore serialization
  factory ReceiptSettingsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReceiptSettingsModel(
      id: doc.id,
      businessId: data['businessId'] ?? '',
      headerLogo: data['headerLogo'],
      headerNote: data['headerNote'],
      showOrderId: data['showOrderId'] ?? true,
      showCustomerName: data['showCustomerName'] ?? false,
      showCustomerPhone: data['showCustomerPhone'] ?? false,
      showDate: data['showDate'] ?? true,
      showTime: data['showTime'] ?? true,
      showPaymentMethod: data['showPaymentMethod'] ?? true,
      showCashier: data['showCashier'] ?? false,
      footerMessage: data['footerMessage'],
      bankAccountNo: data['bankAccountNo'],
      bankName: data['bankName'],
      address: data['address'],
      phone: data['phone'],
      website: data['website'],
      taxId: data['taxId'],
      showTableNo: data['showTableNo'] ?? false,
      showNumberOfPersons: data['showNumberOfPersons'] ?? false,
      showWaiterName: data['showWaiterName'] ?? false,
      enableInvoices: data['enableInvoices'] ?? false,
      invoicePrefix: data['invoicePrefix'] ?? 'INV-',
      nextInvoiceNumber: data['nextInvoiceNumber'] ?? 1000,
      subscriptionHeaderColor: data['subscriptionHeaderColor'] ?? '#2196F3',
      highlightSubscriptionReceipts:
          data['highlightSubscriptionReceipts'] ?? true,
      paperWidth: data['paperWidth'] ?? 58,
      autoConnectBluetooth: data['autoConnectBluetooth'] ?? false,
      defaultPrinterMac: data['defaultPrinterMac'],
      enableEmailReceipts: data['enableEmailReceipts'] ?? true,
      emailTemplateId: data['emailTemplateId'],
      dunningTriggerUrl: data['dunningTriggerUrl'],
      showQrCode: data['showQrCode'] ?? false,
      receiptUrlBase: data['receiptUrlBase'],
      receiptTemplateType: data['receiptTemplateType'] ?? 'simple',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      additionalPreferences:
          data['additionalPreferences'] as Map<String, dynamic>?,
  );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'businessId': businessId,
      'headerLogo': headerLogo,
      'headerNote': headerNote,
      'showOrderId': showOrderId,
      'showCustomerName': showCustomerName,
      'showCustomerPhone': showCustomerPhone,
      'showDate': showDate,
      'showTime': showTime,
      'showPaymentMethod': showPaymentMethod,
      'showCashier': showCashier,
      'footerMessage': footerMessage,
      'bankAccountNo': bankAccountNo,
      'bankName': bankName,
      'address': address,
      'phone': phone,
      'website': website,
      'taxId': taxId,
      'showTableNo': showTableNo,
      'showNumberOfPersons': showNumberOfPersons,
      'showWaiterName': showWaiterName,
      'enableInvoices': enableInvoices,
      'invoicePrefix': invoicePrefix,
      'nextInvoiceNumber': nextInvoiceNumber,
      'subscriptionHeaderColor': subscriptionHeaderColor,
      'highlightSubscriptionReceipts': highlightSubscriptionReceipts,
      'paperWidth': paperWidth,
      'autoConnectBluetooth': autoConnectBluetooth,
      'defaultPrinterMac': defaultPrinterMac,
      'enableEmailReceipts': enableEmailReceipts,
      'emailTemplateId': emailTemplateId,
      'dunningTriggerUrl': dunningTriggerUrl,
      'showQrCode': showQrCode,
      'receiptUrlBase': receiptUrlBase,
      'receiptTemplateType': receiptTemplateType,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (additionalPreferences != null)
        'additionalPreferences': additionalPreferences,
    };
  }

  ReceiptSettingsModel copyWith({
    String? id,
    String? businessId,
    String? headerLogo,
    String? headerNote,
    bool? showOrderId,
    bool? showCustomerName,
    bool? showCustomerPhone,
    bool? showDate,
    bool? showTime,
    bool? showPaymentMethod,
    bool? showCashier,
    String? footerMessage,
    String? bankAccountNo,
    String? bankName,
    String? address,
    String? phone,
    String? website,
    String? taxId,
    bool? showTableNo,
    bool? showNumberOfPersons,
    bool? showWaiterName,
    bool? enableInvoices,
    String? invoicePrefix,
    int? nextInvoiceNumber,
    String? subscriptionHeaderColor,
    bool? highlightSubscriptionReceipts,
    int? paperWidth,
    bool? autoConnectBluetooth,
    String? defaultPrinterMac,
    bool? enableEmailReceipts,
    String? emailTemplateId,
    String? dunningTriggerUrl,
    bool? showQrCode,
    String? receiptUrlBase,
    String? receiptTemplateType,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? additionalPreferences,
  }) {
    return ReceiptSettingsModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      headerLogo: headerLogo ?? this.headerLogo,
      headerNote: headerNote ?? this.headerNote,
      showOrderId: showOrderId ?? this.showOrderId,
      showCustomerName: showCustomerName ?? this.showCustomerName,
      showCustomerPhone: showCustomerPhone ?? this.showCustomerPhone,
      showDate: showDate ?? this.showDate,
      showTime: showTime ?? this.showTime,
      showPaymentMethod: showPaymentMethod ?? this.showPaymentMethod,
      showCashier: showCashier ?? this.showCashier,
      footerMessage: footerMessage ?? this.footerMessage,
      bankAccountNo: bankAccountNo ?? this.bankAccountNo,
      bankName: bankName ?? this.bankName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      taxId: taxId ?? this.taxId,
      showTableNo: showTableNo ?? this.showTableNo,
      showNumberOfPersons: showNumberOfPersons ?? this.showNumberOfPersons,
      showWaiterName: showWaiterName ?? this.showWaiterName,
      enableInvoices: enableInvoices ?? this.enableInvoices,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      nextInvoiceNumber: nextInvoiceNumber ?? this.nextInvoiceNumber,
      subscriptionHeaderColor:
          subscriptionHeaderColor ?? this.subscriptionHeaderColor,
      highlightSubscriptionReceipts:
          highlightSubscriptionReceipts ?? this.highlightSubscriptionReceipts,
      stylePreset: stylePreset,
      accentColor: accentColor ?? this.accentColor,
      paperWidth: paperWidth ?? this.paperWidth,
      autoConnectBluetooth: autoConnectBluetooth ?? this.autoConnectBluetooth,
      defaultPrinterMac: defaultPrinterMac ?? this.defaultPrinterMac,
      enableEmailReceipts: enableEmailReceipts ?? this.enableEmailReceipts,
      emailTemplateId: emailTemplateId ?? this.emailTemplateId,
      dunningTriggerUrl: dunningTriggerUrl ?? this.dunningTriggerUrl,
      showQrCode: showQrCode ?? this.showQrCode,
      receiptUrlBase: receiptUrlBase ?? this.receiptUrlBase,
      receiptTemplateType: receiptTemplateType ?? this.receiptTemplateType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      additionalPreferences:
          additionalPreferences ?? this.additionalPreferences,
    );
  }
}

