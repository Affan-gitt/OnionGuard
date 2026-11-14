import '../../core/constants/app_constants.dart';

class AppSettings {
  final String bleDeviceName;
  final String bleServiceUuid;

  final double targetTemp;
  final double triggerTemp;
  final double resetTemp;
  final double targetHumidity;
  final double maxHumiditySafety;
  final int mq3Baseline;
  final double mq3TriggerDeltaPercent;

  // Mathematical Modelling Weights (sum to 1.0)
  final double weightTemp;
  final double weightHumidity;
  final double weightGas;
  final double weightVentilation;

  // Developer & Simulation Mode
  final String developerPin;
  final bool isSimulationActive;
  final String simulationScenario;
  final double simulationSpeed;

  // Notifications & Alert Gateway
  final bool notificationsEnabled;
  final bool whatsappEnabled;
  final String whatsappProvider; // "ntfy.sh (Free Push Receiver)", "CallMeBot (Free WhatsApp)", "Direct WhatsApp App", "Custom Webhook", "Phone SIM (Direct SMS)", "Simulation Only"
  final String whatsappPhoneNumber;
  final String whatsappApiKey;
  final String whatsappCustomWebhookUrl;
  final String ntfyTopic;
  final int alertCooldownMinutes;

  // Inbound Sensor API Receiver
  final bool inboundApiEnabled;
  final int inboundApiPort;

  // Backward compatibility getters
  bool get smsEnabled => whatsappEnabled;
  String get smsProvider => whatsappProvider;
  String get alertPhoneNumber => whatsappPhoneNumber;
  String get fast2SmsApiKey => whatsappApiKey;

  // Connection & Cloud Sync
  final String backendMode; // "LOCAL_OFFLINE" (default) or "SUPABASE"
  final String supabaseUrl;
  final String supabaseAnonKey;

  AppSettings({
    this.bleDeviceName = 'OnionGuard-ESP32H2',
    this.bleServiceUuid = AppConstants.bleServiceUuid,
    this.targetTemp = AppConstants.defaultTargetTemp,
    this.triggerTemp = AppConstants.defaultTriggerTemp,
    this.resetTemp = AppConstants.defaultResetTemp,
    this.targetHumidity = AppConstants.defaultTargetHumidity,
    this.maxHumiditySafety = AppConstants.defaultMaxHumiditySafety,
    this.mq3Baseline = AppConstants.defaultMq3Baseline,
    this.mq3TriggerDeltaPercent = AppConstants.defaultMq3TriggerDeltaPercent,
    this.weightTemp = 0.35,
    this.weightHumidity = 0.30,
    this.weightGas = 0.20,
    this.weightVentilation = 0.15,
    this.developerPin = AppConstants.defaultDeveloperPin,
    this.isSimulationActive = false,
    this.simulationScenario = 'Normal Storage',
    this.simulationSpeed = 1.0,
    this.notificationsEnabled = true,
    this.whatsappEnabled = true,
    this.whatsappProvider = 'Circuit Digest Cloud WhatsApp API',
    this.whatsappPhoneNumber = '',
    this.whatsappApiKey = 'cd_muh_131126_sIj6nj',
    this.whatsappCustomWebhookUrl = '',
    this.ntfyTopic = 'onionguard_storage_alerts',
    this.alertCooldownMinutes = 15,
    this.inboundApiEnabled = true,
    this.inboundApiPort = 8088,
    this.backendMode = 'LOCAL_OFFLINE',
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
  });

