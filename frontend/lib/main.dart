// main.dart — Lab-on-Chip Medical Device Monitor

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert' show json, base64Decode, LineSplitter;
import 'dart:typed_data';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:window_manager/window_manager.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Backend Configuration ─────────────────────────────────────────────────
// Update these two URLs when migrating hosting providers
class _BackendConfig {
  static const String sensorUrl = 'https://sensor-sfdc.onrender.com';
  static const String cellUrl   = 'https://cell-dsvm.onrender.com';
}
// ─────────────────────────────────────────────────────────────────────────





// Desktop-only: trust self-signed certs (not needed on web — browser handles HTTPS)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await windowManager.ensureInitialized();
    await windowManager.setSize(const Size(1460, 870));
    await windowManager.setMinimumSize(const Size(1100, 680));
    await windowManager.center();
    await windowManager.setTitle('Lab-on-Chip Monitor');
  }
  runApp(const MedicalMonitorApp());
}

// ── Fake user database ────────────────────────────────────────────────────────

const _users = {
  'tech01': 'password1',
  'tech02': 'password2',
  'admin':  'admin123',
};

const _patients = [
  {
    'id':          'PAT-2024-001',
    'name':        'Marie Dupont',       // full name — never displayed
    'pseudo':      'Marie D.',           // pseudonymised — shown only on reveal
    'age':         '58',
    'diagnosis':   'Breast cancer — Stage II',
  },
  {
    'id':          'PAT-2024-002',
    'name':        'Jean-Pierre Arno',
    'pseudo':      'Jean-Pierre A.',
    'age':         '67',
    'diagnosis':   'Colorectal cancer — Stage III',
  },
  {
    'id':          'PAT-2024-003',
    'name':        'Sophie Laurent',
    'pseudo':      'Sophie L.',
    'age':         '44',
    'diagnosis':   'Ovarian cancer — Stage II',
  },
];

// ── Theme system ─────────────────────────────────────────────────────────────

class AppColors {
  // Shared accents (same in both modes)
  static const blue   = Color(0xFF388BFF);
  static const mint   = Color(0xFF26C6A0);
  static const purple = Color(0xFF170345);
  static const amber  = Color(0xFFFFA726);
  static const red    = Color(0xFFEF5350);
  static const green  = Color(0xFF1B8A5A);
  static const navy   = Color(0xFF1A1A2E);

  // Light mode surfaces
  static const lightBg         = Color(0xFFF3F3F3);
  static const loginBg         = Color(0xFFD5D6FF);
  static const lightCard       = Color(0xFFFFFFFF);
  static const lightSurface    = Color(0xFFF3F3F3);
  static const lightBorder     = Color(0x1A000000);
  static const lightText       = Color(0xFF1A1A2E);
  static const lightSubtext    = Color(0xFF666666);
  static const lightMuted      = Color(0xFF9E9E9E);

  // Dark mode surfaces — Material Design dark theme
  static const darkBg          = Color(0xFF121212); // Background
  static const darkCard        = Color(0xFF1E1E1E); // Surface elevated +1
  static const darkSurface     = Color(0xFF121212); // Surface
  static const darkElevated    = Color(0xFF2C2C2C); // Surface elevated +2
  static const darkBorder      = Color(0x1FFFFFFF); // subtle white border
  static const darkText        = Color(0xFFFFFFFF); // On Background / On Surface
  static const darkSubtext     = Color(0xB3FFFFFF); // 70% white
  static const darkMuted       = Color(0x61FFFFFF); // 38% white
  // Material dark accent colors
  static const darkPrimary     = Color(0xFFBB86FC); // Primary
  static const darkPrimaryVar  = Color(0xFF3700B3); // Primary Variant
  static const darkSecondary   = Color(0xFF03DAC6); // Secondary (teal)
  static const darkError       = Color(0xFFCF6679); // Error
}

class AppTheme {
  final bool dark;
  const AppTheme(this.dark);

  Color get bg          => dark ? AppColors.darkBg       : AppColors.lightBg;
  Color get card        => dark ? AppColors.darkCard      : AppColors.lightCard;
  Color get surface     => dark ? AppColors.darkSurface   : AppColors.lightSurface;
  Color get elevated    => dark ? AppColors.darkElevated  : const Color(0xFFE8EEFF);
  Color get border      => dark ? AppColors.darkBorder    : AppColors.lightBorder;
  Color get text        => dark ? AppColors.darkText      : AppColors.lightText;
  Color get subtext     => dark ? AppColors.darkSubtext   : AppColors.lightSubtext;
  Color get muted       => dark ? AppColors.darkMuted     : AppColors.lightMuted;
  Color get topBar      => dark ? AppColors.darkCard      : AppColors.lightCard;
  Color get inputFill   => dark ? AppColors.darkElevated  : AppColors.lightSurface;
  Color get sensorCard  => dark ? AppColors.darkCard      : AppColors.lightCard;
}

class ThemeNotifier extends ChangeNotifier {
  bool _dark = false;
  bool get dark => _dark;
  AppTheme get theme => AppTheme(_dark);

  ThemeNotifier() { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _dark = prefs.getBool('dark_mode') ?? false;
    notifyListeners();
  }

  Future<void> toggle() async {
    _dark = !_dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _dark);
    notifyListeners();
  }
}

// ── Session history ───────────────────────────────────────────────────────────

class PatientSession {
  final String patientId;
  final String diagnosis;
  final String bestDrug;
  final String bestCategory;
  final double bestEfficacy;
  final int wellCount;
  final DateTime timestamp;

  PatientSession({
    required this.patientId,
    required this.diagnosis,
    required this.bestDrug,
    required this.bestCategory,
    required this.bestEfficacy,
    required this.wellCount,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'patientId':    patientId,
    'diagnosis':    diagnosis,
    'bestDrug':     bestDrug,
    'bestCategory': bestCategory,
    'bestEfficacy': bestEfficacy,
    'wellCount':    wellCount,
    'timestamp':    timestamp.toIso8601String(),
  };

  factory PatientSession.fromJson(Map<String, dynamic> j) => PatientSession(
    patientId:    j['patientId'],
    diagnosis:    j['diagnosis'],
    bestDrug:     j['bestDrug'],
    bestCategory: j['bestCategory'],
    bestEfficacy: (j['bestEfficacy'] as num).toDouble(),
    wellCount:    j['wellCount'],
    timestamp:    DateTime.parse(j['timestamp']),
  );
}

class SessionHistory {
  static const _key = 'session_history';

  static Future<List<PatientSession>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = json.decode(raw) as List;
    return list.map((e) => PatientSession.fromJson(e)).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  static Future<void> save(PatientSession session) async {
    final sessions = await load();
    sessions.insert(0, session);
    // Keep last 100 sessions
    final trimmed = sessions.take(100).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json.encode(trimmed.map((s) => s.toJson()).toList()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

// ── App root ──────────────────────────────────────────────────────────────────

final themeNotifier = ThemeNotifier();

class MedicalMonitorApp extends StatefulWidget {
  const MedicalMonitorApp({super.key});
  @override
  State<MedicalMonitorApp> createState() => _MedicalMonitorAppState();
}

class _MedicalMonitorAppState extends State<MedicalMonitorApp> {
  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(() { if (mounted) setState(() {}); });
  }

  @override
  Widget build(BuildContext context) {
    final dark = themeNotifier.dark;
    return MaterialApp(
      title: 'Lab-on-Chip Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: dark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: dark ? AppColors.darkBg : const Color(0xFFF3F3F3),
        colorScheme: dark
            ? ColorScheme.dark(
                primary: AppColors.blue,
                surface: AppColors.darkCard,
                background: AppColors.darkBg,
              )
            : ColorScheme.fromSeed(seedColor: const Color(0xFF1A3A6E)),
      ),
      home: const LoginScreen(),
    );
  }
}

// ══════════════════════════════════════════
//  LOGIN SCREEN
// ══════════════════════════════════════════

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _userCtrl = TextEditingController(text: 'admin');
  final _passCtrl = TextEditingController(text: 'admin123');
  bool _obscure = true;
  String? _error;
  String _version = '';
  late AnimationController _rotCtrl;

  @override
  void initState() {
    super.initState();
    _rotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    setState(() => _version = 'v1.5.0');
  }

  @override
  void dispose() {
    _rotCtrl.dispose();
    super.dispose();
  }

  void _login() {
    final u = _userCtrl.text.trim();
    final p = _passCtrl.text;
    if (_users[u] == p) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => PatientSelectScreen(technician: u)));
    } else {
      setState(() => _error = 'Invalid username or password');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = themeNotifier.theme;
    final titleCol  = t.dark ? AppColors.darkPrimary : AppColors.purple;
    final versionCol = t.dark ? AppColors.darkMuted : AppColors.purple;
    return Scaffold(
      backgroundColor: t.dark ? AppColors.darkBg : AppColors.loginBg,
      body: Stack(children: [
        Center(
          child: SizedBox(width: 380,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [

            // Logo area — slowly rotating
            RotationTransition(
              turns: _rotCtrl,
              child: Image.asset(themeNotifier.dark ? 'assets/icon/icon_dark.png' : 'assets/icon/icon.png', width: 110, height: 110, fit: BoxFit.cover),
            ),
            const SizedBox(height: 20),
            Text('Lab-on-Chip Monitor',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: titleCol)),
            Text('Diagnostic Platform',
                style: TextStyle(fontSize: 13, color: titleCol)),
            const SizedBox(height: 6),
            Text('by Mattéo Meister',
                style: TextStyle(fontSize: 10,
                    color: t.dark ? AppColors.darkSubtext : Colors.white,
                    fontWeight: FontWeight.w400)),

            const SizedBox(height: 40),

            // Login card
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(t.dark ? 0.4 : 0.2),
                    blurRadius: 30, offset: const Offset(0, 10))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Technician Login',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: t.text)),
                const SizedBox(height: 6),
                Text('Authorised personnel only',
                    style: TextStyle(fontSize: 12, color: t.muted)),
                const SizedBox(height: 24),

                _field('Username', _userCtrl, false, t),
                const SizedBox(height: 14),
                _field('Password', _passCtrl, _obscure, t,
                    suffix: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                          size: 18, color: t.muted),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    )),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.red.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline, size: 16, color: AppColors.red),
                      const SizedBox(width: 8),
                      Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.red)),
                    ]),
                  ),
                ],

                const SizedBox(height: 20),
                SizedBox(width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Sign In', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),

                const SizedBox(height: 16),
                Center(child: Text('Pre-filled: admin / admin123',
                    style: TextStyle(fontSize: 11, color: t.muted))),
              ]),       // Column children
            ),             // Container (login card)
            ]),            // Column children (outer)
          ),               // SizedBox
        ),                 // Center
        // Version + dark mode toggle at bottom
        Positioned(
          bottom: 16, left: 0, right: 0,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(_version, style: TextStyle(fontSize: 10, color: versionCol)),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () => setState(() { themeNotifier.toggle(); }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: t.dark ? AppColors.darkElevated : Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: t.border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(t.dark ? Icons.dark_mode : Icons.light_mode,
                      size: 13, color: t.dark ? AppColors.darkPrimary : AppColors.purple),
                  const SizedBox(width: 5),
                  Text(t.dark ? 'Dark' : 'Light',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                          color: t.dark ? AppColors.darkPrimary : AppColors.purple)),
                ]),
              ),
            ),
          ]),
        ),
      ]),                  // Stack children
    );                     // Scaffold
  }

  Widget _field(String label, TextEditingController ctrl, bool obscure, AppTheme t, {
    Widget? suffix}) =>
    TextField(
      controller: ctrl,
      obscureText: obscure,
      onSubmitted: (_) => _login(),
      style: TextStyle(fontSize: 14, color: t.text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: t.muted),
        suffixIcon: suffix,
        filled: true,
        fillColor: t.inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: t.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: t.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.purple, width: 1.5)),
      ),
    );
}

// ══════════════════════════════════════════
//  PATIENT SELECTION SCREEN
// ══════════════════════════════════════════

// ── Mutable patient list (starts with demo patients) ─────────────────────────
final List<Map<String, String>> _runtimePatients = List.from(_patients);

// ── Simulated HL7 FHIR R4 database ───────────────────────────────────────────
const _fhirDatabase = {
  'PAT2024001': {
    'id': 'PAT-2024-001', 'name': 'Marie Dupont', 'pseudo': 'Marie D.',
    'age': '58', 'diagnosis': 'Breast cancer — Stage II',
    'fhir_id': 'f001', 'dob': '1966-03-14', 'gender': 'female', 'mrn': 'MRN-7714-A',
  },
  'PAT2024002': {
    'id': 'PAT-2024-002', 'name': 'Jean-Pierre Arno', 'pseudo': 'Jean-Pierre A.',
    'age': '67', 'diagnosis': 'Colorectal cancer — Stage III',
    'fhir_id': 'f002', 'dob': '1957-08-22', 'gender': 'male', 'mrn': 'MRN-8821-B',
  },
  'PAT2024003': {
    'id': 'PAT-2024-003', 'name': 'Sophie Laurent', 'pseudo': 'Sophie L.',
    'age': '44', 'diagnosis': 'Ovarian cancer — Stage II',
    'fhir_id': 'f003', 'dob': '1980-11-05', 'gender': 'female', 'mrn': 'MRN-5530-C',
  },
  'PAT2024004': {
    'id': 'PAT-2024-004', 'name': 'Lucas Bernard', 'pseudo': 'Lucas B.',
    'age': '52', 'diagnosis': 'Lung cancer — Stage II',
    'fhir_id': 'f004', 'dob': '1972-01-30', 'gender': 'male', 'mrn': 'MRN-6642-D',
  },
  'PAT2024005': {
    'id': 'PAT-2024-005', 'name': 'Camille Rousseau', 'pseudo': 'Camille R.',
    'age': '39', 'diagnosis': 'Melanoma — Stage III',
    'fhir_id': 'f005', 'dob': '1985-06-18', 'gender': 'female', 'mrn': 'MRN-9901-E',
  },
};

Future<Map<String, String>?> _fhirLookup(String barcode) async {
  await Future.delayed(const Duration(milliseconds: 900));
  final key = barcode.replaceAll('-', '').replaceAll(' ', '').toUpperCase();
  return _fhirDatabase[key];
}

class PatientSelectScreen extends StatefulWidget {
  final String technician;
  const PatientSelectScreen({super.key, required this.technician});
  @override
  State<PatientSelectScreen> createState() => _PatientSelectScreenState();
}

class _PatientSelectScreenState extends State<PatientSelectScreen> {
  final FocusNode _scanFocus = FocusNode();
  final TextEditingController _scanCtrl = TextEditingController();
  bool _scanning = false;
  String? _scanError;
  final StringBuffer _scanBuffer = StringBuffer();

  @override
  void dispose() {
    _scanFocus.dispose();
    _scanCtrl.dispose();
    super.dispose();
  }

  void _onScannerInput(String val) {
    _scanBuffer.clear();
    _scanBuffer.write(val);
  }

  void _onScannerSubmit(String val) {
    final code = val.trim();
    _scanCtrl.clear();
    if (code.isNotEmpty) _doLookup(code);
  }

  Future<void> _doLookup(String code) async {
    setState(() { _scanning = true; _scanError = null; });
    final result = await _fhirLookup(code);
    if (!mounted) return;
    if (result == null) {
      setState(() { _scanning = false; _scanError = 'No patient found for: $code'; });
      return;
    }
    setState(() => _scanning = false);
    _showFhirPreview(result);
  }

  void _showFhirPreview(Map<String, String> patient) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _FhirPreviewDialog(
        patient: patient,
        onConfirm: () {
          final alreadyExists = _runtimePatients.any((p) => p['id'] == patient['id']);
          if (!alreadyExists) setState(() => _runtimePatients.add(patient));
          Navigator.pop(context);
          Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => MainDashboard(
              technician: widget.technician, patient: patient)));
        },
      ),
    );
  }

  void _showAddManual() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _ManualBarcodeDialog(
        onSubmit: (code) { Navigator.pop(context); _doLookup(code); },
        onManualAdd: (patient) {
          Navigator.pop(context);
          // Show preview so user confirms before adding
          _showFhirPreview(patient);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = themeNotifier.theme;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Stack(children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Select Patient',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: t.text)),
                  Text('Logged in as ${widget.technician}',
                      style: TextStyle(fontSize: 13, color: t.muted)),
                ]),
                Row(children: [
                  GestureDetector(
                    onTap: _showAddManual,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: themeNotifier.dark ? AppColors.mint.withOpacity(0.12) : const Color(0xFF170345).withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: themeNotifier.dark ? AppColors.mint.withOpacity(0.4) : const Color(0xFF170345).withOpacity(0.2)),
                      ),
                      child: Row(children: [
                        Icon(Icons.qr_code_scanner, size: 15, color: themeNotifier.dark ? AppColors.darkSecondary : const Color(0xFF170345)),
                        const SizedBox(width: 7),
                        Text('Add Patient', style: TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w600, color: themeNotifier.dark ? AppColors.darkSecondary : const Color(0xFF170345))),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: () => Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => const LoginScreen())),
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Sign out'),
                    style: TextButton.styleFrom(foregroundColor: themeNotifier.dark ? AppColors.darkSubtext : Colors.black45),
                  ),
                ]),
              ]),

              const SizedBox(height: 16),

              _ScannerHintBar(
                scanning: _scanning,
                error: _scanError,
                onManualTap: _showAddManual,
                onFocus: () => _scanFocus.requestFocus(),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: ListView(
                  children: _runtimePatients.map((p) => _patientCard(context, p)).toList(),
                ),
              ),
            ]),
          ),

          // Hidden field capturing USB scanner input
          Positioned(
            left: -9999, top: -9999,
            child: SizedBox(
              width: 1, height: 1,
              child: TextField(
                focusNode: _scanFocus,
                controller: _scanCtrl,
                onChanged: _onScannerInput,
                onSubmitted: _onScannerSubmit,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _patientCard(BuildContext context, Map<String, String> p) {
    final t   = themeNotifier.theme;
    final isNew = !_patients.any((d) => d['id'] == p['id']);
    return GestureDetector(
      onTap: () => Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => MainDashboard(
            technician: widget.technician, patient: p))),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isNew
              ? AppColors.purple.withOpacity(0.3) : t.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(t.dark ? 0.15 : 0.04),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppColors.purple.withOpacity(themeNotifier.dark ? 0.25 : 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.person, color: themeNotifier.dark ? AppColors.darkSecondary : AppColors.purple, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(p['id']!, style: TextStyle(fontSize: 15,
                  fontWeight: FontWeight.w700, color: themeNotifier.dark ? AppColors.darkText : const Color(0xFF1A1A2E),
                  fontFamily: 'monospace')),
              if (isNew) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.purple.withOpacity(themeNotifier.dark ? 0.3 : 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('NEW', style: TextStyle(fontSize: 8,
                      fontWeight: FontWeight.w800, color: themeNotifier.dark ? AppColors.darkSecondary : AppColors.purple)),
                ),
              ],
            ]),
            const SizedBox(height: 2),
            Text(p['pseudo']!, style: TextStyle(fontSize: 12, color: themeNotifier.dark ? AppColors.darkSubtext : Colors.black45)),
            const SizedBox(height: 4),
            Text(p['diagnosis']!, style: TextStyle(fontSize: 12, color: themeNotifier.dark ? AppColors.darkSubtext : Colors.black54)),
          ])),
          Icon(Icons.chevron_right, color: themeNotifier.dark ? AppColors.darkMuted : Colors.black26),
        ]),
      ),
    );
  }
}

// ── Scanner hint bar ──────────────────────────────────────────────────────────
class _ScannerHintBar extends StatelessWidget {
  final bool scanning;
  final String? error;
  final VoidCallback onManualTap;
  final VoidCallback onFocus;
  const _ScannerHintBar({required this.scanning, required this.error,
      required this.onManualTap, required this.onFocus});

  @override
  Widget build(BuildContext context) {
    if (scanning) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF170345).withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF170345).withOpacity(0.2)),
        ),
        child: Row(children: [
          const SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF170345))),
          const SizedBox(width: 12),
          const Expanded(child: Text('Querying HL7 FHIR database…',
              style: TextStyle(fontSize: 12, color: Color(0xFF170345),
                  fontWeight: FontWeight.w600))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFF170345).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4)),
            child: const Text('FHIR R4', style: TextStyle(fontSize: 8,
                fontWeight: FontWeight.w800, color: Color(0xFF170345))),
          ),
        ]),
      );
    }
    if (error != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEF5350).withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEF5350).withOpacity(0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, size: 15, color: Color(0xFFEF5350)),
          const SizedBox(width: 10),
          Expanded(child: Text(error!, style: const TextStyle(
              fontSize: 12, color: Color(0xFFEF5350)))),
          GestureDetector(
            onTap: onManualTap,
            child: const Text('Try again', style: TextStyle(fontSize: 11,
                fontWeight: FontWeight.w700, color: Color(0xFF170345),
                decoration: TextDecoration.underline)),
          ),
        ]),
      );
    }
    return GestureDetector(
      onTap: onFocus,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: themeNotifier.dark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: themeNotifier.dark ? AppColors.darkBorder : Colors.black12),
        ),
        child: Row(children: [
          Icon(Icons.qr_code_2, size: 18, color: themeNotifier.dark ? AppColors.darkMuted : Colors.black26),
          const SizedBox(width: 12),
          Expanded(child: Text(
            'USB barcode scanner ready — scan a patient wristband to add or select',
            style: TextStyle(fontSize: 12, color: themeNotifier.dark ? AppColors.darkMuted : Colors.black38))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF26C6A0).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF26C6A0).withOpacity(0.3)),
            ),
            child: const Text('READY', style: TextStyle(fontSize: 8,
                fontWeight: FontWeight.w800, color: Color(0xFF26C6A0))),
          ),
        ]),
      ),
    );
  }
}

// ── Manual barcode entry dialog ───────────────────────────────────────────────
// ── Add Patient Dialog — tabbed: FHIR lookup | manual form ───────────────────
class _ManualBarcodeDialog extends StatefulWidget {
  final void Function(String) onSubmit;         // barcode lookup path
  final void Function(Map<String, String>) onManualAdd; // direct add path
  const _ManualBarcodeDialog({required this.onSubmit, required this.onManualAdd});
  @override
  State<_ManualBarcodeDialog> createState() => _ManualBarcodeDialogState();
}

