/// Set at build time:  flutter run --dart-define=API_URL=https://your-api.onrender.com
const String apiBaseUrl = String.fromEnvironment('API_URL', defaultValue: 'https://parkfame-api.onrender.com');

/// Firebase settings, injected at build time (no flutterfire / google-services.json needed)
const String fbApiKey = String.fromEnvironment('FB_API_KEY');
const String fbAppId = String.fromEnvironment('FB_APP_ID');
const String fbSenderId = String.fromEnvironment('FB_SENDER_ID');
const String fbProjectId = String.fromEnvironment('FB_PROJECT_ID');