  AppSettings copyWith({
    String? bleDeviceName,
    String? bleServiceUuid,
    double? targetTemp,
    double? triggerTemp,
    double? resetTemp,
    double? targetHumidity,
    double? maxHumiditySafety,
    int? mq3Baseline,
    double? mq3TriggerDeltaPercent,
    double? weightTemp,
    double? weightHumidity,
    double? weightGas,
    double? weightVentilation,
    String? developerPin,
    bool? isSimulationActive,
    String? simulationScenario,
    double? simulationSpeed,
    bool? notificationsEnabled,
    bool? whatsappEnabled,
    String? whatsappProvider,
    String? whatsappPhoneNumber,
    String? whatsappApiKey,
    String? whatsappCustomWebhookUrl,
    String? ntfyTopic,
    int? alertCooldownMinutes,
    bool? inboundApiEnabled,
    int? inboundApiPort,
    // Deprecated compatibility parameters
    bool? smsEnabled,
    String? smsProvider,
    String? alertPhoneNumber,
    String? fast2SmsApiKey,
    String? backendMode,
    String? supabaseUrl,
    String? supabaseAnonKey,
  }) {
    return AppSettings(
      bleDeviceName: bleDeviceName ?? this.bleDeviceName,
      bleServiceUuid: bleServiceUuid ?? this.bleServiceUuid,
      targetTemp: targetTemp ?? this.targetTemp,
      triggerTemp: triggerTemp ?? this.triggerTemp,
      resetTemp: resetTemp ?? this.resetTemp,
      targetHumidity: targetHumidity ?? this.targetHumidity,
      maxHumiditySafety: maxHumiditySafety ?? this.maxHumiditySafety,
      mq3Baseline: mq3Baseline ?? this.mq3Baseline,
      mq3TriggerDeltaPercent: mq3TriggerDeltaPercent ?? this.mq3TriggerDeltaPercent,
      weightTemp: weightTemp ?? this.weightTemp,
      weightHumidity: weightHumidity ?? this.weightHumidity,
      weightGas: weightGas ?? this.weightGas,
      weightVentilation: weightVentilation ?? this.weightVentilation,
      developerPin: developerPin ?? this.developerPin,
      isSimulationActive: isSimulationActive ?? this.isSimulationActive,
      simulationScenario: simulationScenario ?? this.simulationScenario,
      simulationSpeed: simulationSpeed ?? this.simulationSpeed,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      whatsappEnabled: whatsappEnabled ?? smsEnabled ?? this.whatsappEnabled,
      whatsappProvider: whatsappProvider ?? smsProvider ?? this.whatsappProvider,
      whatsappPhoneNumber: whatsappPhoneNumber ?? alertPhoneNumber ?? this.whatsappPhoneNumber,
      whatsappApiKey: whatsappApiKey ?? fast2SmsApiKey ?? this.whatsappApiKey,
      whatsappCustomWebhookUrl: whatsappCustomWebhookUrl ?? this.whatsappCustomWebhookUrl,
      ntfyTopic: ntfyTopic ?? this.ntfyTopic,
      alertCooldownMinutes: alertCooldownMinutes ?? this.alertCooldownMinutes,
      inboundApiEnabled: inboundApiEnabled ?? this.inboundApiEnabled,
      inboundApiPort: inboundApiPort ?? this.inboundApiPort,
      backendMode: backendMode ?? this.backendMode,
      supabaseUrl: supabaseUrl ?? this.supabaseUrl,
      supabaseAnonKey: supabaseAnonKey ?? this.supabaseAnonKey,
    );
  }