class _ManualBarcodeDialogState extends State<_ManualBarcodeDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  // ── FHIR tab ──
  final _barcodeCtrl = TextEditingController();
  final _barcodeFocus = FocusNode();

  // ── Manual form tab ──
  final _formKey = GlobalKey<FormState>();
  final _idCtrl          = TextEditingController();
  final _nameCtrl        = TextEditingController();
  final _pseudoCtrl      = TextEditingController();
  final _ageCtrl         = TextEditingController();
  final _diagnosisCtrl   = TextEditingController();
  final _dobCtrl         = TextEditingController();
  final _mrnCtrl         = TextEditingController();
  String _gender = 'unknown';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _barcodeFocus.requestFocus());
  }

  @override
  void dispose() {
    _tabs.dispose();
    _barcodeCtrl.dispose(); _barcodeFocus.dispose();
    _idCtrl.dispose(); _nameCtrl.dispose(); _pseudoCtrl.dispose();
    _ageCtrl.dispose(); _diagnosisCtrl.dispose(); _dobCtrl.dispose();
    _mrnCtrl.dispose();
    super.dispose();
  }

  void _submitManual() {
    if (!_formKey.currentState!.validate()) return;
    final id = _idCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    // auto-generate pseudo from name if blank
    final pseudo = _pseudoCtrl.text.trim().isNotEmpty
        ? _pseudoCtrl.text.trim()
        : name.isNotEmpty
            ? '${name.split(' ').first} ${name.split(' ').length > 1 ? name.split(' ').last[0] + '.' : ''}'.trim()
            : id;
    widget.onManualAdd({
      'id':        id,
      'name':      name,
      'pseudo':    pseudo,
      'age':       _ageCtrl.text.trim(),
      'diagnosis': _diagnosisCtrl.text.trim(),
      'dob':       _dobCtrl.text.trim(),
      'gender':    _gender,
      'mrn':       _mrnCtrl.text.trim(),
      'fhir_id':   '',
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = themeNotifier.theme;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(t.dark ? 0.45 : 0.2),
              blurRadius: 40, offset: const Offset(0, 12))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // ── Header ──
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            decoration: const BoxDecoration(
              color: Color(0xFF170345),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.person_add_outlined, color: Colors.white70, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Add Patient', style: TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w800, color: themeNotifier.dark ? AppColors.darkCard : Colors.white)),
                  Text('Database lookup or manual entry',
                      style: TextStyle(fontSize: 11, color: Colors.white38)),
                ])),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white38, size: 18),
                ),
              ]),
              const SizedBox(height: 16),
              // Tab bar inside header
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TabBar(
                  controller: _tabs,
                  labelColor: const Color(0xFF170345),
                  unselectedLabelColor: Colors.white54,
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  indicator: BoxDecoration(
                    color: themeNotifier.dark ? AppColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  padding: const EdgeInsets.all(3),
                  tabs: const [
                    Tab(icon: Icon(Icons.qr_code_scanner, size: 14), text: 'FHIR Lookup'),
                    Tab(icon: Icon(Icons.edit_note, size: 14), text: 'Manual Entry'),
                  ],
                ),
              ),
              const SizedBox(height: 4),
            ]),
          ),

          // ── Tab views ──
          SizedBox(
            height: _tabs.index == 0 ? 320 : 420,
            child: TabBarView(
              controller: _tabs,
              children: [_fhirTab(), _manualTab()],
            ),
          ),
        ]),
      ),
    );
  }

  // ── Tab 0: FHIR barcode lookup ────────────────────────────────────────────
  Widget _fhirTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF388BFF).withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF388BFF).withOpacity(0.2)),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.local_hospital_outlined, size: 13, color: Color(0xFF388BFF)),
            SizedBox(width: 6),
            Text('HL7 FHIR R4  ·  Patient lookup',
                style: TextStyle(fontSize: 11, color: Color(0xFF388BFF),
                    fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 16),
        Text('Patient Barcode / ID', style: TextStyle(fontSize: 11,
            fontWeight: FontWeight.w700, color: themeNotifier.dark ? AppColors.darkSubtext : Colors.black45, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        TextField(
          controller: _barcodeCtrl,
          focusNode: _barcodeFocus,
          onSubmitted: (v) { if (v.trim().isNotEmpty) widget.onSubmit(v.trim()); },
          style: const TextStyle(fontSize: 15, fontFamily: 'monospace',
              fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: 'e.g. PAT2024004',
            hintStyle: TextStyle(color: themeNotifier.dark ? AppColors.darkMuted : Colors.black26,
                fontWeight: FontWeight.normal, fontFamily: 'monospace'),
            prefixIcon: const Icon(Icons.qr_code_2, color: Color(0xFF170345), size: 20),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: themeNotifier.dark ? AppColors.darkBorder : Colors.black12)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: themeNotifier.dark ? AppColors.darkBorder : Colors.black12)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF170345), width: 1.5)),
          ),
        ),
        const SizedBox(height: 12),
        Text('Demo barcodes:', style: TextStyle(fontSize: 10,
            color: themeNotifier.dark ? AppColors.darkMuted : Colors.black38, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6, runSpacing: 4,
          children: _fhirDatabase.keys.map((k) => GestureDetector(
            onTap: () {
              _barcodeCtrl.text = k;
              _barcodeCtrl.selection = TextSelection.fromPosition(
                  TextPosition(offset: k.length));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: themeNotifier.dark ? AppColors.darkSurface : const Color(0xFFF3F3F3),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: themeNotifier.dark ? AppColors.darkBorder : Colors.black12)),
              child: Text(k, style: const TextStyle(fontSize: 10,
                  fontFamily: 'monospace', color: Colors.black54)),
            ),
          )).toList(),
        ),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: themeNotifier.dark ? AppColors.darkMuted : Colors.black38)),
          )),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton.icon(
            onPressed: () {
              final v = _barcodeCtrl.text.trim();
              if (v.isNotEmpty) widget.onSubmit(v);
            },
            icon: const Icon(Icons.search, size: 15),
            label: const Text('Lookup Patient'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF170345),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          )),
        ]),
      ]),
    );
  }

  // ── Tab 1: Manual entry form ──────────────────────────────────────────────
  Widget _manualTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.25)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.warning_amber_outlined, size: 13, color: Colors.orange),
              SizedBox(width: 6),
              Text('Manual entry — not verified against FHIR',
                  style: TextStyle(fontSize: 11, color: Colors.orange,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 16),

          // Row 1: Patient ID + MRN
          Row(children: [
            Expanded(child: _formField(_idCtrl, 'Patient ID *',
                hint: 'PAT-2024-006', mono: true,
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null)),
            const SizedBox(width: 12),
            Expanded(child: _formField(_mrnCtrl, 'MRN',
                hint: 'MRN-0000-X')),
          ]),
          const SizedBox(height: 12),

          // Row 2: Full name + Pseudonym
          Row(children: [
            Expanded(child: _formField(_nameCtrl, 'Full Name *',
                hint: 'e.g. Jean Martin',
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null)),
            const SizedBox(width: 12),
            Expanded(child: _formField(_pseudoCtrl, 'Pseudonym',
                hint: 'Auto-generated if blank')),
          ]),
          const SizedBox(height: 12),

          // Row 3: DOB + Age + Gender
          Row(children: [
            Expanded(child: _formField(_dobCtrl, 'Date of Birth',
                hint: 'YYYY-MM-DD')),
            const SizedBox(width: 12),
            SizedBox(width: 72, child: _formField(_ageCtrl, 'Age',
                hint: '45', keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: _genderDropdown()),
          ]),
          const SizedBox(height: 12),

          // Diagnosis (full width)
          _formField(_diagnosisCtrl, 'Diagnosis *',
              hint: 'e.g. Lung cancer — Stage II',
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),

          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: themeNotifier.dark ? AppColors.darkMuted : Colors.black38)),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton.icon(
              onPressed: _submitManual,
              icon: const Icon(Icons.person_add_outlined, size: 15),
              label: const Text('Add Patient'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF170345),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            )),
          ]),
        ]),
      ),
    );
  }

  Widget _formField(
    TextEditingController ctrl,
    String label, {
    String? hint,
    bool mono = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(fontSize: 13,
          fontFamily: mono ? 'monospace' : null,
          fontWeight: mono ? FontWeight.w700 : FontWeight.normal),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(fontSize: 12, color: themeNotifier.dark ? AppColors.darkMuted : Colors.black26),
        labelStyle: TextStyle(fontSize: 12, color: themeNotifier.dark ? AppColors.darkSubtext : Colors.black45),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: themeNotifier.dark ? AppColors.darkBorder : Colors.black12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: themeNotifier.dark ? AppColors.darkBorder : Colors.black12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF170345), width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFEF5350))),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFEF5350), width: 1.5)),
        errorStyle: const TextStyle(fontSize: 9),
      ),
    );
  }

  Widget _genderDropdown() {
    return DropdownButtonFormField<String>(
      value: _gender,
      onChanged: (v) => setState(() => _gender = v ?? 'unknown'),
      style: TextStyle(fontSize: 13, color: themeNotifier.dark ? AppColors.darkText : const Color(0xFF1A1A2E)),
      decoration: InputDecoration(
        labelText: 'Gender',
        labelStyle: TextStyle(fontSize: 12, color: themeNotifier.dark ? AppColors.darkSubtext : Colors.black45),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: themeNotifier.dark ? AppColors.darkBorder : Colors.black12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: themeNotifier.dark ? AppColors.darkBorder : Colors.black12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF170345), width: 1.5)),
      ),
      items: const [
        DropdownMenuItem(value: 'male',    child: Text('Male')),
        DropdownMenuItem(value: 'female',  child: Text('Female')),
        DropdownMenuItem(value: 'unknown', child: Text('Other')),
      ],
    );
  }
}

// ── FHIR Preview Dialog ───────────────────────────────────────────────────────
class _FhirPreviewDialog extends StatelessWidget {
  final Map<String, String> patient;
  final VoidCallback onConfirm;
  const _FhirPreviewDialog({required this.patient, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final t = themeNotifier.theme;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(t.dark ? 0.45 : 0.2),
              blurRadius: 40, offset: const Offset(0, 12))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF170345),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF388BFF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_hospital_outlined,
                    color: Color(0xFF388BFF), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('HL7 FHIR Patient Record',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: themeNotifier.dark ? AppColors.darkCard : Colors.white)),
                Text('resourceType: Patient  ·  R4',
                    style: TextStyle(fontSize: 10, color: Colors.white38, fontFamily: 'monospace')),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF26C6A0).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF26C6A0).withOpacity(0.5)),
                ),
                child: const Text('200 OK', style: TextStyle(fontSize: 9,
                    fontWeight: FontWeight.w800, color: Color(0xFF26C6A0),
                    fontFamily: 'monospace')),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: themeNotifier.dark ? AppColors.darkElevated : const Color(0xFFF8F9FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF170345).withOpacity(0.15)),
                ),
                child: Column(children: [
                  Row(children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF170345).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.person_outlined, color: Color(0xFF170345), size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(patient['id']!, style: const TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E),
                          fontFamily: 'monospace')),
                      const SizedBox(height: 2),
                      Text(patient['pseudo']!, style: TextStyle(
                          fontSize: 12, color: themeNotifier.dark ? AppColors.darkSubtext : Colors.black45)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('fhir/${patient['fhir_id']}', style: TextStyle(
                          fontSize: 9, color: themeNotifier.dark ? AppColors.darkMuted : Colors.black26, fontFamily: 'monospace')),
                      Text(patient['mrn']!, style: TextStyle(fontSize: 10,
                          fontWeight: FontWeight.w600, color: themeNotifier.dark ? AppColors.darkMuted : Colors.black38,
                          fontFamily: 'monospace')),
                    ]),
                  ]),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: t.border),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _fhirField('identifier', patient['id']!)),
                    Expanded(child: _fhirField('birthDate', patient['dob']!)),
                    Expanded(child: _fhirField('gender', patient['gender']!)),
                    Expanded(child: _fhirField('age', '${patient['age']} y')),
                  ]),
                  const SizedBox(height: 14),
                  _fhirField('condition / diagnosis', patient['diagnosis']!),
                ]),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFA726).withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFA726).withOpacity(0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 14, color: Color(0xFFFFA726)),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                    'Patient identity verified via HL7 FHIR R4. Confirm before opening session.',
                    style: TextStyle(fontSize: 10, color: themeNotifier.dark ? AppColors.darkSubtext : Colors.black45, height: 1.4))),
                ]),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: themeNotifier.dark ? AppColors.darkBorder : Colors.black12)),
                  ),
                  child: Text('Cancel', style: TextStyle(color: themeNotifier.dark ? AppColors.darkSubtext : Colors.black45)),
                )),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: ElevatedButton.icon(
                  onPressed: onConfirm,
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Confirm & Open Session'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF170345),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _fhirField(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 12, bottom: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(key, style: TextStyle(fontSize: 8, color: themeNotifier.dark ? AppColors.darkMuted : Colors.black38,
            fontFamily: 'monospace', fontWeight: FontWeight.w600, letterSpacing: 0.3)),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: themeNotifier.dark ? AppColors.darkText : const Color(0xFF1A1A2E)), overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

// ══════════════════════════════════════════
//  MAIN DASHBOARD
// ══════════════════════════════════════════

class MainDashboard extends StatefulWidget {
  final String technician;
  final Map<String, String> patient;
  const MainDashboard({super.key, required this.technician, required this.patient});
  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _tab = 0;
  bool _nameRevealed = false;
  Timer? _revealTimer;
  final List<String> _auditLog = [];

  static const String _backendUrl = _BackendConfig.sensorUrl;

  // ── Targets (survive tab switches) ──────────────────────────────────────
  final Map<String, double> targets = {
    'temperature': 37.0,
    'humidity':    95.0,
    'co2':          5.0,
    'o2':          21.0,
    'pressure':  1013.0,
    'ph':           7.4,
  };

  Future<void> pushTargets() async {
    try {
      final body = '{'
        '"temperature":${targets['temperature']},'
        '"humidity":${targets['humidity']},'
        '"co2":${targets['co2']},'
        '"o2":${targets['o2']},'
        '"pressure":${targets['pressure']},'
        '"ph":${targets['ph']}'
        '}';
      await http.post(
        Uri.parse('$_backendUrl/api/targets'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
    } catch (e) {
      print('[Targets] Could not push: $e');
    }
  }

  // ── Protocol state (lifted so it survives tab switches) ──────────────────
  ProtocolStatus _runStatus  = ProtocolStatus.idle;
  Timer?         _protocolTicker;
  int            _activeStep  = 0;
  int            _totalElapsed = 0;

  final List<ProtocolStep> _steps = [
    ProtocolStep(id:'intake',       title:'Sample Intake',
        description:'Biopsy sample loaded into inlet port. System priming microfluidic channels.',
        icon:Icons.science, durationSeconds:120),
    ProtocolStep(id:'dissociation', title:'Cell Dissociation',
        description:'Enzymatic dissociation of tumor tissue into single-cell suspension.',
        icon:Icons.biotech, durationSeconds:300),
    ProtocolStep(id:'droplets',     title:'Droplet Generation',
        description:'Cells encapsulated in picoliter droplets. Target: 1 cell / droplet.',
        icon:Icons.water_drop, durationSeconds:180),
    ProtocolStep(id:'drug_loading', title:'Drug Combination Loading',
        description:'Combinatorial drug library injected into droplet array across 24 wells.',
        icon:Icons.medication, durationSeconds:240),
    ProtocolStep(id:'incubation',   title:'Incubation',
        description:'Cells incubated with drugs at 37°C, 5% CO₂ for 48h. Environment monitored continuously.',
        icon:Icons.thermostat, durationSeconds:600),
    ProtocolStep(id:'imaging',      title:'Fluorescence Imaging',
        description:'Automated microscopy scan of all wells. Viability markers imaged per droplet.',
        icon:Icons.search, durationSeconds:300),
    ProtocolStep(id:'analysis',     title:'Data Analysis & Ranking',
        description:'ML model scores drug efficacy. Top combinations ranked and quality-controlled.',
        icon:Icons.bar_chart, durationSeconds:120),
  ];

  // Oncology is unlocked once imaging step is reached
  bool get _oncologyUnlocked {
    const unlockedAt = {'imaging', 'analysis'};
    if (_runStatus == ProtocolStatus.completed) return true;
    if (_activeStep >= _steps.length) return true;
    return unlockedAt.contains(_steps[_activeStep].id) ||
        _steps.any((s) => unlockedAt.contains(s.id) && s.status == StepStatus.done);
  }

  String get _activeStepId =>
      _activeStep < _steps.length ? _steps[_activeStep].id : 'report';

  void startProtocol() {
    setState(() {
      _runStatus    = ProtocolStatus.running;
      _activeStep   = 0;
      _totalElapsed = 0;
      for (final s in _steps) {
        s.status = StepStatus.pending;
        s.elapsedSeconds = 0;
        s.note = null;
      }
      _steps[0].status = StepStatus.active;
    });
    _protocolTicker?.cancel();
    _protocolTicker = Timer.periodic(const Duration(seconds: 1), _protocolTick);
  }

  void _protocolTick(Timer _) {
    if (_runStatus != ProtocolStatus.running) return;
    setState(() {
      _totalElapsed++;
      final step = _steps[_activeStep];
      step.elapsedSeconds++;
      if (step.durationSeconds > 0 &&
          step.elapsedSeconds >= step.durationSeconds) {
        step.status = StepStatus.done;
        if (_activeStep < _steps.length - 1) {
          _activeStep++;
          _steps[_activeStep].status = StepStatus.active;
          // If next step has 0 duration, complete it immediately
          if (_steps[_activeStep].durationSeconds == 0) {
            _steps[_activeStep].status = StepStatus.done;
            _runStatus = ProtocolStatus.completed;
            _protocolTicker?.cancel();
          }
        } else {
          _runStatus = ProtocolStatus.completed;
          _steps.last.status = StepStatus.done;
          _protocolTicker?.cancel();
        }
      }
    });
  }

  void pauseResumeProtocol() {
    setState(() {
      if (_runStatus == ProtocolStatus.running) {
        _runStatus = ProtocolStatus.paused;
        _protocolTicker?.cancel();
      } else if (_runStatus == ProtocolStatus.paused) {
        _runStatus = ProtocolStatus.running;
        _protocolTicker = Timer.periodic(
            const Duration(seconds: 1), _protocolTick);
      }
    });
  }

  void abortProtocol() {
    setState(() {
      _runStatus = ProtocolStatus.aborted;
      if (_activeStep < _steps.length) {
        _steps[_activeStep].status = StepStatus.failed;
      }
      _protocolTicker?.cancel();
    });
  }

  // ⚡ Simulation only — instantly completes the current step
  void skipStep() {
    if (_runStatus != ProtocolStatus.running &&
        _runStatus != ProtocolStatus.paused) return;
    setState(() {
      _steps[_activeStep].status = StepStatus.done;
      _totalElapsed += _steps[_activeStep].durationSeconds -
          _steps[_activeStep].elapsedSeconds;
      _steps[_activeStep].elapsedSeconds =
          _steps[_activeStep].durationSeconds;

      if (_activeStep < _steps.length - 1) {
        _activeStep++;
        _steps[_activeStep].status = StepStatus.active;
        // Keep running if it was running, keep paused if it was paused
      } else {
        _runStatus = ProtocolStatus.completed;
        _steps.last.status = StepStatus.done;
        _protocolTicker?.cancel();
      }
    });
  }

  void _autoShowReport() {
    showProtocolReport(
      context,
      patient:      widget.patient,
      steps:        _steps,
      totalElapsed: _totalElapsed,
      technician:   widget.technician,
    );
  }

  @override
  void initState() {
    super.initState();
    _startLogger();
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    _protocolTicker?.cancel();
    super.dispose();
  }

  Future<void> _startLogger() async {
    try {
      await http.post(
        Uri.parse('$_backendUrl/api/logger/start'),
        headers: {'Content-Type': 'application/json'},
        body: '{"patient_id":"${widget.patient['id']}"}',
      );
      print('[Logger] Started for ${widget.patient['id']}');
    } catch (e) {
      print('[Logger] Could not start: $e');
    }
  }

  Future<void> _stopLogger() async {
    try {
      await http.post(Uri.parse('$_backendUrl/api/logger/stop'));
      print('[Logger] Stopped');
    } catch (e) {
      print('[Logger] Could not stop: $e');
    }
  }

  void _revealName() {
    final now = DateTime.now();
    final ts = '${now.hour.toString().padLeft(2,'0')}:'
               '${now.minute.toString().padLeft(2,'0')}:'
               '${now.second.toString().padLeft(2,'0')}';
    setState(() {
      _nameRevealed = true;
      _auditLog.insert(0,
          '$ts — ${widget.technician} revealed identity of ${widget.patient['id']}');
    });
    _revealTimer?.cancel();
    _revealTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _nameRevealed = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = themeNotifier.theme;
    return Scaffold(
      backgroundColor: t.surface,
      body: SafeArea(
        child: Column(children: [
          _topBar(),
          Expanded(child: _tab == 0
              ? EnvironmentPanel(
                  patient: widget.patient,
                  targets: targets,
                  onTargetsChanged: (updated) {
                    setState(() => targets.addAll(updated));
                    pushTargets();
                  },
                )
              : _tab == 1
                  ? RunProtocolPanel(
                      patient:          widget.patient,
                      runStatus:        _runStatus,
                      steps:            _steps,
                      activeStep:       _activeStep,
                      totalElapsed:     _totalElapsed,
                      onStart:          startProtocol,
                      onPauseResume:    pauseResumeProtocol,
                      onAbort:          abortProtocol,
                      onSkip:           skipStep,
                      onViewReport: () => showProtocolReport(
                        context,
                        patient:      widget.patient,
                        steps:        _steps,
                        totalElapsed: _totalElapsed,
                        technician:   widget.technician,
                      ),
                    )
                  : OncologyPanel(
                      unlocked:      _oncologyUnlocked,
                      runStatus:     _runStatus,
                      activeStepId:  _activeStepId,
                      patient:       widget.patient,
                      technician:    widget.technician,
                      onGoToProtocol: () => setState(() => _tab = 1),
                    )),
        ]),
      ),
    );
  }

  Widget _topBar() { final t = themeNotifier.theme; return Container(
    color: t.topBar,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    child: Stack(alignment: Alignment.center, children: [
      // ── Tabs — absolutely centered in the full bar width ──
      Center(
        child: Container(
          decoration: BoxDecoration(color: t.dark ? AppColors.darkElevated : const Color(0xFFF3F3F3),
              borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _tabBtn('🧪  Environment', 0),
            _tabBtn('⚗️  Protocol',    1,
                badge: _runStatus == ProtocolStatus.running ? 'LIVE'
                     : _runStatus == ProtocolStatus.paused  ? 'PAUSED'
                     : null,
                badgeColor: _runStatus == ProtocolStatus.running
                     ? const Color(0xFF388BFF)
                     : const Color(0xFFFFA726)),
            _tabBtn('🔬  Oncology',    2,
                badge: !_oncologyUnlocked && _runStatus != ProtocolStatus.idle
                     ? 'LOCKED' : null,
                badgeColor: const Color(0xFF9E9E9E)),
          ]),
        ),
      ),
      // ── Left + Right content — equal Expanded sides force true centering ──
      Row(children: [
      Expanded(child: Row(children: [

      // Patient badge — ID always visible, name revealed on tap
      GestureDetector(
        onTap: () async {
          await _stopLogger();
          if (!mounted) return;
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) =>
                  PatientSelectScreen(technician: widget.technician)));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1A3A6E).withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF1A3A6E).withOpacity(0.2)),
          ),
          child: Row(children: [
            Icon(Icons.person, size: 14, color: themeNotifier.dark ? AppColors.darkSecondary : const Color(0xFF1A3A6E)),
            const SizedBox(width: 6),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Always show patient ID
              Text(widget.patient['id']!,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: Color(0xFF1A3A6E), fontFamily: 'monospace')),
              // Pseudonymised name only when revealed
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _nameRevealed
                    ? Text(widget.patient['pseudo']!,
                        key: const ValueKey('revealed'),
                        style: TextStyle(fontSize: 9, color: themeNotifier.dark ? AppColors.darkSubtext : Colors.black45))
                    : const Text('', key: ValueKey('hidden')),
              ),
            ]),
            const SizedBox(width: 6),
            Icon(Icons.swap_horiz, size: 13, color: themeNotifier.dark ? AppColors.darkSecondary : const Color(0xFF1A3A6E)),
          ]),
        ),
      ),

      const SizedBox(width: 8),

      // Reveal identity button
      Tooltip(
        message: _nameRevealed ? 'Identity visible — auto-hides in 5s' : 'Reveal patient identity',
        child: GestureDetector(
          onTap: _revealName,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _nameRevealed
                  ? AppColors.amber.withOpacity(0.15)
                  : t.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _nameRevealed
                    ? AppColors.amber.withOpacity(0.6)
                    : t.border),
            ),
            child: Row(children: [
              Icon(_nameRevealed ? Icons.visibility : Icons.visibility_off,
                  size: 13,
                  color: _nameRevealed ? AppColors.amber : (themeNotifier.dark ? AppColors.darkSubtext : Colors.black38)),
              const SizedBox(width: 4),
              Text(_nameRevealed ? 'Visible' : 'Reveal',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                      color: _nameRevealed ? AppColors.amber : (themeNotifier.dark ? AppColors.darkSubtext : Colors.black38))),
            ]),
          ),
        ),
      ),

      const SizedBox(width: 8),

      // Audit log button
      Tooltip(
        message: 'View audit log',
        child: GestureDetector(
          onTap: () => _showAuditLog(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: themeNotifier.dark ? AppColors.darkBorder : Colors.black12),
            ),
            child: Row(children: [
              Icon(Icons.receipt_long, size: 13, color: themeNotifier.dark ? AppColors.darkMuted : Colors.black38),
              const SizedBox(width: 4),
              Text('Audit (${_auditLog.length})',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                      color: themeNotifier.dark ? AppColors.darkMuted : Colors.black38)),
            ]),
          ),
        ),
      ),

      const SizedBox(width: 12),
      ])), // end left Expanded

      // Right side — same Expanded so both sides are equal width
      Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        // Dark mode toggle
        GestureDetector(
          onTap: () => setState(() { themeNotifier.toggle(); }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: t.dark ? AppColors.darkElevated : const Color(0xFFF3F3F3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: t.border),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(t.dark ? Icons.dark_mode : Icons.light_mode,
                  size: 13, color: t.dark ? AppColors.darkPrimary : AppColors.purple),
              const SizedBox(width: 5),
              Text(t.dark ? 'Dark' : 'Light',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                      color: t.dark ? AppColors.darkPrimary : AppColors.purple)),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        Text(widget.technician,
            style: TextStyle(fontSize: 12, color: t.muted)),
        const SizedBox(width: 12),
        TextButton.icon(
          onPressed: () async {
            await _stopLogger();
            if (!mounted) return;
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const LoginScreen()));
          },
          icon: const Icon(Icons.logout, size: 14),
          label: const Text('Sign out', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(foregroundColor: themeNotifier.dark ? AppColors.darkSubtext : Colors.black38),
        ),
      ])), // end right Expanded
    ]),   // end Row
    ]),   // end Stack
  ); } // end _topBar

  void _showAuditLog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.receipt_long, size: 18, color: themeNotifier.dark ? AppColors.darkSecondary : const Color(0xFF1A3A6E)),
          SizedBox(width: 8),
          Text('Audit Log', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        content: SizedBox(
          width: 400,
          height: 300,
          child: _auditLog.isEmpty
              ? Center(child: Text('No events recorded yet.',
                  style: TextStyle(color: themeNotifier.dark ? AppColors.darkMuted : Colors.black38, fontSize: 13)))
              : ListView.separated(
                  itemCount: _auditLog.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(children: [
                      const Icon(Icons.lock_open, size: 13, color: Color(0xFFFFA726)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_auditLog[i],
                          style: const TextStyle(fontSize: 12, color: Colors.black54,
                              fontFamily: 'monospace'))),
                    ]),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _tabBtn(String label, int index,
      {
    String? badge, Color? badgeColor}) {
    final t   = themeNotifier.theme;
    final sel = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? (t.dark ? AppColors.darkElevated : AppColors.navy) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: sel ? Colors.white : t.muted)),
          if (badge != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: (badgeColor ?? Colors.grey).withOpacity(sel ? 0.3 : 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(badge,
                  style: TextStyle(
                    fontSize: 7, fontWeight: FontWeight.w800,
                    color: sel
                        ? Colors.white.withOpacity(0.9)
                        : (badgeColor ?? Colors.grey),
                  )),
            ),
          ],
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════
//  ENVIRONMENT PANEL
// ══════════════════════════════════════════

class SensorReading {
  final double value, target;
  final String unit, alarm;
  SensorReading({required this.value, required this.target,
    required this.unit, required this.alarm});
  factory SensorReading.fromJson(Map<String, dynamic> j) => SensorReading(
    value:  (j['value']  as num).toDouble(),
    target: (j['target'] as num).toDouble(),
    unit:   j['unit'],
    alarm:  j['alarm'],
  );
}

class EnvironmentPanel extends StatefulWidget {
  final Map<String, String> patient;
  final Map<String, double> targets;
  final void Function(Map<String, double>) onTargetsChanged;
  const EnvironmentPanel({
    super.key,
    required this.patient,
    required this.targets,
    required this.onTargetsChanged,
  });
  @override
  State<EnvironmentPanel> createState() => _EnvironmentPanelState();
}

class _EnvironmentPanelState extends State<EnvironmentPanel> {
  Map<String, SensorReading?> _readings = {};
  Timer? _timer;
  bool _connected = false;
  String _status = 'Connecting...';
  bool _settingsMode = false;
  bool _alarmsMode   = false;
  bool _exporting    = false;

  // Step sizes for +/- buttons
  static const Map<String, double> _steps = {
    'temperature': 0.5,
    'humidity':    1.0,
    'co2':         0.1,
    'o2':          0.5,
    'pressure':    1.0,
    'ph':          0.1,
  };

  // Bounds for clamping
  static const Map<String, (double, double)> _bounds = {
    'temperature': (30.0,  45.0),
    'humidity':    (60.0, 100.0),
    'co2':          (0.0,  20.0),
    'o2':           (0.0,  25.0),
    'pressure':   (900.0,1100.0),
    'ph':           (6.0,   8.0),
  };

  static const Map<String, String> _units = {
    'temperature': '°C', 'humidity': '%RH', 'co2': '%',
    'o2': '%', 'pressure': 'mbar', 'ph': 'pH',
  };

  // Alarm thresholds — warning and critical bands per sensor
  final Map<String, Map<String, double>> _warningThresholds = {
    'temperature': {'lo': 36.0,  'hi': 38.0},
    'humidity':    {'lo': 90.0,  'hi': 98.0},
    'co2':         {'lo': 4.5,   'hi': 5.5},
    'o2':          {'lo': 19.0,  'hi': 22.0},
    'pressure':    {'lo': 1005.0,'hi': 1020.0},
    'ph':          {'lo': 7.2,   'hi': 7.6},
  };
  final Map<String, Map<String, double>> _criticalThresholds = {
    'temperature': {'lo': 35.0, 'hi': 39.5},
    'humidity':    {'lo': 85.0, 'hi': 100.0},
    'co2':         {'lo': 3.5,  'hi': 7.0},
    'o2':          {'lo': 17.0, 'hi': 24.0},
    'pressure':    {'lo': 990.0,'hi': 1035.0},
    'ph':          {'lo': 6.8,  'hi': 7.8},
  };

  // History for sparklines — last 60 pts per sensor
  final Map<String, List<double>> _history = {
    'temperature': [], 'humidity': [], 'co2': [],
    'o2': [], 'pressure': [], 'ph': [],
  };

  // Timestamped rows for CSV export
  final List<Map<String, dynamic>> _exportLog = [];

  final String _url = '${_BackendConfig.sensorUrl}/api/environment';

  @override
  void initState() { super.initState(); _start(); }
  @override
  void dispose()   { _timer?.cancel(); super.dispose(); }

  void _start() => _timer = Timer.periodic(
      const Duration(seconds: 1), (_) => _fetch());

  Future<void> _fetch() async {
    try {
      final r = await http.get(Uri.parse(_url));
      if (r.statusCode == 200) {
        final d = json.decode(r.body) as Map<String, dynamic>;
        setState(() {
          _connected = true;
          _status = 'Live';
          d.forEach((key, val) {
            _readings[key] = SensorReading.fromJson(val);
            _history[key]?.add(_readings[key]!.value);
            if ((_history[key]?.length ?? 0) > 60) _history[key]?.removeAt(0);
          });
          // Append snapshot to export log (keep last 3600 = 1h at 1Hz)
          final row = <String, dynamic>{'ts': DateTime.now().toIso8601String()};
          d.forEach((key, val) => row[key] = (val['value'] as num).toDouble());
          _exportLog.add(row);
          if (_exportLog.length > 3600) _exportLog.removeAt(0);
        });
      }
    } catch (_) {
      setState(() { _connected = false; _status = 'Disconnected'; });
    }
  }

  Color _alarmColor(String alarm) {
    switch (alarm) {
      case 'critical': return const Color(0xFFEF5350);
      case 'warning':  return const Color(0xFFFFA726);
      default:         return const Color(0xFF26C6A0);
    }
  }

  // Compute alarm level for a value against editable thresholds
  String _computeAlarm(String key, double value) {
    final w = _warningThresholds[key];
    final c = _criticalThresholds[key];
    if (c != null && (value < c['lo']! || value > c['hi']!)) return 'critical';
    if (w != null && (value < w['lo']! || value > w['hi']!)) return 'warning';
    return 'ok';
  }

  // Export history to CSV and save to Downloads
  Future<void> _exportCsv() async {
    if (_exportLog.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No data to export yet — wait for sensor readings.'),
        backgroundColor: Color(0xFFFFA726),
      ));
      return;
    }

    // Build default filename and dir
    final now = DateTime.now();
    final defaultName =
        'sensor_export_${widget.patient['id']}_'
        '${now.year}${now.month.toString().padLeft(2,'0')}'
        '${now.day.toString().padLeft(2,'0')}'
        '_${now.hour.toString().padLeft(2,'0')}'
        '${now.minute.toString().padLeft(2,'0')}.csv';
    final defaultDir = kIsWeb ? null : (await getDownloadsDirectory() ??
                       await getApplicationDocumentsDirectory());

    // Show save-location dialog
    if (!mounted) return;
    final result = await showDialog<String>(
      context: context,
      barrierColor: Colors.black45,
      builder: (_) => _CsvSaveDialog(
        defaultDir: defaultDir?.path ?? '',
        defaultName: defaultName,
      ),
    );
    if (result == null) return; // user cancelled

    setState(() => _exporting = true);
    try {
      const keys = ['temperature','humidity','co2','o2','pressure','ph'];
      final buf = StringBuffer();
      buf.writeln('timestamp,${keys.join(',')}');
      for (final row in _exportLog) {
        buf.write(row['ts']);
        for (final k in keys) {
          buf.write(',');
          buf.write(row[k]?.toStringAsFixed(3) ?? '');
        }
        buf.writeln();
      }
      setState(() => _exporting = false);
      if (kIsWeb) {
        // On web: show CSV in a dialog for copy/paste (no file system access)
        if (mounted) {
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Export CSV'),
              content: SizedBox(
                width: 600, height: 400,
                child: SelectableText(buf.toString(),
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              ),
              actions: [TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              )],
            ),
          );
        }
      } else {
        final file = File(result);
        await file.parent.create(recursive: true);
        await file.writeAsString(buf.toString());
        final dir = file.parent.path;
        if (Platform.isMacOS) await Process.run('open', [dir]);
        else if (Platform.isLinux) await Process.run('xdg-open', [dir]);
        else if (Platform.isWindows) await Process.run('explorer', [dir]);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Exported ${_exportLog.length} rows → $result'),
          backgroundColor: const Color(0xFF388BFF),
        ));
      }
    } catch (e) {
      setState(() => _exporting = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Export failed: $e'),
        backgroundColor: const Color(0xFFEF5350),
      ));
    }
  }

  // Open alarm threshold editor dialog
  void _showAlarmEditor(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (_) => _AlarmThresholdDialog(
        warningThresholds: _warningThresholds,
        criticalThresholds: _criticalThresholds,
        units: _units,
        onSave: (warn, crit) => setState(() {
          warn.forEach((k, v) => _warningThresholds[k] = v);
          crit.forEach((k, v) => _criticalThresholds[k] = v);
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = themeNotifier.theme;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Status bar ──
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.patient['diagnosis']!,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.text)),
            Text('Lab-on-Chip Incubation Environment',
                style: TextStyle(fontSize: 11, color: t.muted)),
          ]),
          Row(children: [

            // ── Export CSV button ──
            GestureDetector(
              onTap: _exporting ? null : _exportCsv,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: themeNotifier.dark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: themeNotifier.dark ? AppColors.darkBorder : Colors.black12),
                ),
                child: Row(children: [
                  _exporting
                    ? const SizedBox(width: 12, height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2,
                            color: Color(0xFF388BFF)))
                    : const Icon(Icons.download_outlined, size: 13,
                        color: Color(0xFF388BFF)),
                  const SizedBox(width: 6),
                  Text(_exporting ? 'Exporting…' : 'Export CSV',
                      style: const TextStyle(fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF388BFF))),
                ]),
              ),
            ),

            const SizedBox(width: 8),

            // ── Alarm thresholds button ──
            GestureDetector(
              onTap: () {
                setState(() { _alarmsMode = !_alarmsMode; if (_alarmsMode) _settingsMode = false; });
                if (!_alarmsMode) _showAlarmEditor(context);
                else _showAlarmEditor(context);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: themeNotifier.dark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: themeNotifier.dark ? AppColors.darkBorder : Colors.black12),
                ),
                child: const Row(children: [
                  Icon(Icons.notifications_active_outlined, size: 13,
                      color: Color(0xFFFFA726)),
                  SizedBox(width: 6),
                  Text('Alarms', style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFFA726))),
                ]),
              ),
            ),

            const SizedBox(width: 8),

            // ── Target settings toggle ──
            GestureDetector(
              onTap: () => setState(() => _settingsMode = !_settingsMode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: _settingsMode ? AppColors.purple : (themeNotifier.dark ? AppColors.darkElevated : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _settingsMode ? AppColors.purple : (themeNotifier.dark ? AppColors.darkText.withOpacity(0.25) : Colors.black12)),
                  boxShadow: _settingsMode ? [BoxShadow(
                      color: const Color(0xFF170345).withOpacity(0.25),
                      blurRadius: 8, offset: const Offset(0, 2))] : [],
                ),
                child: Row(children: [
                  Icon(
                    _settingsMode ? Icons.tune : Icons.tune_outlined,
                    size: 13,
                    color: _settingsMode ? Colors.white : (themeNotifier.dark ? AppColors.darkSubtext : Colors.black45),
                  ),
                  const SizedBox(width: 6),
                  Text('Settings', style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: _settingsMode ? Colors.white : (themeNotifier.dark ? AppColors.darkSubtext : Colors.black45))),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 28, height: 16,
                    decoration: BoxDecoration(
                      color: _settingsMode
                          ? Colors.white.withOpacity(0.3) : (themeNotifier.dark ? AppColors.darkBorder : Colors.black12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(children: [
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 200),
                        alignment: _settingsMode
                            ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          width: 12, height: 12,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: themeNotifier.dark ? AppColors.darkCard : Colors.white, shape: BoxShape.circle),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),

            const SizedBox(width: 12),
            statusBadge(_connected, _status,
                onTap: _connected ? null
                    : () => (!kIsWeb && Platform.isMacOS) ? launchDocker(context, 'temp-sensor', 8080) : _fetch()),
          ]),
        ]),

        const SizedBox(height: 16),

        // ── Sensor grid (full width) ──
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;

            final cols    = w > 700 ? 3 : (w > 420 ? 2 : 1);
            final compact = w < 500;
            final rows    = (6 / cols).ceil();
            const minCardH = 140.0;
            const spacing  = 12.0;
            final totalMinH = rows * minCardH + (rows - 1) * spacing;

            if (h < totalMinH) {
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 6,
                separatorBuilder: (_, __) => const SizedBox(width: spacing),
                itemBuilder: (_, i) {
                  const sensors = [
                    ('Temperature', 'temperature', '🌡'),
                    ('Humidity',    'humidity',    '💧'),
                    ('CO₂',         'co2',         '💨'),
                    ('O₂',          'o2',          '🫁'),
                    ('Pressure',    'pressure',    '⏱'),
                    ('pH',          'ph',          '🧪'),
                  ];
                  return SizedBox(
                    width: 200, height: 160,
                    child: _sensorCard(sensors[i].$1, sensors[i].$2,
                        sensors[i].$3, true, _settingsMode),
                  );
                },
              );
            }

            final cardH = (h - (rows - 1) * spacing) / rows;
            final cardW = (w - (cols - 1) * spacing) / cols;

            return GridView.count(
              crossAxisCount: cols,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              childAspectRatio: cardW / cardH,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _sensorCard('Temperature', 'temperature', '🌡', compact, _settingsMode),
                _sensorCard('Humidity',    'humidity',    '💧', compact, _settingsMode),
                _sensorCard('CO₂',         'co2',         '💨', compact, _settingsMode),
                _sensorCard('O₂',          'o2',          '🫁', compact, _settingsMode),
                _sensorCard('Pressure',    'pressure',    '⏱', compact, _settingsMode),
                _sensorCard('pH',          'ph',          '🧪', compact, _settingsMode),
              ],
            );
          }),
        ),
      ]),
    );
  }

  Widget _sensorCard(String label, String key, String emoji, bool compact, bool settings) {
    final t       = themeNotifier.theme;
    final r       = _readings[key];
    final history = _history[key] ?? [];
    // Use editable thresholds for alarm level; fall back to backend alarm
    final alarm   = r != null ? _computeAlarm(key, r.value) : (r?.alarm ?? 'ok');
    final col     = settings ? const Color(0xFF170345) : _alarmColor(alarm);
    final target  = widget.targets[key] ?? 0.0;
    final step    = _steps[key]   ?? 1.0;
    final bounds  = _bounds[key]  ?? (0.0, 999.0);
    final unit    = r?.unit ?? '';

    final labelSize = compact ? 9.0  : 11.0;
    final valueSize = compact ? 20.0 : 28.0;
    final unitSize  = compact ? 9.0  : 11.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: settings ? const Color(0xFF1A3A6E).withOpacity(0.04) : (themeNotifier.dark ? AppColors.darkCard : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: settings
              ? const Color(0xFF1A3A6E).withOpacity(0.25)
              : col.withOpacity(alarm == 'ok' ? 0.2 : 0.6),
          width: settings ? 1.5 : (alarm == 'ok' ? 1 : 2),
        ),
        boxShadow: (!settings && alarm != 'ok')
            ? [BoxShadow(color: col.withOpacity(0.15),
                blurRadius: 8, offset: const Offset(0, 2))]
            : [],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header: emoji + label + alarm/settings badge ──
        Row(children: [
          Text(emoji, style: TextStyle(fontSize: compact ? 11 : 14)),
          SizedBox(width: compact ? 4 : 6),
          Flexible(child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: labelSize,
                  color: settings ? const Color(0xFF1A3A6E) : (themeNotifier.dark ? AppColors.darkText : Colors.black45),
                  fontWeight: FontWeight.w600))),
          const Spacer(),
          if (!settings && alarm != 'ok') Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(color: col.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4)),
            child: Text(alarm.toUpperCase(),
                style: TextStyle(fontSize: 7, fontWeight: FontWeight.w800, color: col)),
          ),
          if (settings) Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
                color: AppColors.purple.withOpacity(t.dark ? 0.25 : 0.1),
                borderRadius: BorderRadius.circular(4)),
            child: Text('TARGET',
                style: TextStyle(fontSize: 7, fontWeight: FontWeight.w800,
                    color: t.dark ? AppColors.darkSecondary : AppColors.purple)),
          ),
        ]),

        SizedBox(height: compact ? 4 : 8),

        // ── Live mode: value + unit ──
        if (!settings) ...[
          r == null
              ? Text('--', style: TextStyle(fontSize: valueSize,
                  fontWeight: FontWeight.w800, color: t.muted))
              : Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Flexible(child: Text(
                    key == 'ph'
                        ? r.value.toStringAsFixed(2)
                        : r.value.toStringAsFixed(1),
                    style: TextStyle(fontSize: valueSize,
                        fontWeight: FontWeight.w800, color: col, height: 1),
                    overflow: TextOverflow.ellipsis,
                  )),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2, left: 3),
                    child: Text(r.unit,
                        style: TextStyle(fontSize: unitSize, color: t.muted)),
                  ),
                ]),
          if (r != null) Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('Target: ${(widget.targets[key] ?? r.target).toStringAsFixed(step < 1 ? 2 : 1)}$unit',
                style: TextStyle(fontSize: compact ? 8 : 10, color: t.muted)),
          ),
          SizedBox(height: compact ? 6 : 10),
          Expanded(
            child: history.length < 2
                ? Center(child: Text('...', style: TextStyle(
                    color: themeNotifier.dark ? AppColors.darkBorder : Colors.black12, fontSize: compact ? 9 : 11)))
                : LineChart(_sparkline(history, col)),
          ),
        ],

        // ── Settings mode: +/- controls + tappable value ──
        if (settings) ...[
          const Spacer(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

            // Minus button
            _stepBtn(Icons.remove, () {
              final v = (target - step).clamp(bounds.$1, bounds.$2);
              final rounded = double.parse(v.toStringAsFixed(step < 1 ? 2 : 1));
              widget.onTargetsChanged({key: rounded});
            }, compact),

            // Tappable value — opens text input
            Expanded(
              child: GestureDetector(
                onTap: () => _editTarget(key, label, unit, target, bounds),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          step < 1
                              ? target.toStringAsFixed(2)
                              : target.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: valueSize,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1A3A6E),
                            height: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2, left: 3),
                          child: Text(unit,
                              style: TextStyle(fontSize: unitSize,
                                  color: themeNotifier.dark ? AppColors.darkMuted : Colors.black38)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Icon(Icons.edit, size: 9, color: themeNotifier.dark ? AppColors.darkMuted : Colors.black26),
                      const SizedBox(width: 3),
                      Text('tap to edit',
                          style: TextStyle(fontSize: 8, color: themeNotifier.dark ? AppColors.darkMuted : Colors.black26)),
                    ]),
                  ],
                ),
              ),
            ),

            // Plus button
            _stepBtn(Icons.add, () {
              final v = (target + step).clamp(bounds.$1, bounds.$2);
              final rounded = double.parse(v.toStringAsFixed(step < 1 ? 2 : 1));
              widget.onTargetsChanged({key: rounded});
            }, compact),
          ]),
          const Spacer(),
        ],
      ]),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap, bool compact) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:  compact ? 32 : 38,
        height: compact ? 32 : 38,
        decoration: BoxDecoration(
          color: const Color(0xFF1A3A6E).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF1A3A6E).withOpacity(0.2)),
        ),
        child: Icon(icon, size: compact ? 14 : 18, color: themeNotifier.dark ? AppColors.darkSecondary : const Color(0xFF1A3A6E)),
      ),
    );
  }

  void _editTarget(String key, String label, String unit,
      double current, (double, double) bounds) {
    final ctrl = TextEditingController(text: current.toStringAsFixed(
        (_steps[key] ?? 1) < 1 ? 2 : 1));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.tune, size: 16, color: themeNotifier.dark ? AppColors.darkSecondary : const Color(0xFF1A3A6E)),
          const SizedBox(width: 8),
          Text('Set $label Target',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Range: ${bounds.$1} – ${bounds.$2} $unit',
              style: TextStyle(fontSize: 11, color: themeNotifier.dark ? AppColors.darkMuted : Colors.black38)),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                color: themeNotifier.dark ? AppColors.darkSecondary : const Color(0xFF1A3A6E)),
            decoration: InputDecoration(
              suffixText: unit,
              suffixStyle: TextStyle(fontSize: 13, color: themeNotifier.dark ? AppColors.darkMuted : Colors.black38),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: Color(0xFF1A3A6E), width: 1.5),
              ),
            ),
            onSubmitted: (_) {
              _applyTarget(key, ctrl.text, bounds);
              Navigator.pop(context);
            },
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: themeNotifier.dark ? AppColors.darkMuted : Colors.black38)),
          ),
          ElevatedButton(
            onPressed: () {
              _applyTarget(key, ctrl.text, bounds);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A3A6E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _applyTarget(String key, String raw, (double, double) bounds) {
    final v = double.tryParse(raw);
    if (v == null) return;
    widget.onTargetsChanged({key: v.clamp(bounds.$1, bounds.$2)});
  }

  LineChartData _sparkline(List<double> data, Color color) {
    final spots = data.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value)).toList();
    final minY = data.reduce((a, b) => a < b ? a : b) - 0.1;
    final maxY = data.reduce((a, b) => a > b ? a : b) + 0.1;
    return LineChartData(
      minY: minY, maxY: maxY,
      minX: spots.first.x, maxX: spots.last.x,
      lineTouchData: LineTouchData(enabled: false),
      gridData: FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles:   AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:  AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:    AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      lineBarsData: [LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.4,
        color: color,
        barWidth: 2,
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(show: true, gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [color.withOpacity(themeNotifier.dark ? 0.35 : 0.2), color.withOpacity(0.0)],
        )),
      )],
    );
  }
}