  Map<String, dynamic> toJson() => {
    'bleDeviceName': bleDeviceName,
    'bleServiceUuid': bleServiceUuid,
    'targetTemp': targetTemp,
    'triggerTemp': triggerTemp,
    'resetTemp': resetTemp,
    'targetHumidity': targetHumidity,
    'maxHumiditySafety': maxHumiditySafety,
    'mq3Baseline': mq3Baseline,
    'mq3TriggerDeltaPercent': mq3TriggerDeltaPercent,
    'weightTemp': weightTemp,
    'weightHumidity': weightHumidity,
    'weightGas': weightGas,
    'weightVentilation': weightVentilation,
    'developerPin': developerPin,
    'isSimulationActive': isSimulationActive,
    'simulationScenario': simulationScenario,
    'simulationSpeed': simulationSpeed,
    'notificationsEnabled': notificationsEnabled,
    'whatsappEnabled': whatsappEnabled,
    'whatsappProvider': whatsappProvider,
    'whatsappPhoneNumber': whatsappPhoneNumber,
    'whatsappApiKey': whatsappApiKey,
    'whatsappCustomWebhookUrl': whatsappCustomWebhookUrl,
    'ntfyTopic': ntfyTopic,
    'alertCooldownMinutes': alertCooldownMinutes,
    'inboundApiEnabled': inboundApiEnabled,
    'inboundApiPort': inboundApiPort,
    // Deprecated keys for compatibility
    'smsEnabled': whatsappEnabled,
    'smsProvider': whatsappProvider,
    'alertPhoneNumber': whatsappPhoneNumber,
    'fast2SmsApiKey': whatsappApiKey,
    'backendMode': backendMode,
    'supabaseUrl': supabaseUrl,
    'supabaseAnonKey': supabaseAnonKey,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    bleDeviceName: json['bleDeviceName'] as String? ?? 'OnionGuard-ESP32H2',
    bleServiceUuid: json['bleServiceUuid'] as String? ?? AppConstants.bleServiceUuid,
    targetTemp: (json['targetTemp'] as num?)?.toDouble() ?? AppConstants.defaultTargetTemp,
    triggerTemp: (json['triggerTemp'] as num?)?.toDouble() ?? AppConstants.defaultTriggerTemp,
    resetTemp: (json['resetTemp'] as num?)?.toDouble() ?? AppConstants.defaultResetTemp,
    targetHumidity: (json['targetHumidity'] as num?)?.toDouble() ?? AppConstants.defaultTargetHumidity,
    maxHumiditySafety: (json['maxHumiditySafety'] as num?)?.toDouble() ?? AppConstants.defaultMaxHumiditySafety,
    mq3Baseline: json['mq3Baseline'] as int? ?? AppConstants.defaultMq3Baseline,
    mq3TriggerDeltaPercent: (json['mq3TriggerDeltaPercent'] as num?)?.toDouble() ?? AppConstants.defaultMq3TriggerDeltaPercent,
    weightTemp: (json['weightTemp'] as num?)?.toDouble() ?? 0.35,
    weightHumidity: (json['weightHumidity'] as num?)?.toDouble() ?? 0.30,
    weightGas: (json['weightGas'] as num?)?.toDouble() ?? 0.20,
    weightVentilation: (json['weightVentilation'] as num?)?.toDouble() ?? 0.15,
    developerPin: json['developerPin'] as String? ?? AppConstants.defaultDeveloperPin,
    isSimulationActive: json['isSimulationActive'] as bool? ?? false,
    simulationScenario: json['simulationScenario'] as String? ?? 'Normal Storage',
    simulationSpeed: (json['simulationSpeed'] as num?)?.toDouble() ?? 1.0,
    notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
    whatsappEnabled: json['whatsappEnabled'] as bool? ?? json['smsEnabled'] as bool? ?? true,
    whatsappProvider: json['whatsappProvider'] as String? ?? 'Circuit Digest Cloud WhatsApp API',
    whatsappPhoneNumber: json['whatsappPhoneNumber'] as String? ?? json['alertPhoneNumber'] as String? ?? '',
    whatsappApiKey: (json['whatsappApiKey'] as String?)?.isNotEmpty == true
        ? json['whatsappApiKey'] as String
        : ((json['fast2SmsApiKey'] as String?)?.isNotEmpty == true ? json['fast2SmsApiKey'] as String : 'cd_muh_131126_sIj6nj'),
    whatsappCustomWebhookUrl: json['whatsappCustomWebhookUrl'] as String? ?? '',
    ntfyTopic: json['ntfyTopic'] as String? ?? 'onionguard_storage_alerts',
    alertCooldownMinutes: json['alertCooldownMinutes'] as int? ?? 15,
    inboundApiEnabled: json['inboundApiEnabled'] as bool? ?? true,
    inboundApiPort: json['inboundApiPort'] as int? ?? 8088,
    backendMode: json['backendMode'] as String? ?? 'LOCAL_OFFLINE',
    supabaseUrl: json['supabaseUrl'] as String? ?? '',
    supabaseAnonKey: json['supabaseAnonKey'] as String? ?? '',
  );
}