// ══════════════════════════════════════════
//  RUN PROTOCOL PANEL
// ══════════════════════════════════════════

enum ProtocolStatus { idle, running, paused, completed, aborted }
enum StepStatus     { pending, active, done, failed }

class ProtocolStep {
  final String id, title, description;
  final IconData icon;
  final int durationSeconds; // nominal duration for progress bar
  StepStatus status;
  int elapsedSeconds;
  String? note;

  ProtocolStep({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.durationSeconds,
    this.status = StepStatus.pending,
    this.elapsedSeconds = 0,
    this.note,
  });
}

class RunProtocolPanel extends StatelessWidget {
  final Map<String, String> patient;
  final ProtocolStatus runStatus;
  final List<ProtocolStep> steps;
  final int activeStep;
  final int totalElapsed;
  final VoidCallback onStart;
  final VoidCallback onPauseResume;
  final VoidCallback onAbort;
  final VoidCallback onSkip;
  final VoidCallback onViewReport;

  const RunProtocolPanel({
    super.key,
    required this.patient,
    required this.runStatus,
    required this.steps,
    required this.activeStep,
    required this.totalElapsed,
    required this.onStart,
    required this.onPauseResume,
    required this.onAbort,
    required this.onSkip,
    required this.onViewReport,
  });

  int get _totalNominal =>
      steps.fold(0, (s, st) => s + st.durationSeconds);

  String _fmt(int sec) {
    final m = sec ~/ 60, s = sec % 60;
    return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  // ── Root build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final t = themeNotifier.theme;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(patient['diagnosis'] ?? '',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.text)),
            Text('Lab-on-Chip Monitor — Run Protocol',
                style: TextStyle(fontSize: 11, color: t.muted)),
          ]),
          const Spacer(),
          _statusBadge(context),
        ]),

        const SizedBox(height: 16),

        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 300, child: _stepperList()),
            const SizedBox(width: 16),
            Expanded(child: _rightPanel(context)),
          ]),
        ),
      ]),
    );
  }

  // ── Status badge ───────────────────────────────────────────────────────────
  Widget _statusBadge(BuildContext context) {
    final (label, col) = switch (runStatus) {
      ProtocolStatus.idle      => ('IDLE',      const Color(0xFF9E9E9E)),
      ProtocolStatus.running   => ('RUNNING',   const Color(0xFF388BFF)),
      ProtocolStatus.paused    => ('PAUSED',    const Color(0xFFFFA726)),
      ProtocolStatus.completed => ('COMPLETED', const Color(0xFF26C6A0)),
      ProtocolStatus.aborted   => ('ABORTED',   const Color(0xFFEF5350)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: col.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: col.withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        runStatus == ProtocolStatus.running
            ? _PulseDot(color: col)
            : Container(width: 7, height: 7,
                decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 10,
            fontWeight: FontWeight.w800, color: col)),
      ]),
    );
  }

  // ── Left stepper ───────────────────────────────────────────────────────────
  Widget _stepperList() {
    final t = themeNotifier.theme;
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: steps.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, indent: 52, endIndent: 16, color: t.border),
          itemBuilder: (_, i) => _stepRow(steps[i], i),
        ),
      ),
    );
  }

  Widget _stepRow(ProtocolStep step, int i) {
    final t = themeNotifier.theme;
    final isActive = i == activeStep &&
        (runStatus == ProtocolStatus.running ||
         runStatus == ProtocolStatus.paused);
    final isDone   = step.status == StepStatus.done;
    final isFailed = step.status == StepStatus.failed;

    final col = isFailed ? const Color(0xFFEF5350)
              : isDone   ? const Color(0xFF26C6A0)
              : isActive ? const Color(0xFF388BFF)
              :            (t.dark ? AppColors.darkMuted : const Color(0xFFE0E0E0));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      color: isActive
          ? const Color(0xFF388BFF).withOpacity(t.dark ? 0.12 : 0.05)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        // Circle indicator
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: (isDone || isFailed) ? col : col.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: col, width: isActive ? 2 : 1.5),
          ),
          child: Center(child: isDone
              ? Icon(Icons.check, size: 14, color: themeNotifier.dark ? AppColors.darkCard : Colors.white)
              : isFailed
                  ? Icon(Icons.close, size: 14, color: themeNotifier.dark ? AppColors.darkCard : Colors.white)
                  : Text('${i+1}', style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800, color: col))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(children: [
            Icon(step.icon, size: 14, color: t.dark ? AppColors.darkSecondary : const Color(0xFF1A3A6E)),
            const SizedBox(width: 5),
            Flexible(child: Text(step.title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: isActive ? const Color(0xFF388BFF)
                       : isDone   ? t.text
                       :            t.muted,
                ))),
          ]),
          if (isDone || isActive)
            Text(
              isDone ? 'Completed' : _fmt(step.elapsedSeconds),
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                  color: isDone
                      ? const Color(0xFF26C6A0)
                      : const Color(0xFF388BFF)),
            ),
        ])),
      ]),
    );
  }

  // ── Right panel ────────────────────────────────────────────────────────────
  Widget _rightPanel(BuildContext context) {
    return Column(children: [
      Expanded(child: _activeStepCard(context)),
      const SizedBox(height: 12),
      if (runStatus != ProtocolStatus.idle) _overallProgress(),
      const SizedBox(height: 12),
      _controlRow(context),
    ]);
  }

  Widget _activeStepCard(BuildContext context) {
    final t = themeNotifier.theme;
    if (runStatus == ProtocolStatus.idle)      return _idleCard();
    if (runStatus == ProtocolStatus.completed) return _completedCard();
    if (runStatus == ProtocolStatus.aborted)   return _abortedCard();

    final step      = steps[activeStep];
    final frac      = step.durationSeconds > 0
        ? (step.elapsedSeconds / step.durationSeconds).clamp(0.0, 1.0)
        : 1.0;
    final remaining = (step.durationSeconds - step.elapsedSeconds)
        .clamp(0, step.durationSeconds);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF388BFF).withOpacity(0.25), width: 1.5),
        boxShadow: [BoxShadow(
            color: const Color(0xFF388BFF).withOpacity(0.07),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header row
        Row(children: [
          Icon(step.icon, size: 28, color: t.dark ? AppColors.darkSecondary : const Color(0xFF1A3A6E)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              _pill('STEP ${activeStep + 1} / ${steps.length}',
                  const Color(0xFF388BFF)),
              if (runStatus == ProtocolStatus.paused) ...[
                const SizedBox(width: 8),
                _pill('PAUSED', const Color(0xFFFFA726)),
              ],
            ]),
            const SizedBox(height: 6),
            Text(step.title, style: TextStyle(fontSize: 18,
                fontWeight: FontWeight.w700, color: t.text)),
          ])),
          if (step.durationSeconds > 0)
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_fmt(step.elapsedSeconds),
                  style: const TextStyle(fontSize: 22,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                      color: Color(0xFF388BFF))),
              Text('${_fmt(remaining)} remaining',
                  style: TextStyle(fontSize: 9, color: themeNotifier.dark ? AppColors.darkMuted : Colors.black38)),
            ]),
        ]),

        const SizedBox(height: 20),

        // Description
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: themeNotifier.dark ? AppColors.darkElevated : const Color(0xFFF8F9FF),
              borderRadius: BorderRadius.circular(10)),
          child: Text(step.description,
              style: TextStyle(fontSize: 12,
                  color: themeNotifier.dark ? AppColors.darkSubtext : Colors.black54, height: 1.6)),
        ),

        const SizedBox(height: 20),

        // Step progress bar
        if (step.durationSeconds > 0) ...[
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Step progress', style: TextStyle(fontSize: 10,
                color: themeNotifier.dark ? AppColors.darkMuted : Colors.black38, fontWeight: FontWeight.w600)),
            Text('${(frac * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w700, color: Color(0xFF388BFF))),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: frac, minHeight: 6,
              backgroundColor: const Color(0xFFE8EEFF),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF388BFF)),
            ),
          ),
        ],

        const Spacer(),

        // QC note
        Row(children: [
          Icon(Icons.info_outline, size: 13, color: themeNotifier.dark ? AppColors.darkMuted : Colors.black26),
          const SizedBox(width: 6),
          Expanded(child: Text(_qcNote(step.id),
              style: TextStyle(fontSize: 10,
                  color: themeNotifier.dark ? AppColors.darkMuted : Colors.black38, fontStyle: FontStyle.italic))),
        ]),
      ]),
    );
  }

  Widget _pill(String label, Color col) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
        color: col.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4)),
    child: Text(label, style: TextStyle(fontSize: 8,
        fontWeight: FontWeight.w800, color: col)),
  );

  String _qcNote(String id) => switch (id) {
    'intake'       => 'Verify sample volume ≥ 50 µL before continuing.',
    'dissociation' => 'Target viability post-dissociation: >80%. Check cell counter.',
    'droplets'     => 'Droplet generation rate: 500–1000 droplets/sec. Monitor pressure.',
    'drug_loading' => 'Confirm 24-well drug matrix loaded. Check for air bubbles.',
    'incubation'   => 'Environment sensors active. Alarm thresholds enforced.',
    'imaging'      => 'Auto-focus calibration required if CV >10% across wells.',
    'analysis'     => 'ML model v2.4 running. Minimum 50 viable cells/well for inclusion.',
    _              => 'Review all QC flags before sending report to clinician.',
  };

  // ── Idle / Completed / Aborted cards ──────────────────────────────────────
  Widget _idleCard() { final t = themeNotifier.theme; return Container(
    width: double.infinity,
    decoration: BoxDecoration(color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border)),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Tooltip(
        message: 'Start Run',
        child: GestureDetector(
          onTap: onStart,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 64, height: 64,
              decoration: BoxDecoration(
                  color: const Color(0xFF388BFF).withOpacity(0.08),
                  shape: BoxShape.circle),
              child: const Icon(Icons.play_circle_outline,
                  size: 36, color: Color(0xFF388BFF)),
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Text('Ready to Run', style: TextStyle(fontSize: 18,
          fontWeight: FontWeight.w700, color: t.text)),
      const SizedBox(height: 8),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          'Start the Lab-on-Chip Monitor protocol for this patient sample.\n'
          'Ensure chip is loaded and all environment sensors are nominal.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: t.muted, height: 1.6),
        ),
      ),
      const SizedBox(height: 24),
      Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center,
        children: steps.map((s) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: t.dark ? AppColors.darkElevated : const Color(0xFFF3F3F3),
              borderRadius: BorderRadius.circular(20)),
          child: Text(s.title,
              style: TextStyle(fontSize: 10, color: t.muted)),
        )).toList()),
    ]),
  ); }

  Widget _completedCard() { final t = themeNotifier.theme; return Container(
    width: double.infinity,
    decoration: BoxDecoration(color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF26C6A0).withOpacity(0.4), width: 1.5)),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 64, height: 64,
        decoration: BoxDecoration(
            color: const Color(0xFF26C6A0).withOpacity(0.1),
            shape: BoxShape.circle),
        child: const Icon(Icons.check_circle_outline,
            size: 36, color: Color(0xFF26C6A0))),
      const SizedBox(height: 16),
      Text('Run Completed', style: TextStyle(fontSize: 18,
          fontWeight: FontWeight.w700, color: t.text)),
      const SizedBox(height: 8),
      Text(
        'Total runtime: ${_fmt(totalElapsed)}\nAll ${steps.length} steps completed successfully.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: t.muted, height: 1.6)),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: onViewReport,
        icon: const Icon(Icons.description_outlined, size: 15),
        label: const Text('View Report'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF26C6A0), foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    ]),
  ); }

  Widget _abortedCard() { final t = themeNotifier.theme; return Container(
    width: double.infinity,
    decoration: BoxDecoration(color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFFEF5350).withOpacity(0.4), width: 1.5)),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 64, height: 64,
        decoration: BoxDecoration(
            color: const Color(0xFFEF5350).withOpacity(0.08),
            shape: BoxShape.circle),
        child: const Icon(Icons.cancel_outlined,
            size: 36, color: Color(0xFFEF5350))),
      const SizedBox(height: 16),
      Text('Run Aborted', style: TextStyle(fontSize: 18,
          fontWeight: FontWeight.w700, color: t.text)),
      const SizedBox(height: 8),
      Text(
        'Aborted at step ${activeStep + 1}: ${steps[activeStep].title}.\n'
        'Elapsed: ${_fmt(totalElapsed)}',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: t.muted, height: 1.6)),
    ]),
  ); }

  // ── Overall progress bar ───────────────────────────────────────────────────
  Widget _overallProgress() {
    final done = steps.where((s) => s.status == StepStatus.done).length;
    final nominalDone = steps
        .where((s) => s.status == StepStatus.done)
        .fold(0, (s, st) => s + st.durationSeconds);
    final frac = _totalNominal > 0
        ? (nominalDone / _totalNominal).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: themeNotifier.dark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: themeNotifier.dark ? AppColors.darkBorder : Colors.black12)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Overall progress  ·  $done / ${steps.length} steps',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                  color: themeNotifier.dark ? AppColors.darkSubtext : Colors.black45)),
          Text('${(frac * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: Color(0xFF388BFF))),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: frac, minHeight: 5,
            backgroundColor: const Color(0xFFE8EEFF),
            valueColor: AlwaysStoppedAnimation(
              runStatus == ProtocolStatus.aborted
                  ? const Color(0xFFEF5350)
                  : const Color(0xFF388BFF),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Control buttons ────────────────────────────────────────────────────────
  Widget _controlRow(BuildContext context) {
    final canStart = runStatus == ProtocolStatus.idle ||
                     runStatus == ProtocolStatus.aborted ||
                     runStatus == ProtocolStatus.completed;
    final canPause = runStatus == ProtocolStatus.running ||
                     runStatus == ProtocolStatus.paused;
    final canAbort = runStatus == ProtocolStatus.running ||
                     runStatus == ProtocolStatus.paused;
    final canSkip  = runStatus == ProtocolStatus.running ||
                     runStatus == ProtocolStatus.paused;
    final isPaused = runStatus == ProtocolStatus.paused;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Main controls row
      Row(children: [
        Expanded(child: _ctrlBtn(
          label: canStart && runStatus != ProtocolStatus.idle
              ? 'New Run' : 'Start Run',
          icon: Icons.play_arrow_rounded,
          color: const Color(0xFF388BFF),
          enabled: canStart, onTap: onStart,
        )),
        const SizedBox(width: 10),
        Expanded(child: _ctrlBtn(
          label: isPaused ? 'Resume' : 'Pause',
          icon: isPaused
              ? Icons.play_circle_outline
              : Icons.pause_circle_outline,
          color: const Color(0xFFFFA726),
          enabled: canPause, onTap: onPauseResume,
        )),
        const SizedBox(width: 10),
        Expanded(child: _ctrlBtn(
          label: 'Abort Run',
          icon: Icons.stop_circle_outlined,
          color: const Color(0xFFEF5350),
          enabled: canAbort,
          onTap: () => _confirmAbort(context),
        )),
      ]),

      // Simulation skip row — only shown while a run is active
      if (canSkip) ...[
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onSkip,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: themeNotifier.dark ? AppColors.darkSurface : const Color(0xFFF3F3F3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: themeNotifier.dark ? AppColors.darkBorder : Colors.black12),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.fast_forward_rounded,
                  size: 14, color: themeNotifier.dark ? AppColors.darkMuted : Colors.black38),
              const SizedBox(width: 7),
              Text('Skip Step',
                  style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w600, color: themeNotifier.dark ? AppColors.darkSubtext : Colors.black45)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Text('SIMULATION ONLY',
                    style: TextStyle(fontSize: 7,
                        fontWeight: FontWeight.w800,
                        color: Colors.orange)),
              ),
            ]),
          ),
        ),
      ],
    ]);
  }

  void _confirmAbort(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFEF5350), size: 20),
          SizedBox(width: 8),
          Text('Abort Run?', style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
        content: const Text(
          'This will stop the current protocol. All in-progress data will be '
          'logged but the run cannot be resumed.',
          style: TextStyle(fontSize: 13, color: Colors.black54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); onAbort(); },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF5350),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Abort'),
          ),
        ],
      ),
    );
  }

  Widget _ctrlBtn({
    required String label, required IconData icon,
    required Color color, required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1.0 : 0.35,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: enabled
                ? color.withOpacity(0.1)
                : const Color(0xFFF3F3F3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: enabled ? color.withOpacity(0.4) : (themeNotifier.dark ? AppColors.darkBorder : Colors.black12)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: enabled ? color : Colors.black26),
            const SizedBox(width: 7),
            Text(label, style: TextStyle(fontSize: 12,
                fontWeight: FontWeight.w600,
                color: enabled ? color : Colors.black26)),
          ]),
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}
class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) => Container(
      width: 7, height: 7,
      decoration: BoxDecoration(
        color: widget.color.withOpacity(0.4 + 0.6 * _c.value),
        shape: BoxShape.circle,
      ),
    ),
  );
}

// ══════════════════════════════════════════
//  ONCOLOGY PANEL (unchanged from before)
// ══════════════════════════════════════════

class WellData {
  final int wellIndex, totalCells, aliveCells, deadCells;
  final String drug, category, framePng;
  final double viability, efficacy;
  const WellData({required this.wellIndex, required this.totalCells,
    required this.aliveCells, required this.deadCells, required this.drug,
    required this.category, required this.framePng, required this.viability,
    required this.efficacy});
  factory WellData.fromJson(Map<String, dynamic> j) => WellData(
    wellIndex: j['well_index'], totalCells: j['total_cells'],
    aliveCells: j['alive_cells'], deadCells: j['dead_cells'],
    drug: j['drug'], category: j['category'],
    viability: (j['viability'] as num).toDouble(),
    efficacy: (j['efficacy'] as num).toDouble(),
    framePng: j['frame_b64'] ?? '',
  );
}

class RankedEntry {
  final int rank, wellIndex;
  final String drug, category;
  final double efficacy, viability;
  const RankedEntry({required this.rank, required this.wellIndex,
    required this.drug, required this.category,
    required this.efficacy, required this.viability});
  factory RankedEntry.fromJson(Map<String, dynamic> j) => RankedEntry(
    rank: j['rank'], wellIndex: j['well_index'],
    drug: j['drug'], category: j['category'],
    efficacy: (j['efficacy'] as num).toDouble(),
    viability: (j['viability'] as num).toDouble(),
  );
}

class OncologyPanel extends StatefulWidget {
  final bool unlocked;
  final ProtocolStatus runStatus;
  final String activeStepId;
  final Map<String, String> patient;
  final String technician;
  final VoidCallback onGoToProtocol;

  const OncologyPanel({
    super.key,
    required this.unlocked,
    required this.runStatus,
    required this.activeStepId,
    required this.patient,
    required this.technician,
    required this.onGoToProtocol,
  });
  @override
  State<OncologyPanel> createState() => _OncologyPanelState();
}

class _OncologyPanelState extends State<OncologyPanel> {
  List<WellData> _wells = [];
  List<RankedEntry> _ranked = [];
  String _bestDrug = '', _bestCategory = '';
  double _bestEfficacy = 0;
  bool _loading = false, _connected = false;
  bool _exportingReport = false;
  String _status = 'Idle';
  int? _selectedWell;
  final String _url = '${_BackendConfig.cellUrl}/api/analyze';

  @override
  void initState() { super.initState(); if (widget.unlocked) _analyze(); }

  @override
  void didUpdateWidget(OncologyPanel old) {
    super.didUpdateWidget(old);
    // Auto-fetch when protocol unlocks oncology for the first time
    if (!old.unlocked && widget.unlocked && _wells.isEmpty) _analyze();
  }

  Future<void> _analyze() async {
    if (!mounted) return;
    setState(() { _loading = true; _status = 'Analysing...'; });
    try {
      final r = await http.get(Uri.parse(_url)).timeout(const Duration(seconds: 60));
      if (!mounted) return;
      if (r.statusCode == 200) {
        final d = json.decode(r.body);
        setState(() {
          _bestDrug     = d['best_drug'];
          _bestCategory = d['best_category'];
          _bestEfficacy = (d['best_efficacy'] as num).toDouble();
          _ranked = (d['ranked'] as List).map((e) => RankedEntry.fromJson(e)).toList();
          _wells  = (d['wells']  as List).map((e) => WellData.fromJson(e)).toList();
          _connected = true; _status = 'Complete'; _loading = false;
          _selectedWell ??= _ranked.isNotEmpty ? _ranked.first.wellIndex : 0;
        });
        // Save to session history
        SessionHistory.save(PatientSession(
          patientId:    widget.patient['id'] ?? '—',
          diagnosis:    widget.patient['diagnosis'] ?? '—',
          bestDrug:     d['best_drug'],
          bestCategory: d['best_category'],
          bestEfficacy: (d['best_efficacy'] as num).toDouble(),
          wellCount:    (d['wells'] as List).length,
          timestamp:    DateTime.now(),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _connected = false; _status = 'Error: $e'; _loading = false; });
    }
  }

  Color _wellColor(double efficacy) {
    if (efficacy >= 75) return const Color(0xFF1B8A5A);
    if (efficacy >= 60) return const Color(0xFF26C6A0);
    if (efficacy >= 45) return const Color(0xFFFFA726);
    if (efficacy >= 30) return const Color(0xFFFF7043);
    return const Color(0xFFEF5350);
  }

  @override
  Widget build(BuildContext context) {
    final t = themeNotifier.theme;
    // Show gate if protocol hasn't reached imaging yet
    if (!widget.unlocked) return _gateScreen();

    return Padding(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _recommendationBanner(),
      const SizedBox(height: 14),
      Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 5, child: Column(children: [
          Expanded(child: _heroFrame()),
          const SizedBox(height: 12),
          _wellStrip(),
        ])),
        const SizedBox(width: 14),
        SizedBox(width: 200, child: _rankedSidebar()),
      ])),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: appButton(
          icon: _loading ? Icons.hourglass_top_rounded : Icons.biotech,
          label: _loading ? 'Analysing...' : 'Run Analysis',
          color: const Color(0xFF1B8A5A),
          onTap: _loading ? () {} : _analyze,
        )),
        const SizedBox(width: 12),
        Expanded(child: appButton(
          icon: _exportingReport ? Icons.hourglass_top_rounded : Icons.picture_as_pdf_outlined,
          label: _exportingReport ? 'Generating…' : 'Export Report',
          color: const Color(0xFF388BFF),
          onTap: (_exportingReport || _bestDrug.isEmpty) ? () {} : () => _showReport(context),
        )),
        const SizedBox(width: 12),
        Expanded(child: appButton(
          icon: Icons.history_rounded,
          label: 'History',
          color: const Color(0xFF9C27B0),
          onTap: () => _showHistory(context),
        )),
        const SizedBox(width: 12),
        Align(alignment: Alignment.centerRight,
            child: statusBadge(_connected, _status,
                onTap: _connected ? null
                    : () => (!kIsWeb && Platform.isMacOS) ? launchDocker(context, 'cell-analyzer', 8081) : _analyze())),
      ]),
    ]),
  );
  }

  void _showHistory(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => SessionHistoryDialog(patientId: widget.patient['id'] ?? ''),
    );
  }

  void _showReport(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => OncologyReportDialog(
        patient: widget.patient,
        technician: widget.technician,
        wells: _wells,
        ranked: _ranked,
        bestDrug: _bestDrug,
        bestCategory: _bestCategory,
        bestEfficacy: _bestEfficacy,
      ),
    );
  }

  // ── Gate screen shown while protocol hasn't reached imaging ───────────────
  Widget _gateScreen() {
    final isRunning = widget.runStatus == ProtocolStatus.running ||
                      widget.runStatus == ProtocolStatus.paused;
    final isIdle    = widget.runStatus == ProtocolStatus.idle;

    // Work out which step we're waiting for
    final waitingFor = isIdle ? 'a run to be started'
        : 'Step: Fluorescence Imaging';

    final (icon, title, subtitle, btnLabel, btnColor) = isIdle
        ? (Icons.lock_outline_rounded,
           'No active run',
           'Start a protocol run first. Oncology results will be available once '
           'the Fluorescence Imaging step begins.',
           'Go to Protocol',
           const Color(0xFF388BFF))
        : (Icons.hourglass_top_rounded,
           'Awaiting imaging data',
           'The protocol is currently at: ${widget.activeStepId.replaceAll('_', ' ')}.\n'
           'Oncology results will unlock automatically once imaging is complete.',
           'View Protocol',
           const Color(0xFF388BFF));

    // Progress mini-strip showing which steps are done
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: themeNotifier.dark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: themeNotifier.dark ? AppColors.darkBorder : Colors.black12),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF388BFF).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: const Color(0xFF388BFF)),
            ),
            const SizedBox(height: 20),
            Text(title, style: TextStyle(fontSize: 20,
                fontWeight: FontWeight.w700, color: themeNotifier.dark ? AppColors.darkText : const Color(0xFF1A1A2E))),
            const SizedBox(height: 10),
            Text(subtitle, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12,
                    color: themeNotifier.dark ? AppColors.darkSubtext : Colors.black45, height: 1.65)),
            const SizedBox(height: 28),

            // Mini step pills showing protocol progress
            if (isRunning) ...[
              Text('Protocol progress',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                      color: themeNotifier.dark ? AppColors.darkMuted : Colors.black38)),
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center,
                children: [
                  '🧫 Intake', '⚗️ Dissociation', '💧 Droplets',
                  '💊 Drug Loading', '🌡 Incubation', '🔬 Imaging',
                ].asMap().entries.map((e) {
                  const unlockedAt = {'imaging', 'analysis'};
                  final stepIds = ['intake','dissociation','droplets',
                                   'drug_loading','incubation','imaging'];
                  final sid     = stepIds[e.key];
                  final isDone  = unlockedAt.contains(sid)
                      ? widget.unlocked
                      : _isStepDone(sid);
                  final isAct   = widget.activeStepId == sid;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDone
                          ? const Color(0xFF26C6A0).withOpacity(0.12)
                          : isAct
                              ? const Color(0xFF388BFF).withOpacity(0.10)
                              : const Color(0xFFF3F3F3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDone
                            ? const Color(0xFF26C6A0).withOpacity(0.5)
                            : isAct
                                ? const Color(0xFF388BFF).withOpacity(0.4)
                                : Colors.black12,
                      ),
                    ),
                    child: Text(e.value, style: TextStyle(
                      fontSize: 10,
                      color: isDone
                          ? const Color(0xFF26C6A0)
                          : isAct
                              ? const Color(0xFF388BFF)
                              : Colors.black38,
                      fontWeight: isAct || isDone
                          ? FontWeight.w700 : FontWeight.normal,
                    )),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],

            GestureDetector(
              onTap: widget.onGoToProtocol,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 13),
                decoration: BoxDecoration(
                  color: btnColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(isIdle
                      ? Icons.play_arrow_rounded
                      : Icons.arrow_forward_rounded,
                      size: 16, color: themeNotifier.dark ? AppColors.darkCard : Colors.white),
                  const SizedBox(width: 8),
                  Text(btnLabel, style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: themeNotifier.dark ? AppColors.darkCard : Colors.white)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  bool _isStepDone(String id) {
    // We don't have direct access to _steps here, so derive from activeStepId
    const order = ['intake','dissociation','droplets',
                   'drug_loading','incubation','imaging','analysis','report'];
    final activeIdx = order.indexOf(widget.activeStepId);
    final thisIdx   = order.indexOf(id);
    return activeIdx > thisIdx;
  }

  Widget _recommendationBanner() {
    final t = themeNotifier.theme;
    if (_bestDrug.isEmpty) return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: t.card,
          borderRadius: BorderRadius.circular(14), border: Border.all(color: t.border)),
      child: Row(children: [
        Icon(Icons.science_outlined, color: t.muted, size: 20),
        const SizedBox(width: 10),
        Text('Run an analysis to get a treatment recommendation',
            style: TextStyle(color: t.muted, fontSize: 13)),
      ]),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0D4F35), Color(0xFF1B8A5A)]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: const Color(0xFF1B8A5A).withOpacity(0.3),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.recommend_rounded, color: themeNotifier.dark ? AppColors.darkCard : Colors.white, size: 24)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('RECOMMENDED TREATMENT',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: Colors.white60, letterSpacing: 1.2)),
          const SizedBox(height: 2),
          Text(_bestDrug, style: TextStyle(fontSize: 20,
              fontWeight: FontWeight.w800, color: themeNotifier.dark ? AppColors.darkCard : Colors.white)),
          Text('$_bestCategory  ·  ${_bestEfficacy.toStringAsFixed(1)}% tumour cell kill rate',
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            Text('${_bestEfficacy.toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: themeNotifier.dark ? AppColors.darkCard : Colors.white)),
            const Text('efficacy', style: TextStyle(fontSize: 10, color: Colors.white60)),
          ]),
        ),
      ]),
    );
  }

  Widget _heroFrame() {
    final w = _wells.isEmpty ? null
        : _wells.firstWhere((x) => x.wellIndex == (_selectedWell ?? 0),
            orElse: () => _wells.first);
    final col = w != null ? _wellColor(w.efficacy) : Colors.black26;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: themeNotifier.dark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: w != null ? col.withOpacity(0.4) : Colors.black12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: w == null
            ? Center(child: Text('Run analysis to see frames',
                style: TextStyle(color: themeNotifier.dark ? AppColors.darkMuted : Colors.black26, fontSize: 13)))
            : Stack(fit: StackFit.expand, children: [
                w.framePng.isNotEmpty
                    ? Image.memory(base64Decode(w.framePng), fit: BoxFit.contain)
                    : const Center(child: CircularProgressIndicator()),
                Positioned(top: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0.55), Colors.transparent])),
                    child: Row(children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(6)),
                        child: Text('Well ${w.wellIndex + 1}',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                color: themeNotifier.dark ? AppColors.darkCard : Colors.white))),
                      const SizedBox(width: 10),
                      Expanded(child: Text(w.drug, style: const TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w700, color: Colors.white))),
                      Text(w.category, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                    ]),
                  )),
                Positioned(bottom: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(gradient: LinearGradient(
                      begin: Alignment.bottomCenter, end: Alignment.topCenter,
                      colors: [Colors.black.withOpacity(0.6), Colors.transparent])),
                    child: Row(children: [
                      _overlayBadge('Efficacy', '${w.efficacy.toStringAsFixed(1)}%', col),
                      const SizedBox(width: 10),
                      _overlayBadge('Alive', '${w.aliveCells}', const Color(0xFFEF5350)),
                      const SizedBox(width: 10),
                      _overlayBadge('Dead', '${w.deadCells}', const Color(0xFF26C6A0)),
                      const SizedBox(width: 10),
                      _overlayBadge('Total', '${w.totalCells}', Colors.white54),
                      const Spacer(),
                      Row(children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(
                            color: Color(0xFF3CC83C), shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        const Text('Alive', style: TextStyle(fontSize: 10, color: Colors.white70)),
                        const SizedBox(width: 10),
                        Container(width: 8, height: 8, decoration: const BoxDecoration(
                            color: Color(0xFF3C3CDC), shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        const Text('Dead', style: TextStyle(fontSize: 10, color: Colors.white70)),
                      ]),
                    ]),
                  )),
              ]),
      ),
    );
  }

  Widget _overlayBadge(String label, String value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 9, color: Colors.white54, letterSpacing: 0.5)),
      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
    ],
  );

  Widget _wellStrip() => SizedBox(
    height: 72,
    child: _wells.isEmpty
        ? Center(child: Text('No data', style: TextStyle(color: themeNotifier.dark ? AppColors.darkMuted : Colors.black26)))
        : ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _wells.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => _stripTile(_wells[i]),
          ),
  );

  Widget _stripTile(WellData w) {
    final isSelected = _selectedWell == w.wellIndex;
    final isBest = _ranked.isNotEmpty && _ranked.first.wellIndex == w.wellIndex;
    final col = _wellColor(w.efficacy);
    return GestureDetector(
      onTap: () => setState(() => _selectedWell = w.wellIndex),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 68,
        decoration: BoxDecoration(
          color: col.withOpacity(isSelected ? 0.2 : 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? col : col.withOpacity(0.35),
              width: isSelected ? 2.5 : 1)),
        child: Stack(children: [
          Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${w.efficacy.toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: col)),
            const SizedBox(height: 2),
            Text(w.drug.length > 7 ? '${w.drug.substring(0, 7)}…' : w.drug,
                style: TextStyle(fontSize: 8, color: themeNotifier.dark ? AppColors.darkSubtext : Colors.black45),
                textAlign: TextAlign.center),
          ])),
          if (isBest) Positioned(top: 3, right: 3,
              child: Icon(Icons.star_rounded, size: 11, color: col)),
        ]),
      ),
    );
  }

  Widget _rankedSidebar() { final t = themeNotifier.theme; return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: t.card,
        borderRadius: BorderRadius.circular(16), border: Border.all(color: t.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Top 5 Treatments',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.text)),
      Text('by tumour cell kill rate',
          style: TextStyle(fontSize: 10, color: t.muted)),
      const SizedBox(height: 12),
      if (_ranked.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text('...', style: TextStyle(color: t.muted)))),
      Expanded(child: Column(children: _ranked.isEmpty ? []
          : _ranked.map((r) => Expanded(child: _rankedRow(r))).toList())),
    ]),
  ); }

  Widget _rankedRow(RankedEntry r) {
    final t = themeNotifier.theme;
    final col = _wellColor(r.efficacy);
    final isTop = r.rank == 1;
    final isSel = _selectedWell == r.wellIndex;
    return GestureDetector(
      onTap: () => setState(() => _selectedWell = r.wellIndex),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? col.withOpacity(0.12) : (isTop
              ? const Color(0xFF1B8A5A).withOpacity(0.07) : Colors.transparent),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSel ? col : (isTop
              ? const Color(0xFF1B8A5A).withOpacity(0.4) : Colors.black12)),
        ),
        child: Row(children: [
          Container(width: 26, height: 26,
            decoration: BoxDecoration(
              color: isTop ? const Color(0xFF1B8A5A) : col.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6)),
            child: Center(child: Text('${r.rank}', style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800,
                color: isTop ? Colors.white : col)))),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(r.drug, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: t.text), overflow: TextOverflow.ellipsis),
            Text(r.category, style: TextStyle(fontSize: 9, color: t.muted),
                overflow: TextOverflow.ellipsis),
          ])),
          Text('${r.efficacy.toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: col)),
        ]),
      ),
    );
  }
}

// ── Oncology Report Dialog ───────────────────────────────────────────────────
class OncologyReportDialog extends StatefulWidget {
  final Map<String, String> patient;
  final String technician;
  final List<WellData> wells;
  final List<RankedEntry> ranked;
  final String bestDrug, bestCategory;
  final double bestEfficacy;

  const OncologyReportDialog({
    super.key,
    required this.patient,
    required this.technician,
    required this.wells,
    required this.ranked,
    required this.bestDrug,
    required this.bestCategory,
    required this.bestEfficacy,
  });

  @override
  State<OncologyReportDialog> createState() => _OncologyReportDialogState();
}

class _OncologyReportDialogState extends State<OncologyReportDialog> {
  bool _exporting = false;
  String? _exportedPath;

  String get _dateStr {
    final n = DateTime.now();
    return '${n.day.toString().padLeft(2,'0')}/${n.month.toString().padLeft(2,'0')}/${n.year}'
        '  ${n.hour.toString().padLeft(2,'0')}:${n.minute.toString().padLeft(2,'0')}';
  }

  Color _efficacyColor(double e) {
    if (e >= 75) return const Color(0xFF1B8A5A);
    if (e >= 60) return const Color(0xFF26C6A0);
    if (e >= 45) return const Color(0xFFFFA726);
    if (e >= 30) return const Color(0xFFFF7043);
    return const Color(0xFFEF5350);
  }

  // ── PDF export ─────────────────────────────────────────────────────────────
  Future<void> _exportPdf() async {
    setState(() { _exporting = true; _exportedPath = null; });
    try {
      final now = DateTime.now();
      const navy  = PdfColor.fromInt(0xFF1A1A2E);
      const green = PdfColor.fromInt(0xFF1B8A5A);
      const mint  = PdfColor.fromInt(0xFF26C6A0);
      const blue  = PdfColor.fromInt(0xFF388BFF);
      const amber = PdfColor.fromInt(0xFFFFA726);
      const red   = PdfColor.fromInt(0xFFEF5350);
      const grey  = PdfColor.fromInt(0xFF9E9E9E);
      const lightBg = PdfColor.fromInt(0xFFF8F9FF);
      const rowAlt  = PdfColor.fromInt(0xFFF3F3F3);

      final ttRegular = await PdfGoogleFonts.interRegular();
      final ttBold    = await PdfGoogleFonts.interBold();
      final ttMono    = await PdfGoogleFonts.sourceCodeProRegular();

      pw.TextStyle ts(double size, {pw.Font? font, PdfColor? color, double? spacing}) =>
          pw.TextStyle(font: font ?? ttRegular, fontSize: size,
              color: color ?? navy, letterSpacing: spacing);

      PdfColor efficacyPdf(double e) {
        if (e >= 75) return green;
        if (e >= 60) return mint;
        if (e >= 45) return amber;
        if (e >= 30) return const PdfColor.fromInt(0xFFFF7043);
        return red;
      }

      final pdf = pw.Document(
        title: 'Oncology Results Report — ${widget.patient['id']}',
        author: widget.technician,
        creator: 'TheraMeDx1 Sampler',
      );

      // Pre-encode well images that are available
      final topWells = widget.ranked.take(5).toList();

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        build: (ctx) => [

          // ══ HEADER ══════════════════════════════════════════════════════
          pw.Container(
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
                color: navy, borderRadius: pw.BorderRadius.circular(10)),
            child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Oncology Results Report',
                    style: ts(16, font: ttBold, color: PdfColors.white)),
                pw.SizedBox(height: 3),
                pw.Text('TheraMeDx1 Sampler™  —  Cell Viability & Drug Efficacy Analysis',
                    style: ts(9, color: PdfColor.fromInt(0x88FFFFFF))),
              ]),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: pw.BoxDecoration(
                  color: green.shade(0.25),
                  borderRadius: pw.BorderRadius.circular(20),
                  border: pw.Border.all(color: green),
                ),
                child: pw.Text('ANALYSIS COMPLETE',
                    style: ts(8, font: ttBold, color: green)),
              ),
            ]),
          ),

          pw.SizedBox(height: 14),

          // Meta chips
          pw.Row(children: [
            _pdfChip(ttRegular, 'Date: $_dateStr', 9),
            pw.SizedBox(width: 8),
            _pdfChip(ttRegular, 'Analyst: ${widget.technician}', 9),
            pw.SizedBox(width: 8),
            _pdfChip(ttRegular, '${widget.wells.length} wells analysed', 9),
          ]),

          pw.SizedBox(height: 18),

          // ══ PATIENT ══════════════════════════════════════════════════════
          _pdfSectionLabel(ttBold, 'Patient', blue),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(color: lightBg,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColor.fromInt(0xFFE0E0E0))),
            child: pw.Row(children: [
              _pdfKV(ttRegular, ttBold, 'Patient ID', widget.patient['id'] ?? '—'),
              pw.SizedBox(width: 24),
              _pdfKV(ttRegular, ttBold, 'Age', widget.patient['age'] ?? '—'),
              pw.SizedBox(width: 24),
              pw.Expanded(child: _pdfKV(ttRegular, ttBold,
                  'Diagnosis', widget.patient['diagnosis'] ?? '—')),
            ]),
          ),

          pw.SizedBox(height: 18),

          // ══ RECOMMENDATION ════════════════════════════════════════════════
          _pdfSectionLabel(ttBold, 'Treatment Recommendation', blue),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              gradient: const pw.LinearGradient(
                  colors: [PdfColor.fromInt(0xFF0D4F35), PdfColor.fromInt(0xFF1B8A5A)]),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Row(children: [
              pw.Expanded(child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('RECOMMENDED TREATMENT',
                    style: ts(8, font: ttBold,
                        color: PdfColor.fromInt(0x99FFFFFF), spacing: 1.2)),
                pw.SizedBox(height: 4),
                pw.Text(widget.bestDrug,
                    style: ts(20, font: ttBold, color: PdfColors.white)),
                pw.SizedBox(height: 2),
                pw.Text('${widget.bestCategory}  ·  Tumour cell kill rate',
                    style: ts(10, color: PdfColor.fromInt(0xCCFFFFFF))),
              ])),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0x33FFFFFF),
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Column(children: [
                  pw.Text('${widget.bestEfficacy.toStringAsFixed(0)}%',
                      style: ts(26, font: ttBold, color: PdfColors.white)),
                  pw.Text('efficacy',
                      style: ts(9, color: PdfColor.fromInt(0xAAFFFFFF))),
                ]),
              ),
            ]),
          ),

          pw.SizedBox(height: 18),

          // ══ SUMMARY STATS ═════════════════════════════════════════════════
          _pdfSectionLabel(ttBold, 'Analysis Summary', blue),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            _pdfStatCard(ttRegular, ttBold, 'Wells Tested',
                '${widget.wells.length}', blue),
            pw.SizedBox(width: 8),
            _pdfStatCard(ttRegular, ttBold, 'Best Efficacy',
                '${widget.bestEfficacy.toStringAsFixed(1)}%', green),
            pw.SizedBox(width: 8),
            _pdfStatCard(ttRegular, ttBold, 'Avg Efficacy',
                widget.wells.isEmpty ? '—'
                : '${(widget.wells.fold(0.0,(a,b)=>a+b.efficacy)/widget.wells.length).toStringAsFixed(1)}%',
                blue),
            pw.SizedBox(width: 8),
            _pdfStatCard(ttRegular, ttBold, 'Avg Viability',
                widget.wells.isEmpty ? '—'
                : '${(widget.wells.fold(0.0,(a,b)=>a+b.viability)/widget.wells.length).toStringAsFixed(1)}%',
                mint),
          ]),

          pw.SizedBox(height: 18),

          // ══ TOP 5 RANKED DRUGS TABLE ══════════════════════════════════════
          _pdfSectionLabel(ttBold, 'Top Drug Rankings', blue),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(
                color: PdfColor.fromInt(0xFFE0E0E0), width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(28),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FixedColumnWidth(60),
              4: const pw.FixedColumnWidth(60),
              5: const pw.FixedColumnWidth(50),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: rowAlt),
                children: ['Rank','Drug','Category','Efficacy','Viability','Well']
                    .map((h) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  child: pw.Text(h, style: ts(7.5, font: ttBold,
                      color: grey, spacing: 0.4)),
                )).toList(),
              ),
              ...widget.ranked.take(10).toList().asMap().entries.map((e) {
                final r = e.value;
                final ec = efficacyPdf(r.efficacy);
                final bg = e.key.isOdd ? PdfColors.white : rowAlt;
                pw.Widget cell(pw.Widget w) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: w);
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    cell(pw.Container(
                      width: 18, height: 18,
                      decoration: pw.BoxDecoration(
                        color: r.rank == 1 ? green : ec.shade(0.15),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Center(child: pw.Text('${r.rank}',
                          style: ts(9, font: ttBold,
                              color: r.rank == 1 ? PdfColors.white : ec))),
                    )),
                    cell(pw.Text(r.drug,
                        style: ts(10, font: ttBold))),
                    cell(pw.Text(r.category,
                        style: ts(9, color: grey))),
                    cell(pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: pw.BoxDecoration(
                        color: ec.shade(0.12),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text('${r.efficacy.toStringAsFixed(1)}%',
                          style: ts(10, font: ttBold, color: ec)),
                    )),
                    cell(pw.Text('${r.viability.toStringAsFixed(1)}%',
                        style: ts(9, color: grey))),
                    cell(pw.Text('W${r.wellIndex + 1}',
                        style: ts(9, font: ttMono, color: grey))),
                  ],
                );
              }),
            ],
          ),

          pw.SizedBox(height: 18),

          // ══ FULL WELL DATA TABLE ══════════════════════════════════════════
          _pdfSectionLabel(ttBold, 'Complete Well Data', blue),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(
                color: PdfColor.fromInt(0xFFE0E0E0), width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(28),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FixedColumnWidth(50),
              4: const pw.FixedColumnWidth(50),
              5: const pw.FixedColumnWidth(40),
              6: const pw.FixedColumnWidth(40),
              7: const pw.FixedColumnWidth(40),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: rowAlt),
                children: ['Well','Drug','Category','Efficacy','Viability','Total','Alive','Dead']
                    .map((h) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                  child: pw.Text(h, style: ts(7, font: ttBold,
                      color: grey, spacing: 0.3)),
                )).toList(),
              ),
              ...widget.wells.asMap().entries.map((e) {
                final w = e.value;
                final ec = efficacyPdf(w.efficacy);
                final bg = e.key.isOdd ? PdfColors.white : rowAlt;
                pw.Widget cell(pw.Widget wd) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                    child: wd);
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    cell(pw.Text('W${w.wellIndex + 1}',
                        style: ts(8, font: ttMono, color: grey))),
                    cell(pw.Text(w.drug, style: ts(8, font: ttBold))),
                    cell(pw.Text(w.category, style: ts(8, color: grey))),
                    cell(pw.Text('${w.efficacy.toStringAsFixed(1)}%',
                        style: ts(9, font: ttBold, color: ec))),
                    cell(pw.Text('${w.viability.toStringAsFixed(1)}%',
                        style: ts(8, color: grey))),
                    cell(pw.Text('${w.totalCells}', style: ts(8))),
                    cell(pw.Text('${w.aliveCells}',
                        style: ts(8, color: PdfColor.fromInt(0xFFEF5350)))),
                    cell(pw.Text('${w.deadCells}',
                        style: ts(8, color: mint))),
                  ],
                );
              }),
            ],
          ),

          pw.SizedBox(height: 20),

          // ══ CLINICAL NOTE ════════════════════════════════════════════════
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: green.shade(0.06),
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: green.shade(0.3), width: 0.8),
            ),
            child: pw.Row(children: [
              pw.Container(width: 8, height: 8,
                  decoration: pw.BoxDecoration(color: green, shape: pw.BoxShape.circle)),
              pw.SizedBox(width: 10),
              pw.Expanded(child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Analysis validated. Recommended treatment: ${widget.bestDrug}',
                    style: ts(10, font: ttBold)),
                pw.SizedBox(height: 2),
                pw.Text('Analyst: ${widget.technician}  ·  $_dateStr',
                    style: ts(8, color: grey)),
              ])),
            ]),
          ),

          pw.SizedBox(height: 16),
          pw.Divider(color: PdfColor.fromInt(0xFFE0E0E0), thickness: 0.5),
          pw.SizedBox(height: 6),
          pw.Text(
            'This report is generated automatically by the TheraMeDx1 Sampler™ software. '
            'Drug efficacy values are based on in-vitro cell viability assays and are intended '
            'for research use only. Not for direct clinical use without physician review.',
            style: ts(7.5, color: grey),
          ),
        ],
      ));

      final pdfBytes = await pdf.save();
      final now2 = DateTime.now();
      final fname = 'oncology_report_${widget.patient['id']}_'
          '${now2.year}${now2.month.toString().padLeft(2,'0')}'
          '${now2.day.toString().padLeft(2,'0')}'
          '_${now2.hour.toString().padLeft(2,'0')}'
          '${now2.minute.toString().padLeft(2,'0')}.pdf';
      if (kIsWeb) {
        await Printing.layoutPdf(onLayout: (_) async => pdfBytes, name: fname);
        setState(() { _exporting = false; _exportedPath = fname; });
      } else {
        final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fname');
        await file.writeAsBytes(pdfBytes);
        setState(() { _exporting = false; _exportedPath = file.path; });
        if (Platform.isMacOS) await Process.run('open', [file.path]);
        else if (Platform.isLinux) await Process.run('xdg-open', [file.path]);
        else if (Platform.isWindows) await Process.run('start', [file.path], runInShell: true);
      }
    } catch (e) {
      setState(() => _exporting = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Export failed: $e'),
        backgroundColor: const Color(0xFFEF5350),
      ));
    }
  }

  // ── PDF helpers (reused from protocol report) ─────────────────────────────
  pw.Widget _pdfChip(pw.Font font, String label, double size) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFF3F3F3),
            borderRadius: pw.BorderRadius.circular(6)),
        child: pw.Text(label, style: pw.TextStyle(font: font, fontSize: size,
            color: PdfColor.fromInt(0xFF666666))),
      );

  pw.Widget _pdfSectionLabel(pw.Font bold, String text, PdfColor col) =>
      pw.Row(children: [
        pw.Container(width: 3, height: 12,
            decoration: pw.BoxDecoration(color: col,
                borderRadius: pw.BorderRadius.circular(2))),
        pw.SizedBox(width: 7),
        pw.Text(text, style: pw.TextStyle(font: bold, fontSize: 11,
            color: PdfColor.fromInt(0xFF1A1A2E), letterSpacing: 0.4)),
      ]);

  pw.Widget _pdfKV(pw.Font reg, pw.Font bold, String key, String val) =>
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(key, style: pw.TextStyle(font: bold, fontSize: 7.5,
            color: PdfColor.fromInt(0xFF999999), letterSpacing: 0.4)),
        pw.SizedBox(height: 3),
        pw.Text(val, style: pw.TextStyle(font: bold, fontSize: 11,
            color: PdfColor.fromInt(0xFF1A1A2E))),
      ]);

  pw.Widget _pdfStatCard(pw.Font reg, pw.Font bold,
      String label, String value, PdfColor col) =>
      pw.Expanded(child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: pw.BoxDecoration(
          color: col.shade(0.08),
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: col.shade(0.25), width: 0.5),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label, style: pw.TextStyle(font: bold, fontSize: 7.5,
              color: col.shade(0.6), letterSpacing: 0.4)),
          pw.SizedBox(height: 3),
          pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 16, color: col)),
        ]),
      ));

  // ── Flutter UI ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 780),
        decoration: BoxDecoration(
          color: false ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25),
              blurRadius: 40, offset: const Offset(0, 12))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // ── Header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A2E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF1B8A5A).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.biotech, color: Color(0xFF26C6A0), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Oncology Results Report',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: false ? AppColors.darkCard : Colors.white)),
                Text('TheraMeDx1 Sampler™  —  Cell Viability & Drug Efficacy',
                    style: TextStyle(fontSize: 10, color: Colors.white38)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF26C6A0).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF26C6A0).withOpacity(0.5)),
                ),
                child: const Text('ANALYSIS COMPLETE', style: TextStyle(fontSize: 9,
                    fontWeight: FontWeight.w800, color: Color(0xFF26C6A0))),
              ),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: Colors.white38, size: 18),
              ),
            ]),
          ),

          // ── Body ──
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Meta row
                Row(children: [
                  _chip(Icons.calendar_today_outlined, _dateStr),
                  const SizedBox(width: 8),
                  _chip(Icons.person_outline, 'Analyst: ${widget.technician}'),
                  const SizedBox(width: 8),
                  _chip(Icons.science_outlined, '${widget.wells.length} wells'),
                ]),
                const SizedBox(height: 20),

                // Patient card
                _sectionLabel('Patient'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: false ? AppColors.darkElevated : const Color(0xFFF8F9FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: false ? AppColors.darkBorder : Colors.black12)),
                  child: Row(children: [
                    Expanded(child: _kv('Patient ID', widget.patient['id'] ?? '—')),
                    Expanded(child: _kv('Age', widget.patient['age'] ?? '—')),
                    Expanded(flex: 2, child: _kv('Diagnosis', widget.patient['diagnosis'] ?? '—')),
                  ]),
                ),
                const SizedBox(height: 20),

                // Recommendation banner
                _sectionLabel('Treatment Recommendation'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF0D4F35), Color(0xFF1B8A5A)]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: const Color(0xFF1B8A5A).withOpacity(0.3),
                        blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Row(children: [
                    Container(padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.recommend_rounded,
                          color: false ? AppColors.darkCard : Colors.white, size: 24)),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('RECOMMENDED TREATMENT', style: TextStyle(fontSize: 9,
                          fontWeight: FontWeight.w700, color: Colors.white60, letterSpacing: 1.2)),
                      const SizedBox(height: 4),
                      Text(widget.bestDrug, style: TextStyle(fontSize: 22,
                          fontWeight: FontWeight.w800, color: false ? AppColors.darkCard : Colors.white)),
                      Text('${widget.bestCategory}  ·  ${widget.bestEfficacy.toStringAsFixed(1)}% tumour cell kill rate',
                          style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10)),
                      child: Column(children: [
                        Text('${widget.bestEfficacy.toStringAsFixed(0)}%',
                            style: TextStyle(fontSize: 26,
                                fontWeight: FontWeight.w800, color: false ? AppColors.darkCard : Colors.white)),
                        const Text('efficacy', style: TextStyle(fontSize: 10,
                            color: Colors.white60)),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),

                // Summary stats
                _sectionLabel('Analysis Summary'),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _statCard('Wells Tested',
                      '${widget.wells.length}', const Color(0xFF388BFF))),
                  const SizedBox(width: 10),
                  Expanded(child: _statCard('Best Efficacy',
                      '${widget.bestEfficacy.toStringAsFixed(1)}%',
                      const Color(0xFF1B8A5A))),
                  const SizedBox(width: 10),
                  Expanded(child: _statCard('Avg Efficacy',
                      widget.wells.isEmpty ? '—'
                      : '${(widget.wells.fold(0.0,(a,b)=>a+b.efficacy)/widget.wells.length).toStringAsFixed(1)}%',
                      const Color(0xFF388BFF))),
                  const SizedBox(width: 10),
                  Expanded(child: _statCard('Avg Viability',
                      widget.wells.isEmpty ? '—'
                      : '${(widget.wells.fold(0.0,(a,b)=>a+b.viability)/widget.wells.length).toStringAsFixed(1)}%',
                      const Color(0xFF26C6A0))),
                ]),
                const SizedBox(height: 20),

                // Top rankings table
                _sectionLabel('Drug Rankings'),
                const SizedBox(height: 8),
                _rankingsTable(),
                const SizedBox(height: 20),

                // Full well data
                _sectionLabel('Complete Well Data'),
                const SizedBox(height: 8),
                _wellTable(),
                const SizedBox(height: 8),

                // Disclaimer
                Text(
                  'Drug efficacy values are based on in-vitro cell viability assays. '
                  'Not for direct clinical use without physician review.',
                  style: TextStyle(fontSize: 9, color: false ? AppColors.darkMuted : Colors.black26,
                      fontStyle: FontStyle.italic, height: 1.5),
                ),
              ]),
            ),
          ),

          // ── Footer ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.black.withOpacity(0.07)))),
            child: Row(children: [
              if (_exportedPath != null) ...[
                const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF26C6A0)),
                const SizedBox(width: 6),
                Expanded(child: Text(
                  'Saved: ${_exportedPath!.split('/').last}',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF26C6A0)),
                  overflow: TextOverflow.ellipsis)),
              ] else
                const Expanded(child: SizedBox()),
              GestureDetector(
                onTap: _exporting ? null : _exportPdf,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: _exporting ? Colors.black12 : const Color(0xFF388BFF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _exporting
                        ? SizedBox(width: 13, height: 13,
                            child: CircularProgressIndicator(strokeWidth: 2, color: false ? AppColors.darkCard : Colors.white))
                        : Icon(Icons.picture_as_pdf_outlined, size: 14, color: false ? AppColors.darkCard : Colors.white),
                    const SizedBox(width: 7),
                    Text(_exporting ? 'Generating…' : 'Export PDF',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                            color: false ? AppColors.darkCard : Colors.white)),
                  ]),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: TextStyle(color: false ? AppColors.darkSubtext : Colors.black45)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String text) => Row(children: [
    Container(width: 3, height: 14, decoration: BoxDecoration(
        color: const Color(0xFF388BFF), borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
        color: Color(0xFF1A1A2E), letterSpacing: 0.5)),
  ]);

  Widget _chip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: false ? AppColors.darkSurface : const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: false ? AppColors.darkMuted : Colors.black38),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 10, color: false ? AppColors.darkSubtext : Colors.black45)),
    ]),
  );

  Widget _kv(String key, String val) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(key, style: TextStyle(fontSize: 9, color: false ? AppColors.darkMuted : Colors.black38,
        fontWeight: FontWeight.w700, letterSpacing: 0.4)),
    const SizedBox(height: 3),
    Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
        color: false ? AppColors.darkText : const Color(0xFF1A1A2E))),
  ]);

  Widget _statCard(String label, String value, Color col) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    decoration: BoxDecoration(
      color: col.withOpacity(0.07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: col.withOpacity(0.2)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
          color: col.withOpacity(0.7), letterSpacing: 0.5)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: col)),
    ]),
  );

  Widget _rankingsTable() {
    final t = AppTheme(false); // forced light for report
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
          border: Border.all(color: false ? AppColors.darkBorder : Colors.black12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Table(
          columnWidths: const {
            0: FixedColumnWidth(40),
            1: FlexColumnWidth(3),
            2: FlexColumnWidth(2),
            3: FixedColumnWidth(80),
            4: FixedColumnWidth(80),
            5: FixedColumnWidth(50),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: t.dark ? AppColors.darkElevated : const Color(0xFFF3F3F3)),
              children: ['Rank','Drug','Category','Efficacy','Viability','Well']
                  .map((h) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Text(h, style: TextStyle(fontSize: 9,
                    fontWeight: FontWeight.w800, color: t.muted, letterSpacing: 0.5)),
              )).toList(),
            ),
            ...widget.ranked.take(10).toList().asMap().entries.map((e) {
              final r = e.value;
              final col = _efficacyColor(r.efficacy);
              final bg = e.key.isOdd ? (t.dark ? AppColors.darkCard : Colors.white) : (t.dark ? AppColors.darkSurface : const Color(0xFFFAFAFA));
              Widget cell(Widget w) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  child: w);
              return TableRow(
                decoration: BoxDecoration(color: bg),
                children: [
                  cell(Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: r.rank == 1 ? const Color(0xFF1B8A5A) : col.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(child: Text('${r.rank}', style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800,
                        color: r.rank == 1 ? Colors.white : col))),
                  )),
                  cell(Text(r.drug, style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w700, color: false ? AppColors.darkText : const Color(0xFF1A1A2E)))),
                  cell(Text(r.category, style: TextStyle(
                      fontSize: 10, color: false ? AppColors.darkSubtext : Colors.black45))),
                  cell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: col.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(5)),
                    child: Text('${r.efficacy.toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: col)),
                  )),
                  cell(Text('${r.viability.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 10, color: false ? AppColors.darkSubtext : Colors.black45))),
                  cell(Text('W${r.wellIndex + 1}', style: TextStyle(
                      fontSize: 10, fontFamily: 'monospace', color: false ? AppColors.darkMuted : Colors.black38))),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _wellTable() {
    final t = AppTheme(false); // forced light for report
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
          border: Border.all(color: false ? AppColors.darkBorder : Colors.black12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Table(
          columnWidths: const {
            0: FixedColumnWidth(40),
            1: FlexColumnWidth(3),
            2: FlexColumnWidth(2),
            3: FixedColumnWidth(70),
            4: FixedColumnWidth(70),
            5: FixedColumnWidth(50),
            6: FixedColumnWidth(50),
            7: FixedColumnWidth(50),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: t.dark ? AppColors.darkElevated : const Color(0xFFF3F3F3)),
              children: ['Well','Drug','Category','Efficacy','Viability','Total','Alive','Dead']
                  .map((h) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                child: Text(h, style: TextStyle(fontSize: 8,
                    fontWeight: FontWeight.w800, color: false ? AppColors.darkMuted : Colors.black38, letterSpacing: 0.4)),
              )).toList(),
            ),
            ...widget.wells.asMap().entries.map((e) {
              final w = e.value;
              final col = _efficacyColor(w.efficacy);
              final bg = e.key.isOdd ? Colors.white : const Color(0xFFFAFAFA);
              Widget cell(Widget wd) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: wd);
              return TableRow(
                decoration: BoxDecoration(color: bg),
                children: [
                  cell(Text('W${w.wellIndex + 1}', style: TextStyle(
                      fontSize: 9, fontFamily: 'monospace', color: false ? AppColors.darkMuted : Colors.black38))),
                  cell(Text(w.drug, style: TextStyle(fontSize: 10,
                      fontWeight: FontWeight.w600, color: false ? AppColors.darkText : const Color(0xFF1A1A2E)))),
                  cell(Text(w.category, style: TextStyle(
                      fontSize: 9, color: false ? AppColors.darkSubtext : Colors.black45))),
                  cell(Text('${w.efficacy.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: col))),
                  cell(Text('${w.viability.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 9, color: false ? AppColors.darkSubtext : Colors.black45))),
                  cell(Text('${w.totalCells}', style: const TextStyle(
                      fontSize: 9, color: Colors.black54))),
                  cell(Text('${w.aliveCells}', style: const TextStyle(
                      fontSize: 9, color: Color(0xFFEF5350)))),
                  cell(Text('${w.deadCells}', style: const TextStyle(
                      fontSize: 9, color: Color(0xFF26C6A0)))),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Session History Dialog ───────────────────────────────────────────────────
class SessionHistoryDialog extends StatefulWidget {
  final String patientId;
  const SessionHistoryDialog({super.key, required this.patientId});
  @override
  State<SessionHistoryDialog> createState() => _SessionHistoryDialogState();
}

class _SessionHistoryDialogState extends State<SessionHistoryDialog> {
  List<PatientSession> _sessions = [];
  bool _loading = true;
  bool _showAll = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final all = await SessionHistory.load();
    setState(() {
      _sessions = _showAll ? all : all.where((s) => s.patientId == widget.patientId).toList();
      _loading = false;
    });
  }

  Future<void> _clearHistory() async {
    await SessionHistory.clear();
    setState(() { _sessions = []; });
  }

  Color _efficacyColor(double e) {
    if (e >= 75) return AppColors.green;
    if (e >= 60) return AppColors.mint;
    if (e >= 45) return AppColors.amber;
    if (e >= 30) return const Color(0xFFFF7043);
    return AppColors.red;
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}  '
           '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = themeNotifier.theme;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 560),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(t.dark ? 0.5 : 0.2),
              blurRadius: 40, offset: const Offset(0, 12))],
        ),
        child: Column(children: [

          // ── Header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            decoration: const BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF9C27B0).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.history_rounded, color: Color(0xFFCE93D8), size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Session History',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: themeNotifier.dark ? AppColors.darkCard : Colors.white)),
                Text(_showAll ? 'All patients' : 'Patient ${widget.patientId}',
                    style: const TextStyle(fontSize: 10, color: Colors.white38)),
              ])),

              // All / This patient toggle
              GestureDetector(
                onTap: () { setState(() { _showAll = !_showAll; _loading = true; }); _load(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(_showAll ? 'This patient' : 'All patients',
                      style: const TextStyle(fontSize: 10, color: Colors.white70,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: Colors.white38, size: 18),
              ),
            ]),
          ),

          // ── Body ──
          Expanded(child: _loading
            ? Center(child: CircularProgressIndicator(
                color: const Color(0xFF9C27B0), strokeWidth: 2))
            : _sessions.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.history_rounded, size: 40, color: t.muted),
                  const SizedBox(height: 12),
                  Text('No sessions recorded yet',
                      style: TextStyle(fontSize: 13, color: t.muted)),
                  const SizedBox(height: 6),
                  Text('Run an analysis to start tracking results',
                      style: TextStyle(fontSize: 11, color: t.muted)),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _sessions.length,
                  separatorBuilder: (_, __) => Divider(color: t.border, height: 1),
                  itemBuilder: (_, i) {
                    final s = _sessions[i];
                    final col = _efficacyColor(s.bestEfficacy);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(children: [
                        // Rank/index badge
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: i == 0 && !_showAll
                                ? AppColors.green.withOpacity(0.15)
                                : t.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: t.border),
                          ),
                          child: Center(child: Text('${i + 1}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                  color: i == 0 && !_showAll ? AppColors.green : t.muted))),
                        ),
                        const SizedBox(width: 14),

                        // Main info
                        Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            if (_showAll) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.purple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(s.patientId,
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                                        fontFamily: 'monospace',
                                        color: t.dark ? AppColors.darkSecondary : AppColors.purple)),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(child: Text(s.diagnosis,
                                style: TextStyle(fontSize: 11, color: t.muted),
                                overflow: TextOverflow.ellipsis)),
                          ]),
                          const SizedBox(height: 3),
                          Text(s.bestDrug,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                                  color: t.text)),
                          const SizedBox(height: 2),
                          Text('${s.bestCategory}  ·  ${s.wellCount} wells  ·  ${_formatDate(s.timestamp)}',
                              style: TextStyle(fontSize: 10, color: t.muted)),
                        ])),

                        const SizedBox(width: 14),

                        // Efficacy badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: col.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: col.withOpacity(0.3)),
                          ),
                          child: Column(children: [
                            Text('${s.bestEfficacy.toStringAsFixed(0)}%',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                                    color: col)),
                            Text('efficacy', style: TextStyle(fontSize: 8, color: t.muted)),
                          ]),
                        ),
                      ]),
                    );
                  },
                ),
          ),

          // ── Footer ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: t.border))),
            child: Row(children: [
              Text('${_sessions.length} session${_sessions.length == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 11, color: t.muted)),
              const Spacer(),
              if (_sessions.isNotEmpty)
                TextButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: t.card,
                        title: Text('Clear history?',
                            style: TextStyle(color: t.text, fontSize: 14)),
                        content: Text('This will delete all ${_sessions.length} sessions.',
                            style: TextStyle(color: t.muted, fontSize: 12)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(context, true),
                              child: const Text('Clear', style: TextStyle(color: AppColors.red))),
                        ],
                      ),
                    );
                    if (confirm == true) _clearHistory();
                  },
                  icon: const Icon(Icons.delete_outline, size: 14, color: AppColors.red),
                  label: const Text('Clear', style: TextStyle(fontSize: 11, color: AppColors.red)),
                ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9C27B0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Close', style: TextStyle(fontSize: 12)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── CSV Save Location Dialog ─────────────────────────────────────────────────
// Uses native OS file-save dialog (Finder on macOS, Explorer on Windows)
class _CsvSaveDialog extends StatefulWidget {
  final String defaultDir;
  final String defaultName;
  const _CsvSaveDialog({required this.defaultDir, required this.defaultName});
  @override
  State<_CsvSaveDialog> createState() => _CsvSaveDialogState();
}

class _CsvSaveDialogState extends State<_CsvSaveDialog> {
  late TextEditingController _nameCtrl;
  String? _chosenDir;   // null = use defaultDir
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    // Strip .csv suffix for display — we add it back on save
    final rawName = widget.defaultName.endsWith('.csv')
        ? widget.defaultName.substring(0, widget.defaultName.length - 4)
        : widget.defaultName;
    _nameCtrl = TextEditingController(text: rawName);
  }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  String get _activeDir => _chosenDir ?? widget.defaultDir;

  String get _fullPath {
    var name = _nameCtrl.text.trim();
    if (name.isEmpty) name = widget.defaultName;
    if (!name.endsWith('.csv')) name += '.csv';
    return '$_activeDir/$name';
  }

  Future<void> _pickFolder() async {
    if (kIsWeb) return;
    setState(() => _picking = true);
    try {
      String? picked;
      if (Platform.isMacOS) {
        // Use osascript to show native Finder folder picker
        final result = await Process.run('osascript', [
          '-e',
          'tell application "Finder" to set f to choose folder with prompt "Choose export folder:" default location POSIX file "$_activeDir"\nreturn POSIX path of f',
        ]);
        if (result.exitCode == 0) {
          picked = (result.stdout as String).trim().replaceAll(RegExp(r'/$'), '');
        }
      } else if (Platform.isLinux) {
        // Use zenity (available in all GTK desktops)
        final result = await Process.run('zenity', [
          '--file-selection', '--directory',
          '--title=Choose export folder',
          '--filename=$_activeDir/',
        ]);
        if (result.exitCode == 0) {
          picked = (result.stdout as String).trim().replaceAll(RegExp(r'/$'), '');
        }
      } else if (Platform.isWindows) {
        // PowerShell folder browser dialog
        final result = await Process.run('powershell', [
          '-command',
          '[System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null; \$f = New-Object System.Windows.Forms.FolderBrowserDialog; \$f.SelectedPath = "$_activeDir"; if(\$f.ShowDialog() -eq "OK") { Write-Output \$f.SelectedPath }',
        ], runInShell: true);
        if (result.exitCode == 0 && (result.stdout as String).trim().isNotEmpty) {
          picked = (result.stdout as String).trim();
        }
      }
      if (picked != null && picked.isNotEmpty) {
        setState(() => _chosenDir = picked);
      }
    } catch (_) {
      // silently ignore if native dialog not available
    } finally {
      setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = themeNotifier.theme;
    final dirDisplay = _activeDir.length > 42
        ? '…${_activeDir.substring(_activeDir.length - 42)}'
        : _activeDir;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(t.dark ? 0.4 : 0.18),
              blurRadius: 32, offset: const Offset(0, 10))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A2E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF388BFF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.download_outlined,
                    color: Color(0xFF388BFF), size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Export Sensor Data',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                        color: themeNotifier.dark ? AppColors.darkCard : Colors.white)),
                Text('Choose where to save the CSV file',
                    style: TextStyle(fontSize: 10, color: Colors.white38)),
              ])),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: Colors.white38, size: 16),
              ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Save folder row
              Text('Save to folder', style: TextStyle(fontSize: 10,
                  fontWeight: FontWeight.w700, color: themeNotifier.dark ? AppColors.darkSubtext : Colors.black45,
                  letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: themeNotifier.dark ? AppColors.darkElevated : const Color(0xFFF8F9FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: themeNotifier.dark ? AppColors.darkBorder : Colors.black12),
                    ),
                    child: Row(children: [
                      Icon(Icons.folder_outlined, size: 14, color: themeNotifier.dark ? AppColors.darkMuted : Colors.black38),
                      const SizedBox(width: 8),
                      Expanded(child: Text(dirDisplay,
                          style: const TextStyle(fontSize: 11,
                              fontFamily: 'monospace', color: Colors.black54),
                          overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _picking ? null : _pickFolder,
                  icon: _picking
                      ? SizedBox(width: 12, height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2,
                              color: themeNotifier.dark ? AppColors.darkCard : Colors.white))
                      : const Icon(Icons.folder_open_outlined, size: 14),
                  label: Text(_picking ? 'Opening…' : 'Browse…'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF170345),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ]),

              const SizedBox(height: 16),

              // Filename field
              Text('File name', style: TextStyle(fontSize: 10,
                  fontWeight: FontWeight.w700, color: themeNotifier.dark ? AppColors.darkSubtext : Colors.black45,
                  letterSpacing: 0.5)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.insert_drive_file_outlined,
                      size: 16, color: themeNotifier.dark ? AppColors.darkMuted : Colors.black38),
                  suffixText: '.csv',
                  suffixStyle: TextStyle(fontSize: 11, color: themeNotifier.dark ? AppColors.darkMuted : Colors.black38),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 11),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: themeNotifier.dark ? AppColors.darkBorder : Colors.black12)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: themeNotifier.dark ? AppColors.darkBorder : Colors.black12)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: Color(0xFF388BFF), width: 1.5)),
                ),
              ),

              const SizedBox(height: 10),

              // Full path preview
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF388BFF).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF388BFF).withOpacity(0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline, size: 12,
                      color: Color(0xFF388BFF)),
                  const SizedBox(width: 7),
                  Expanded(child: Text(_fullPath,
                      style: const TextStyle(fontSize: 10,
                          fontFamily: 'monospace', color: Colors.black54),
                      overflow: TextOverflow.ellipsis)),
                ]),
              ),

              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel',
                      style: TextStyle(color: themeNotifier.dark ? AppColors.darkMuted : Colors.black38)),
                )),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, _fullPath),
                  icon: const Icon(Icons.download_outlined, size: 15),
                  label: const Text('Save Here'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF388BFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                )),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Alarm Threshold Editor Dialog ────────────────────────────────────────────
class _AlarmThresholdDialog extends StatefulWidget {
  final Map<String, Map<String, double>> warningThresholds;
  final Map<String, Map<String, double>> criticalThresholds;
  final Map<String, String> units;
  final void Function(
    Map<String, Map<String, double>>,
    Map<String, Map<String, double>>,
  ) onSave;

  const _AlarmThresholdDialog({
    required this.warningThresholds,
    required this.criticalThresholds,
    required this.units,
    required this.onSave,
  });

  @override
  State<_AlarmThresholdDialog> createState() => _AlarmThresholdDialogState();
}

class _AlarmThresholdDialogState extends State<_AlarmThresholdDialog> {
  late Map<String, Map<String, double>> _warn;
  late Map<String, Map<String, double>> _crit;

  static const _labels = {
    'temperature': ('🌡', 'Temperature'),
    'humidity':    ('💧', 'Humidity'),
    'co2':         ('💨', 'CO₂'),
    'o2':          ('🫁', 'O₂'),
    'pressure':    ('⏱', 'Pressure'),
    'ph':          ('🧪', 'pH'),
  };

  @override
  void initState() {
    super.initState();
    // Deep copy so edits don't mutate originals until Save
    _warn = widget.warningThresholds.map((k, v) => MapEntry(k, Map.from(v)));
    _crit = widget.criticalThresholds.map((k, v) => MapEntry(k, Map.from(v)));
  }

  void _reset() => setState(() {
    _warn = {
      'temperature': {'lo': 36.0, 'hi': 38.0},
      'humidity':    {'lo': 90.0, 'hi': 98.0},
      'co2':         {'lo': 4.5,  'hi': 5.5},
      'o2':          {'lo': 19.0, 'hi': 22.0},
      'pressure':    {'lo': 1005.0,'hi': 1020.0},
      'ph':          {'lo': 7.2,  'hi': 7.6},
    };
    _crit = {
      'temperature': {'lo': 35.0, 'hi': 39.5},
      'humidity':    {'lo': 85.0, 'hi': 100.0},
      'co2':         {'lo': 3.5,  'hi': 7.0},
      'o2':          {'lo': 17.0, 'hi': 24.0},
      'pressure':    {'lo': 990.0,'hi': 1035.0},
      'ph':          {'lo': 6.8,  'hi': 7.8},
    };
  });

  @override
  Widget build(BuildContext context) {
    final t = themeNotifier.theme;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(t.dark ? 0.45 : 0.2),
              blurRadius: 40, offset: const Offset(0, 12))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // ── Header ──
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A2E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFA726).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.notifications_active_outlined,
                    color: Color(0xFFFFA726), size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Alarm Threshold Editor',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: themeNotifier.dark ? AppColors.darkCard : Colors.white)),
                Text('Warning and critical bands per sensor — values outside trigger alarms',
                    style: TextStyle(fontSize: 10, color: Colors.white38)),
              ])),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: Colors.white38, size: 18),
              ),
            ]),
          ),

          // ── Legend row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
            child: Row(children: [
              const Expanded(flex: 3, child: SizedBox()),
              _legendChip('WARNING', const Color(0xFFFFA726)),
              const SizedBox(width: 8),
              _legendChip('CRITICAL', const Color(0xFFEF5350)),
            ]),
          ),

          // ── Sensor rows ──
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              child: Column(
                children: _labels.keys.map((key) => _sensorRow(key)).toList(),
              ),
            ),
          ),

          // ── Footer ──
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
            child: Row(children: [
              TextButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.restart_alt, size: 14),
                label: const Text('Reset defaults'),
                style: TextButton.styleFrom(foregroundColor: themeNotifier.dark ? AppColors.darkSubtext : Colors.black38),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: themeNotifier.dark ? AppColors.darkMuted : Colors.black38)),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () {
                  widget.onSave(_warn, _crit);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.check, size: 15),
                label: const Text('Save Thresholds'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A2E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _legendChip(String label, Color col) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10,
        decoration: BoxDecoration(color: col.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: col, width: 1.5))),
    const SizedBox(width: 5),
    Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
        color: col, letterSpacing: 0.5)),
    const SizedBox(width: 40),
    Text('Lo', style: TextStyle(fontSize: 9, color: themeNotifier.dark ? AppColors.darkMuted : Colors.black38,
        fontWeight: FontWeight.w700)),
    const SizedBox(width: 52),
    Text('Hi', style: TextStyle(fontSize: 9, color: themeNotifier.dark ? AppColors.darkMuted : Colors.black38,
        fontWeight: FontWeight.w700)),
  ]);

  Widget _sensorRow(String key) {
    final (emoji, label) = _labels[key]!;
    final unit = widget.units[key] ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: themeNotifier.dark ? AppColors.darkElevated : const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeNotifier.dark ? AppColors.darkBorder : Colors.black12),
      ),
      child: Row(children: [
        // Label
        SizedBox(width: 110, child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12,
              fontWeight: FontWeight.w600, color: themeNotifier.dark ? AppColors.darkText : const Color(0xFF1A1A2E))),
        ])),

        // Warning band
        Expanded(child: Row(children: [
          _thresholdField(_warn[key]!['lo']!, const Color(0xFFFFA726), (v) =>
              setState(() => _warn[key]!['lo'] = v), unit),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text('–', style: TextStyle(color: themeNotifier.dark ? AppColors.darkMuted : Colors.black26))),
          _thresholdField(_warn[key]!['hi']!, const Color(0xFFFFA726), (v) =>
              setState(() => _warn[key]!['hi'] = v), unit),
        ])),

        const SizedBox(width: 16),

        // Critical band
        Expanded(child: Row(children: [
          _thresholdField(_crit[key]!['lo']!, const Color(0xFFEF5350), (v) =>
              setState(() => _crit[key]!['lo'] = v), unit),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text('–', style: TextStyle(color: themeNotifier.dark ? AppColors.darkMuted : Colors.black26))),
          _thresholdField(_crit[key]!['hi']!, const Color(0xFFEF5350), (v) =>
              setState(() => _crit[key]!['hi'] = v), unit),
        ])),
      ]),
    );
  }

  Widget _thresholdField(double value, Color color,
      ValueChanged<double> onChanged, String unit) {
    final ctrl = TextEditingController(
        text: value % 1 == 0 ? value.toStringAsFixed(1) : value.toStringAsFixed(2));
    return SizedBox(
      width: 72,
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
        onSubmitted: (v) { final d = double.tryParse(v); if (d != null) onChanged(d); },
        onTapOutside: (_) {
          final d = double.tryParse(ctrl.text); if (d != null) onChanged(d);
        },
        decoration: InputDecoration(
          suffixText: unit,
          suffixStyle: TextStyle(fontSize: 9, color: color.withOpacity(0.6)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: color.withOpacity(0.3))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: color.withOpacity(0.3))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: color, width: 1.5)),
          filled: true,
          fillColor: color.withOpacity(0.05),
        ),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

Widget statusBadge(bool connected, String status, {VoidCallback? onTap}) {
  final col = connected ? const Color(0xFF26C6A0) : Colors.red;
  final badge = Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: col.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: col),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.circle, size: 7, color: col),
      const SizedBox(width: 6),
      Text(status, style: TextStyle(fontSize: 12,
          fontWeight: FontWeight.w600, color: col)),
      if (!connected && onTap != null) ...[
        const SizedBox(width: 6),
        Icon(Icons.play_circle_outline, size: 13, color: col),
      ],
    ]),
  );
  if (onTap == null || connected) return badge;
  return Tooltip(
    message: 'Click to start Docker backend',
    child: GestureDetector(onTap: onTap, child: badge),
  );
}

Widget statPill(String label, String value, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
  child: Row(children: [
    Text('$label  ', style: TextStyle(fontSize: 10, color: color.withOpacity(0.7),
        fontWeight: FontWeight.w700, letterSpacing: 0.8)),
    Text(value, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w700)),
  ]),
);

Widget appButton({required IconData icon, required String label,
  required Color color, required VoidCallback onTap}) => GestureDetector(
  onTap: onTap,
  child: Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.4))),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14)),
    ]),
  ),
);


// ── Docker manager ────────────────────────────────────────────────────────────
// Handles build + run for backend containers entirely from the GUI.
// image configs: name → {port, dockerfilePath}

// Flutter desktop on macOS doesn't inherit shell PATH — use full binary path.
String get _dockerBin {
  if (kIsWeb) return 'docker';
  if (Platform.isMacOS)   return '/usr/local/bin/docker';
  if (Platform.isLinux)   return '/usr/bin/docker';
  return 'docker';
}

// ── Project root resolution ───────────────────────────────────────────────────
// Walks up from the running executable to find the repo root (the folder that
// contains the "backend" and "frontend" siblings). Works for any user/machine
// that clones the repo, with no hardcoded paths.
//
// Executable location (macOS debug):
//   <root>/frontend/build/macos/Build/Products/Debug/
//          temperature_monitor.app/Contents/MacOS/temperature_monitor
//   MacOS(0) → Contents(1) → .app(2) → Debug(3) → Products(4) → Build(5)
//   → macos(6) → build(7) → frontend(8) → <root>(9)
String get _projectRoot {
  if (kIsWeb) return '';
  try {
    final exe = Platform.resolvedExecutable;
    var d = Directory(File(exe).parent.path); // start at MacOS/
    for (int i = 0; i < 9; i++) d = d.parent;
    // Confirm we landed in the right place
    if (Directory('${d.path}/backend').existsSync()) return d.path;
    // If standard depth didn't work, search upward for a dir containing backend/
    if (!kIsWeb) d = Directory(File(exe).parent.path);
    for (int i = 0; i < 15; i++) {
      if (Directory('${d.path}/backend').existsSync()) return d.path;
      d = d.parent;
    }
  } catch (_) {}
  // Last resort: derive from the source file location via Platform.script
  try {
    // Platform.script = .../frontend/lib/main.dart (during flutter run)
    final script = Platform.script.toFilePath();
    var d = Directory(File(script).parent.path); // lib/
    for (int i = 0; i < 3; i++) d = d.parent;   // lib→frontend→root (3 up)
    if (Directory('${d.path}/backend').existsSync()) return d.path;
  } catch (_) {}
  throw Exception(
    'Could not locate project root. '
    'Make sure the app is run from inside the cloned repository.',
  );
}

// ── Docker env: resolve real HOME from executable path (not sandbox HOME) ────
Map<String, String> _dockerEnv() {
  if (kIsWeb) return {};
  if (Platform.isMacOS) {
    // On macOS sandbox, Platform.environment['HOME'] returns the container path.
    // Extract the real home dir from the executable path which always starts
    // with /Users/<username>/...
    String realHome = Platform.environment['HOME'] ?? '';
    try {
      final exe = Platform.resolvedExecutable;
      final match = RegExp(r'^(/Users/[^/]+)').firstMatch(exe);
      if (match != null) realHome = match.group(1)!;
    } catch (_) {}

    // Docker Desktop ≥4.13 socket location
    final socketPath = '$realHome/.docker/run/docker.sock';
    return {
      ...Platform.environment,
      'HOME': realHome,
      'DOCKER_HOST': 'unix://$socketPath',
    };
  }
  return Map.from(Platform.environment);
}

Map<String, Map<String, dynamic>> get _imageConfig => {
  'temp-sensor':   {
    'port': 8080,
    'context': '$_projectRoot/backend',
    'dockerfile': '$_projectRoot/backend/Dockerfile',
  },
  'cell-analyzer': {
    'port': 8081,
    'context': '$_projectRoot/backend',
    'dockerfile': '$_projectRoot/backend/Dockerfile.cell',
  },
};

// Entry point called by the disconnected badge tap
Future<void> launchDocker(
    BuildContext context, String image, int port) async {
  final cfg = _imageConfig[image] ?? {};
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DockerProgressDialog(
      image: image,
      port: port,
      contextPath:    cfg['context']    as String? ?? '$_projectRoot/backend',
      dockerfilePath: cfg['dockerfile'] as String? ?? '${cfg['context']}/Dockerfile',
    ),
  );
}

// ── Docker progress dialog ────────────────────────────────────────────────────
class _DockerProgressDialog extends StatefulWidget {
  final String image;
  final int port;
  final String contextPath;
  final String dockerfilePath;
  const _DockerProgressDialog({
    required this.image,
    required this.port,
    required this.contextPath,
    required this.dockerfilePath,
  });
  @override
  State<_DockerProgressDialog> createState() => _DockerProgressDialogState();
}

class _DockerProgressDialogState extends State<_DockerProgressDialog> {
  // Phases: checking → building → starting → done / error
  String _phase   = 'checking';
  bool   _success = false;
  bool   _done    = false;
  final List<String> _logs = [];
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _run();
  }

  void _log(String line) {
    setState(() => _logs.add(line));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut);
      }
    });
  }

  Future<void> _run() async {
    final docker = _dockerBin;
    final env    = _dockerEnv();

    try {
      // ── 1. Check if image already exists ──────────────────────────────
      setState(() => _phase = 'checking');
      _log('▶ Checking for image "${widget.image}"…');

      final check = await Process.run(
        '/bin/sh', ['-c', '$docker images -q ${widget.image}'],
        environment: env,
      );

      final imageExists = check.stdout.toString().trim().isNotEmpty;
      _log(imageExists
          ? '✓  Image found locally.'
          : '✗  Image not found — will build from Dockerfile.');

      // ── 2. Build if needed ────────────────────────────────────────────
      if (!imageExists) {
        setState(() => _phase = 'building');
        _log('');
        _log('▶ Building "${widget.image}" from:');
        _log('  Dockerfile: ${widget.dockerfilePath}');
        _log('  Context:    ${widget.contextPath}');
        _log('');

        // Check that the context directory exists
        final dir = Directory(widget.contextPath);
        if (!await dir.exists()) {
          _log('');
          _log('✗  ERROR: Dockerfile directory not found:');
          _log('   ${widget.contextPath}');
          _log('');
          _log('  Create it with a Dockerfile, then try again.');
          setState(() { _phase = 'error'; _done = true; });
          return;
        }

        // Run via /bin/sh -c. After cd-ing into the context dir, use a
        // relative path for -f to avoid spaces-in-path issues with docker's -f flag.
        final dockerfileName = widget.dockerfilePath.split('/').last; // e.g. "Dockerfile.cell"
        final esc = (String p) => '"${p.replaceAll('"', '\\"')}"';
        final buildCmd =
            'cd ${esc(widget.contextPath)} && '
            '$docker build -f $dockerfileName -t ${widget.image} .';
        final buildProcess = await Process.start(
          '/bin/sh', ['-c', buildCmd],
          environment: env,
        );

        buildProcess.stdout
            .transform(const SystemEncoding().decoder)
            .transform(const LineSplitter())
            .listen(_log);
        buildProcess.stderr
            .transform(const SystemEncoding().decoder)
            .transform(const LineSplitter())
            .listen(_log);

        final buildExit = await buildProcess.exitCode;
        if (buildExit != 0) {
          _log('');
          _log('✗  Build failed (exit $buildExit).');
          setState(() { _phase = 'error'; _done = true; });
          return;
        }
        _log('');
        _log('✓  Build succeeded.');
      }

      // ── 3. Remove old container (if any) ─────────────────────────────
      setState(() => _phase = 'starting');
      _log('');
      _log('▶ Removing old container (if any)…');
      await Process.run('/bin/sh', ['-c', '$docker rm -f ${widget.image}'],
          environment: env);

      // ── 4. Start container ────────────────────────────────────────────
      _log('▶ Starting container on port ${widget.port}…');
      final run = await Process.run(
        '/bin/sh',
        ['-c', '$docker run -d --name ${widget.image} '
               '-p ${widget.port}:${widget.port} ${widget.image}'],
        environment: env,
      );

      if (run.exitCode == 0) {
        final id = run.stdout.toString().trim().substring(0, 12);
        _log('✓  Container started  (id: $id)');
        _log('');
        _log('Listening on http://localhost:${widget.port}');
        setState(() { _phase = 'done'; _success = true; _done = true; });
      } else {
        _log('');
        _log('✗  docker run failed:');
        _log(run.stderr.toString().trim());
        setState(() { _phase = 'error'; _done = true; });
      }

    } catch (e) {
      _log('');
      _log('✗  Exception: $e');
      setState(() { _phase = 'error'; _done = true; });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (phaseLabel, phaseColor) = switch (_phase) {
      'checking'  => ('Checking image',   const Color(0xFF9E9E9E)),
      'building'  => ('Building image',   const Color(0xFF388BFF)),
      'starting'  => ('Starting container', const Color(0xFF388BFF)),
      'done'      => ('Running',           const Color(0xFF26C6A0)),
      _           => ('Error',             const Color(0xFFEF5350)),
    };

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 80),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 32, offset: const Offset(0, 10))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // ── Title bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 18, 0),
            child: Row(children: [
              const Icon(Icons.terminal, size: 16, color: Colors.white54),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'Docker  ·  ${widget.image}',
                style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w700, color: themeNotifier.dark ? AppColors.darkCard : Colors.white),
              )),
              // Phase badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: phaseColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: phaseColor.withOpacity(0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (!_done)
                    SizedBox(width: 8, height: 8,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: phaseColor))
                  else
                    Container(width: 7, height: 7,
                        decoration: BoxDecoration(
                            color: phaseColor,
                            shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(phaseLabel, style: TextStyle(fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: phaseColor)),
                ]),
              ),
            ]),
          ),

          const SizedBox(height: 12),

          // ── Log terminal ──
          Container(
            height: 300,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D1A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListView.builder(
              controller: _scroll,
              itemCount: _logs.length,
              itemBuilder: (_, i) {
                final line = _logs[i];
                Color col = Colors.white54;
                if (line.startsWith('✓'))  col = const Color(0xFF26C6A0);
                if (line.startsWith('✗'))  col = const Color(0xFFEF5350);
                if (line.startsWith('▶'))  col = const Color(0xFF388BFF);
                return Text(line,
                    style: TextStyle(
                        fontSize: 10.5, fontFamily: 'monospace',
                        color: col, height: 1.5));
              },
            ),
          ),

          // ── Footer ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            child: Row(children: [
              if (_done && !_success) ...[
                const Icon(Icons.info_outline,
                    size: 12, color: Colors.white38),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Check that Docker Desktop is open and '
                    'the Dockerfile path is correct.',
                    style: TextStyle(fontSize: 10, color: Colors.white38),
                  ),
                ),
              ] else
                const Expanded(child: SizedBox()),
              TextButton(
                onPressed: _done
                    ? () => Navigator.pop(context)
                    : null,
                child: Text(
                  _success ? 'Done' : _done ? 'Close' : 'Running…',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: _done
                        ? (_success
                            ? const Color(0xFF26C6A0)
                            : Colors.white54)
                        : Colors.white24,
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Protocol Report Dialog ────────────────────────────────────────────────────
void showProtocolReport(
  BuildContext context, {
  required Map<String, String> patient,
  required List<ProtocolStep> steps,
  required int totalElapsed,
  required String technician,
}) {
  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => _ProtocolReportDialog(
      patient: patient,
      steps: steps,
      totalElapsed: totalElapsed,
      technician: technician,
    ),
  );
}

class _ProtocolReportDialog extends StatefulWidget {
  final Map<String, String> patient;
  final List<ProtocolStep> steps;
  final int totalElapsed;
  final String technician;

  const _ProtocolReportDialog({
    required this.patient,
    required this.steps,
    required this.totalElapsed,
    required this.technician,
  });

  @override
  State<_ProtocolReportDialog> createState() => _ProtocolReportDialogState();
}

class _ProtocolReportDialogState extends State<_ProtocolReportDialog> {
  bool _exporting = false;
  String? _exportedPath;

  // Short aliases
  Map<String, String> get patient     => widget.patient;
  List<ProtocolStep>  get steps       => widget.steps;
  int                 get totalElapsed => widget.totalElapsed;
  String              get technician  => widget.technician;

  String _fmt(int sec) {
    final m = sec ~/ 60, s = sec % 60;
    return '${m.toString().padLeft(2,'0')}m ${s.toString().padLeft(2,'0')}s';
  }

  String _qcNote(String id) => switch (id) {
    'intake'       => 'Sample volume >= 50 uL verified.',
    'dissociation' => 'Viability post-dissociation: >80%.',
    'droplets'     => 'Droplet rate: 500-1000 /sec.',
    'drug_loading' => '24-well drug matrix confirmed.',
    'incubation'   => 'Environment within alarm thresholds.',
    'imaging'      => 'Auto-focus CV <10% across wells.',
    'analysis'     => 'ML model v2.4. Min. 50 cells/well.',
    _              => 'All QC flags reviewed.',
  };

  Future<void> _exportPdf() async {
    setState(() { _exporting = true; _exportedPath = null; });

    try {
      final now    = DateTime.now();
      final dateStr =
          '${now.day.toString().padLeft(2,'0')}/'
          '${now.month.toString().padLeft(2,'0')}/'
          '${now.year}  '
          '${now.hour.toString().padLeft(2,'0')}:'
          '${now.minute.toString().padLeft(2,'0')}';

      final allDone = steps.every((s) => s.status == StepStatus.done);
      final anyFail = steps.any((s)  => s.status == StepStatus.failed);
      final outcome = anyFail ? 'ABORTED' : allDone ? 'COMPLETED' : 'INCOMPLETE';

      // ── Colours ──
      const navy    = PdfColor.fromInt(0xFF1A1A2E);
      const blue    = PdfColor.fromInt(0xFF388BFF);
      const green   = PdfColor.fromInt(0xFF26C6A0);
      const red     = PdfColor.fromInt(0xFFEF5350);
      const amber   = PdfColor.fromInt(0xFFFFA726);
      const grey    = PdfColor.fromInt(0xFF9E9E9E);
      const lightBg = PdfColor.fromInt(0xFFF8F9FF);
      const rowAlt  = PdfColor.fromInt(0xFFF3F3F3);

      final outcomeColor = anyFail ? red : allDone ? green : amber;

      final pdf = pw.Document(
        title: 'Protocol Run Report — ${patient['id']}',
        author: technician,
        creator: 'Lab-on-Chip Monitor',
      );

      // ── Fonts ──
      final ttRegular = await PdfGoogleFonts.interRegular();
      final ttBold    = await PdfGoogleFonts.interBold();
      final ttMono    = await PdfGoogleFonts.sourceCodeProRegular();

      pw.TextStyle ts(double size, {pw.Font? font, PdfColor? color,
          double? height, double? spacing}) =>
          pw.TextStyle(
            font: font ?? ttRegular,
            fontSize: size,
            color: color ?? navy,
            lineSpacing: height,
            letterSpacing: spacing,
          );

      final pdf_doc = pdf; // alias for clarity

      pdf_doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        build: (ctx) => [

          // ══ HEADER ══════════════════════════════════════════════════════
          pw.Container(
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              color: navy,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Protocol Run Report',
                    style: ts(16, font: ttBold, color: PdfColors.white)),
                pw.SizedBox(height: 3),
                pw.Text('Lab-on-Chip Monitor  —  IVD Device',
                    style: ts(9, color: PdfColor.fromInt(0x88FFFFFF))),
              ]),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: pw.BoxDecoration(
                  color: outcomeColor.shade(0.25),
                  borderRadius: pw.BorderRadius.circular(20),
                  border: pw.Border.all(
                      color: outcomeColor, width: 1),
                ),
                child: pw.Text(outcome,
                    style: ts(9, font: ttBold, color: outcomeColor)),
              ),
            ]),
          ),

          pw.SizedBox(height: 16),

          // ══ META ROW ═════════════════════════════════════════════════════
          pw.Row(children: [
            _pdfChip(ttRegular, 'Date: $dateStr', 9),
            pw.SizedBox(width: 8),
            _pdfChip(ttRegular, 'Operator: $technician', 9),
            pw.SizedBox(width: 8),
            _pdfChip(ttRegular, 'Runtime: ${_fmt(totalElapsed)}', 9),
          ]),

          pw.SizedBox(height: 18),

          // ══ PATIENT INFO ══════════════════════════════════════════════════
          _pdfSectionLabel(ttBold, 'Patient Information', blue),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: lightBg,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColor.fromInt(0xFFE0E0E0)),
            ),
            child: pw.Row(children: [
              _pdfKV(ttRegular, ttBold, 'Patient ID',
                  patient['id'] ?? '—'),
              pw.SizedBox(width: 24),
              _pdfKV(ttRegular, ttBold, 'Age',
                  patient['age'] ?? '—'),
              pw.SizedBox(width: 24),
              pw.Expanded(child: _pdfKV(ttRegular, ttBold, 'Diagnosis',
                  patient['diagnosis'] ?? '—')),
            ]),
          ),

          pw.SizedBox(height: 18),

          // ══ RUN SUMMARY ═══════════════════════════════════════════════════
          _pdfSectionLabel(ttBold, 'Run Summary', blue),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            _pdfStatCard(ttRegular, ttBold, 'Total Steps',
                '${steps.length}', blue),
            pw.SizedBox(width: 8),
            _pdfStatCard(ttRegular, ttBold, 'Completed',
                '${steps.where((s) => s.status == StepStatus.done).length}',
                green),
            pw.SizedBox(width: 8),
            _pdfStatCard(ttRegular, ttBold, 'Failed',
                '${steps.where((s) => s.status == StepStatus.failed).length}',
                red),
            pw.SizedBox(width: 8),
            _pdfStatCard(ttRegular, ttBold, 'Total Runtime',
                _fmt(totalElapsed), navy),
          ]),

          pw.SizedBox(height: 18),

          // ══ STEP LOG TABLE ════════════════════════════════════════════════
          _pdfSectionLabel(ttBold, 'Step Log', blue),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(
                color: PdfColor.fromInt(0xFFE0E0E0), width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(22),
              1: const pw.FixedColumnWidth(22),
              2: const pw.FlexColumnWidth(2.5),
              3: const pw.FlexColumnWidth(3.5),
              4: const pw.FixedColumnWidth(60),
              5: const pw.FixedColumnWidth(58),
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: rowAlt),
                children: ['#', '', 'Step', 'QC Note', 'Duration', 'Status']
                    .map((h) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 6, vertical: 6),
                  child: pw.Text(h, style: ts(7.5, font: ttBold,
                      color: grey, spacing: 0.4)),
                )).toList(),
              ),
              // Data rows
              for (int i = 0; i < steps.length; i++)
                _pdfStepRow(steps[i], i, ttRegular, ttBold, ttMono,
                    i.isOdd ? PdfColors.white : rowAlt),
            ],
          ),

          pw.SizedBox(height: 18),

          // ══ QC SIGN-OFF ════════════════════════════════════════════════
          _pdfSectionLabel(ttBold, 'QC Sign-off', blue),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: (anyFail ? red : green).shade(0.08),
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(
                  color: (anyFail ? red : green).shade(0.4), width: 0.8),
            ),
            child: pw.Row(children: [
              pw.Container(
                width: 10, height: 10,
                decoration: pw.BoxDecoration(
                  color: anyFail ? red : green,
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(
                  anyFail
                      ? 'Run did not complete normally. Manual review required.'
                      : 'Run completed successfully. All steps passed QC criteria.',
                  style: ts(10, font: ttBold)),
                pw.SizedBox(height: 2),
                pw.Text('Operator: $technician  \u00B7  $dateStr',
                    style: ts(8, color: grey)),
              ])),
            ]),
          ),

          pw.SizedBox(height: 20),

          // ══ FOOTER ════════════════════════════════════════════════════════
          pw.Divider(color: PdfColor.fromInt(0xFFE0E0E0), thickness: 0.5),
          pw.SizedBox(height: 6),
          pw.Text(
            'This report is generated automatically by the Lab-on-Chip Monitor. '
            'Built by Mattéo Meister (meister.matteo@outlook.com). '
            'Intended for authorised laboratory personnel only. Not for direct clinical use without physician review.',
            style: ts(7.5, color: grey),
          ),
        ],
      ));

      // ── Save file (sandbox-safe via path_provider) ───────────────────────
      // Platform.environment['HOME'] returns the sandbox container path on
      // macOS, not the real home. Use getDownloadsDirectory() instead which
      // is always accessible without extra entitlements.
      final pdfBytes2 = await pdf_doc.save();
      final filename =
          'protocol_report_${patient['id']}_'
          '${now.year}${now.month.toString().padLeft(2,'0')}'
          '${now.day.toString().padLeft(2,'0')}'
          '_${now.hour.toString().padLeft(2,'0')}'
          '${now.minute.toString().padLeft(2,'0')}.pdf';
      if (kIsWeb) {
        await Printing.layoutPdf(onLayout: (_) async => pdfBytes2, name: filename);
        setState(() { _exporting = false; _exportedPath = filename; });
      } else {
        final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(pdfBytes2);
        setState(() { _exporting = false; _exportedPath = file.path; });
        if (Platform.isMacOS) {
          await Process.run('open', [file.path]);
        } else if (Platform.isLinux) {
          await Process.run('xdg-open', [file.path]);
        } else if (Platform.isWindows) {
          await Process.run('start', [file.path], runInShell: true);
        }
      }

    } catch (e) {
      setState(() => _exporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: const Color(0xFFEF5350),
        ));
      }
    }
  }

  // ── PDF helper widgets ────────────────────────────────────────────────────
  pw.Widget _pdfChip(pw.Font font, String label, double size) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(0xFFF3F3F3),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Text(label,
            style: pw.TextStyle(font: font, fontSize: size,
                color: PdfColor.fromInt(0xFF666666))),
      );

  pw.Widget _pdfSectionLabel(pw.Font bold, String text, PdfColor col) =>
      pw.Row(children: [
        pw.Container(width: 3, height: 12,
            decoration: pw.BoxDecoration(
                color: col, borderRadius: pw.BorderRadius.circular(2))),
        pw.SizedBox(width: 7),
        pw.Text(text, style: pw.TextStyle(
            font: bold, fontSize: 11, color: PdfColor.fromInt(0xFF1A1A2E),
            letterSpacing: 0.4)),
      ]);

  pw.Widget _pdfKV(pw.Font reg, pw.Font bold, String key, String val) =>
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(key, style: pw.TextStyle(
            font: bold, fontSize: 7.5,
            color: PdfColor.fromInt(0xFF999999), letterSpacing: 0.4)),
        pw.SizedBox(height: 3),
        pw.Text(val, style: pw.TextStyle(
            font: bold, fontSize: 11,
            color: PdfColor.fromInt(0xFF1A1A2E))),
      ]);

  pw.Widget _pdfStatCard(pw.Font reg, pw.Font bold,
      String label, String value, PdfColor col) =>
      pw.Expanded(child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: pw.BoxDecoration(
          color: col.shade(0.08),
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: col.shade(0.25), width: 0.5),
        ),
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label, style: pw.TextStyle(font: bold, fontSize: 7.5,
              color: col.shade(0.6), letterSpacing: 0.4)),
          pw.SizedBox(height: 3),
          pw.Text(value, style: pw.TextStyle(
              font: bold, fontSize: 16, color: col)),
        ]),
      ));

  pw.TableRow _pdfStepRow(ProtocolStep step, int i,
      pw.Font reg, pw.Font bold, pw.Font mono, PdfColor bg) {
    final isDone   = step.status == StepStatus.done;
    final isFailed = step.status == StepStatus.failed;
    final isPend   = step.status == StepStatus.pending;
    const green = PdfColor.fromInt(0xFF26C6A0);
    const red   = PdfColor.fromInt(0xFFEF5350);
    const grey  = PdfColor.fromInt(0xFFBBBBBB);
    const blue  = PdfColor.fromInt(0xFF388BFF);
    final statusCol = isFailed ? red : isDone ? green : isPend ? grey : blue;
    final statusLabel = isFailed ? 'FAILED' : isDone ? 'DONE'
        : isPend ? 'SKIPPED' : 'PARTIAL';

    pw.Widget cell(pw.Widget child) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        child: child);

    return pw.TableRow(
      decoration: pw.BoxDecoration(color: bg),
      children: [
        cell(pw.Text('${i+1}',
            style: pw.TextStyle(font: reg, fontSize: 8,
                color: PdfColor.fromInt(0xFF999999)))),
        cell(pw.Text('',
            style: pw.TextStyle(font: reg, fontSize: 10))),
        cell(pw.Text(step.title,
            style: pw.TextStyle(font: bold, fontSize: 9,
                color: PdfColor.fromInt(0xFF1A1A2E)))),
        cell(pw.Text(_qcNote(step.id),
            style: pw.TextStyle(font: reg, fontSize: 8,
                color: PdfColor.fromInt(0xFF666666)),
            maxLines: 2)),
        cell(pw.Text(
            step.elapsedSeconds > 0 ? _fmt(step.elapsedSeconds) : '—',
            style: pw.TextStyle(font: mono, fontSize: 8,
                color: PdfColor.fromInt(0xFF666666)))),
        cell(pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: pw.BoxDecoration(
            color: statusCol.shade(0.12),
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Text(statusLabel,
              style: pw.TextStyle(font: bold, fontSize: 7,
                  color: statusCol)),
        )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme(false); // forced light for report
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2,'0')}/${now.month.toString().padLeft(2,'0')}/${now.year}'
        '  ${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';

    final allDone  = steps.every((s) => s.status == StepStatus.done);
    final anyFail  = steps.any((s) => s.status == StepStatus.failed);
    final outcome  = anyFail ? 'ABORTED' : allDone ? 'COMPLETED' : 'INCOMPLETE';
    final outcomeColor = anyFail
        ? const Color(0xFFEF5350)
        : allDone
            ? const Color(0xFF26C6A0)
            : const Color(0xFFFFA726);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 760),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 40, offset: const Offset(0, 12))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // ── Header bar ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A2E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(children: [
              const Icon(Icons.description_outlined,
                  color: Colors.white70, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Protocol Run Report',
                      style: TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w800, color: Colors.white)),
                  Text('Lab-on-Chip Monitor  —  IVD Device',
                      style: TextStyle(fontSize: 10, color: Colors.white38)),
                ]),
              ),
              // Outcome badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: outcomeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: outcomeColor.withOpacity(0.5)),
                ),
                child: Text(outcome, style: TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w800, color: outcomeColor)),
              ),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: Colors.white38, size: 18),
              ),
            ]),
          ),

          // ── Scrollable body ──
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Meta row
                _metaRow(dateStr),
                const SizedBox(height: 22),

                // Patient info card
                _sectionLabel('Patient Information'),
                const SizedBox(height: 10),
                _patientCard(),
                const SizedBox(height: 22),

                // Run summary
                _sectionLabel('Run Summary'),
                const SizedBox(height: 10),
                _summaryRow(),
                const SizedBox(height: 22),

                // Step-by-step table
                _sectionLabel('Step Log'),
                const SizedBox(height: 10),
                _stepTable(),
                const SizedBox(height: 22),

                // QC sign-off
                _sectionLabel('QC Sign-off'),
                const SizedBox(height: 10),
                _qcBox(technician, dateStr, outcome),
                const SizedBox(height: 8),

                // Footer
                Text(
                  'This report is generated automatically by the Lab-on-Chip Monitor. '
                  'Built by Mattéo Meister (meister.matteo@outlook.com). '
                  'Intended for authorised laboratory personnel only. Not for direct clinical use without physician review.',
                  style: TextStyle(fontSize: 9, color: Colors.black26,
                      fontStyle: FontStyle.italic, height: 1.5),
                ),
              ]),
            ),
          ),

          // ── Footer buttons ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(color: Colors.black.withOpacity(0.07))),
            ),
            child: Row(children: [
              if (_exportedPath != null) ...[
                const Icon(Icons.check_circle_outline,
                    size: 14, color: Color(0xFF26C6A0)),
                const SizedBox(width: 6),
                Expanded(child: Text(
                  'Saved to Downloads: ${_exportedPath!.split('/').last}',
                  style: const TextStyle(fontSize: 10,
                      color: Color(0xFF26C6A0)),
                  overflow: TextOverflow.ellipsis,
                )),
              ] else
                const Expanded(child: SizedBox()),
              const SizedBox(width: 12),
              // Export PDF button
              GestureDetector(
                onTap: _exporting ? null : _exportPdf,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: _exporting
                        ? Colors.black12
                        : const Color(0xFF388BFF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (_exporting)
                      SizedBox(width: 13, height: 13,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    else
                      Icon(Icons.picture_as_pdf_outlined,
                          size: 14, color: Colors.white),
                    const SizedBox(width: 7),
                    Text(
                      _exporting ? 'Exporting…' : 'Export PDF',
                      style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close',
                    style: TextStyle(color: Colors.black45)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String text) => Row(children: [
    Container(width: 3, height: 14,
        decoration: BoxDecoration(color: const Color(0xFF388BFF),
            borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(text, style: TextStyle(fontSize: 12,
        fontWeight: FontWeight.w800, color: const Color(0xFF1A1A2E),
        letterSpacing: 0.5)),
  ]);

  Widget _metaRow(String dateStr) => Row(children: [
    _metaChip(Icons.calendar_today_outlined, dateStr),
    const SizedBox(width: 10),
    _metaChip(Icons.person_outline, 'Operator: $technician'),
    const SizedBox(width: 10),
    _metaChip(Icons.timer_outlined, 'Runtime: ${_fmt(totalElapsed)}'),
  ]);

  Widget _metaChip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F3F3),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: Colors.black38),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.black45)),
    ]),
  );

  Widget _patientCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F9FF),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.black12),
    ),
    child: Row(children: [
      Expanded(child: _kv('Patient ID',   patient['id']    ?? '—')),
      Expanded(child: _kv('Age',          patient['age']   ?? '—')),
      Expanded(flex: 2,
          child: _kv('Diagnosis', patient['diagnosis'] ?? '—')),
    ]),
  );

  Widget _summaryRow() => Row(children: [
    Expanded(child: _statCard('Total Steps',
        '${steps.length}', const Color(0xFF388BFF))),
    const SizedBox(width: 10),
    Expanded(child: _statCard('Completed',
        '${steps.where((s) => s.status == StepStatus.done).length}',
        const Color(0xFF26C6A0))),
    const SizedBox(width: 10),
    Expanded(child: _statCard('Failed',
        '${steps.where((s) => s.status == StepStatus.failed).length}',
        const Color(0xFFEF5350))),
    const SizedBox(width: 10),
    Expanded(child: _statCard('Total Runtime',
        _fmt(totalElapsed), const Color(0xFF1A1A2E))),
  ]);

  Widget _statCard(String label, String value, Color col) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    decoration: BoxDecoration(
      color: col.withOpacity(0.07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: col.withOpacity(0.2)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
          color: col.withOpacity(0.7), letterSpacing: 0.5)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 18,
          fontWeight: FontWeight.w800, color: col)),
    ]),
  );

  Widget _stepTable() => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.black12),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(32),
          1: FixedColumnWidth(28),
          2: FlexColumnWidth(3),
          3: FlexColumnWidth(4),
          4: FixedColumnWidth(80),
          5: FixedColumnWidth(70),
        },
        children: [
          // Header
          TableRow(
            decoration: BoxDecoration(color: const Color(0xFFF3F3F3)),
            children: ['#', '', 'Step', 'QC Note', 'Duration', 'Status']
                .map((h) => Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 9),
              child: Text(h, style: TextStyle(fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Colors.black38, letterSpacing: 0.5)),
            )).toList(),
          ),
          // Data rows
          for (int i = 0; i < steps.length; i++)
            _stepRow(steps[i], i),
        ],
      ),
    ),
  );

  TableRow _stepRow(ProtocolStep step, int i) {
    final t = AppTheme(false); // forced light for report
    final isDone   = step.status == StepStatus.done;
    final isFailed = step.status == StepStatus.failed;
    final isPend   = step.status == StepStatus.pending;
    final statusCol = isFailed ? const Color(0xFFEF5350)
        : isDone ? const Color(0xFF26C6A0)
        : isPend ? const Color(0xFFBBBBBB)
        : const Color(0xFF388BFF);
    final statusLabel = isFailed ? 'FAILED'
        : isDone ? 'DONE'
        : isPend ? 'SKIPPED'
        : 'PARTIAL';
    final bg = i.isOdd
        ? (Colors.white)
        : (const Color(0xFFFAFAFA));

    return TableRow(
      decoration: BoxDecoration(color: bg),
      children: [
        // #
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Text('${i+1}', style: TextStyle(
                fontSize: 10, color: Colors.black38))),
        // Icon
        Padding(padding: const EdgeInsets.symmetric(vertical: 10),
            child: const SizedBox.shrink()),
        // Title
        Padding(padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 10),
            child: Text(step.title, style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A2E)))),
        // QC note
        Padding(padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 10),
            child: Text(_qcNote(step.id), style: TextStyle(
                fontSize: 10, color: Colors.black45, height: 1.4))),
        // Duration
        Padding(padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 10),
            child: Text(
              step.elapsedSeconds > 0 ? _fmt(step.elapsedSeconds) : '—',
              style: TextStyle(fontSize: 10,
                  fontFamily: 'monospace', color: Colors.black45))),
        // Status chip
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: statusCol.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(statusLabel, style: TextStyle(fontSize: 8,
                fontWeight: FontWeight.w800, color: statusCol)),
          ),
        ),
      ],
    );
  }

  Widget _qcBox(String tech, String dateStr, String outcome) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: outcome == 'COMPLETED'
          ? const Color(0xFF26C6A0).withOpacity(0.06)
          : const Color(0xFFEF5350).withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: outcome == 'COMPLETED'
            ? const Color(0xFF26C6A0).withOpacity(0.3)
            : const Color(0xFFEF5350).withOpacity(0.3),
      ),
    ),
    child: Row(children: [
      Icon(outcome == 'COMPLETED'
          ? Icons.verified_outlined
          : Icons.warning_amber_outlined,
          size: 18,
          color: outcome == 'COMPLETED'
              ? const Color(0xFF26C6A0)
              : const Color(0xFFEF5350)),
      const SizedBox(width: 12),
      Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          outcome == 'COMPLETED'
              ? 'Run completed successfully. All steps passed QC criteria.'
              : 'Run did not complete normally. Manual review required.',
          style: TextStyle(fontSize: 12,
              fontWeight: FontWeight.w600, color: const Color(0xFF1A1A2E))),
        const SizedBox(height: 3),
        Text('Operator: $tech  ·  $dateStr',
            style: TextStyle(fontSize: 10, color: Colors.black38)),
      ])),
    ]),
  );

  Widget _kv(String key, String val) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(key, style: TextStyle(fontSize: 9, color: Colors.black38,
        fontWeight: FontWeight.w700, letterSpacing: 0.4)),
    const SizedBox(height: 3),
    Text(val, style: TextStyle(fontSize: 12,
        fontWeight: FontWeight.w600, color: const Color(0xFF1A1A2E))),
  ]);
}
