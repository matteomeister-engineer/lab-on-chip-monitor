// main.dart — Lab-on-Chip Medical Device Monitor
// Login → Patient Selection → Dashboard (Environment + Oncology)

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

void main() => runApp(const MedicalMonitorApp());

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

// ── App root ──────────────────────────────────────────────────────────────────

class MedicalMonitorApp extends StatelessWidget {
  const MedicalMonitorApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lab-on-Chip Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF3F3F3),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A3A6E)),
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

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  String? _error;

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
    return Scaffold(
      backgroundColor: const Color(0xFF3889FE),
      body: Center(
        child: SizedBox(width: 380,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [

            // Logo area
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.biotech, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text('Lab-on-Chip Monitor',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const Text('Diagnostic Platform',
                style: TextStyle(fontSize: 13, color: Colors.white54)),

            const SizedBox(height: 40),

            // Login card
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2),
                    blurRadius: 30, offset: const Offset(0, 10))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Technician Login',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E))),
                const SizedBox(height: 6),
                const Text('Authorised personnel only',
                    style: TextStyle(fontSize: 12, color: Colors.black38)),
                const SizedBox(height: 24),

                _field('Username', _userCtrl, false),
                const SizedBox(height: 14),
                _field('Password', _passCtrl, _obscure,
                    suffix: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                          size: 18, color: Colors.black38),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    )),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.red)),
                    ]),
                  ),
                ],

                const SizedBox(height: 20),
                SizedBox(width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A3A6E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Sign In', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),

                const SizedBox(height: 16),
                const Center(child: Text('Demo: tech01 / password1',
                    style: TextStyle(fontSize: 11, color: Colors.black26))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, bool obscure, {Widget? suffix}) =>
    TextField(
      controller: ctrl,
      obscureText: obscure,
      onSubmitted: (_) => _login(),
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: Colors.black45),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.black12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.black12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF1A3A6E), width: 1.5)),
      ),
    );
}

// ══════════════════════════════════════════
//  PATIENT SELECTION SCREEN
// ══════════════════════════════════════════

class PatientSelectScreen extends StatelessWidget {
  final String technician;
  const PatientSelectScreen({super.key, required this.technician});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Select Patient',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A2E))),
                Text('Logged in as $technician',
                    style: const TextStyle(fontSize: 13, color: Colors.black45)),
              ]),
              TextButton.icon(
                onPressed: () => Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const LoginScreen())),
                icon: const Icon(Icons.logout, size: 16),
                label: const Text('Sign out'),
                style: TextButton.styleFrom(foregroundColor: Colors.black45),
              ),
            ]),

            const SizedBox(height: 32),

            ..._patients.map((p) => _patientCard(context, p, technician)),
          ]),
        ),
      ),
    );
  }

  Widget _patientCard(BuildContext context, Map<String, String> p, String tech) {
    return GestureDetector(
      onTap: () => Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => MainDashboard(
            technician: tech, patient: p))),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF1A3A6E).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person, color: Color(0xFF1A3A6E), size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ID is always visible
            Text(p['id']!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E), fontFamily: 'monospace')),
            const SizedBox(height: 2),
            // Pseudonymised name in muted style
            Text(p['pseudo']!, style: const TextStyle(fontSize: 12, color: Colors.black45)),
            const SizedBox(height: 4),
            Text(p['diagnosis']!, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ])),
          const Icon(Icons.chevron_right, color: Colors.black26),
        ]),
      ),
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

  static const String _backendUrl = 'http://localhost:8080';

  // Targets lifted here so they survive tab switches
  final Map<String, double> targets = {
    'temperature': 37.0,
    'humidity':    95.0,
    'co2':          5.0,
    'o2':          21.0,
    'pressure':  1013.0,
    'ph':           7.4,
  };

  // Push updated targets to backend so simulated data drifts toward them
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

  @override
  void initState() {
    super.initState();
    _startLogger();
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
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
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
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
              : OncologyPanel()),
        ]),
      ),
    );
  }

  Widget _topBar() => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    child: Row(children: [

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
            const Icon(Icons.person, size: 14, color: Color(0xFF1A3A6E)),
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
                        style: const TextStyle(fontSize: 9, color: Colors.black45))
                    : const Text('', key: ValueKey('hidden')),
              ),
            ]),
            const SizedBox(width: 6),
            const Icon(Icons.swap_horiz, size: 13, color: Color(0xFF1A3A6E)),
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
                  ? const Color(0xFFFFA726).withOpacity(0.15)
                  : Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _nameRevealed
                    ? const Color(0xFFFFA726).withOpacity(0.6)
                    : Colors.black12),
            ),
            child: Row(children: [
              Icon(_nameRevealed ? Icons.visibility : Icons.visibility_off,
                  size: 13,
                  color: _nameRevealed ? const Color(0xFFFFA726) : Colors.black38),
              const SizedBox(width: 4),
              Text(_nameRevealed ? 'Visible' : 'Reveal',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                      color: _nameRevealed ? const Color(0xFFFFA726) : Colors.black38)),
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
              border: Border.all(color: Colors.black12),
            ),
            child: Row(children: [
              const Icon(Icons.receipt_long, size: 13, color: Colors.black38),
              const SizedBox(width: 4),
              Text('Audit (${_auditLog.length})',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                      color: Colors.black38)),
            ]),
          ),
        ),
      ),

      const SizedBox(width: 12),

      // Tabs
      Container(
        decoration: BoxDecoration(color: const Color(0xFFF3F3F3),
            borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          _tabBtn('🧪  Environment', 0),
          _tabBtn('🔬  Oncology', 1),
        ]),
      ),

      const Spacer(),

      Text(widget.technician,
          style: const TextStyle(fontSize: 12, color: Colors.black45)),
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
        style: TextButton.styleFrom(foregroundColor: Colors.black38),
      ),
    ]),
  );

  void _showAuditLog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.receipt_long, size: 18, color: Color(0xFF1A3A6E)),
          SizedBox(width: 8),
          Text('Audit Log', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        content: SizedBox(
          width: 400,
          height: 300,
          child: _auditLog.isEmpty
              ? const Center(child: Text('No events recorded yet.',
                  style: TextStyle(color: Colors.black38, fontSize: 13)))
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

  Widget _tabBtn(String label, int index) {
    final sel = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF1A1A2E) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: sel ? Colors.white : Colors.black45)),
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

  // History for sparklines — last 60 pts per sensor
  final Map<String, List<double>> _history = {
    'temperature': [], 'humidity': [], 'co2': [],
    'o2': [], 'pressure': [], 'ph': [],
  };

  final String _url = 'http://localhost:8080/api/environment';

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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Status bar ──
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.patient['diagnosis']!,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E))),
            const Text('Lab-on-Chip Incubation Environment',
                style: TextStyle(fontSize: 11, color: Colors.black38)),
          ]),
          Row(children: [
            // Settings toggle
            GestureDetector(
              onTap: () => setState(() => _settingsMode = !_settingsMode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: _settingsMode
                      ? const Color(0xFF1A3A6E)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _settingsMode
                        ? const Color(0xFF1A3A6E)
                        : Colors.black12),
                  boxShadow: _settingsMode ? [BoxShadow(
                      color: const Color(0xFF1A3A6E).withOpacity(0.25),
                      blurRadius: 8, offset: const Offset(0, 2))] : [],
                ),
                child: Row(children: [
                  Icon(
                    _settingsMode ? Icons.tune : Icons.tune_outlined,
                    size: 13,
                    color: _settingsMode ? Colors.white : Colors.black45,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _settingsMode ? 'Settings' : 'Settings',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _settingsMode ? Colors.white : Colors.black45,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Pill toggle indicator
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 28, height: 16,
                    decoration: BoxDecoration(
                      color: _settingsMode
                          ? Colors.white.withOpacity(0.3)
                          : Colors.black12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(children: [
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 200),
                        alignment: _settingsMode
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          width: 12, height: 12,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: _settingsMode ? Colors.white : Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 12),
            statusBadge(_connected, _status),
          ]),
        ]),

        const SizedBox(height: 16),

        // ── Responsive sensor grid ──
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;

              // Column count: portrait or narrow → 2, very narrow → 1, wide → 3
              final cols    = w > 700 ? 3 : (w > 420 ? 2 : 1);
              final compact = w < 500;
              final rows    = (6 / cols).ceil(); // e.g. 3cols→2rows, 2cols→3rows

              // Estimate minimum comfortable card height
              const minCardH = 160.0;
              const spacing  = 12.0;
              final totalMinH = rows * minCardH + (rows - 1) * spacing;

              // If not enough height for all rows → single scrollable row
              final tooShort = h < totalMinH;

              if (tooShort) {
                // Single horizontal scrolling row
                const cardW = 220.0;
                const cardH = 180.0;
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
                      width: cardW,
                      height: cardH,
                      child: _sensorCard(
                          sensors[i].$1, sensors[i].$2, sensors[i].$3, true, _settingsMode),
                    );
                  },
                );
              }

              // Normal grid — aspect ratio fills available height evenly
              final cardH = (h - (rows - 1) * spacing) / rows;
              final cardW = (w - (cols - 1) * spacing) / cols;
              final aspectRatio = cardW / cardH;

              return GridView.count(
                crossAxisCount: cols,
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
                childAspectRatio: aspectRatio,
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
            },
          ),
        ),
      ]),
    );
  }

  Widget _sensorCard(String label, String key, String emoji, bool compact, bool settings) {
    final r       = _readings[key];
    final history = _history[key] ?? [];
    final alarm   = r?.alarm ?? 'ok';
    final col     = settings ? const Color(0xFF1A3A6E) : _alarmColor(alarm);
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
        color: settings ? const Color(0xFF1A3A6E).withOpacity(0.04) : Colors.white,
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
                  color: settings ? const Color(0xFF1A3A6E) : Colors.black45,
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
                color: const Color(0xFF1A3A6E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4)),
            child: const Text('TARGET',
                style: TextStyle(fontSize: 7, fontWeight: FontWeight.w800,
                    color: Color(0xFF1A3A6E))),
          ),
        ]),

        SizedBox(height: compact ? 4 : 8),

        // ── Live mode: value + unit ──
        if (!settings) ...[
          r == null
              ? Text('--', style: TextStyle(fontSize: valueSize,
                  fontWeight: FontWeight.w800, color: Colors.black26))
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
                        style: TextStyle(fontSize: unitSize, color: Colors.black38)),
                  ),
                ]),
          if (r != null) Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('Target: ${(widget.targets[key] ?? r.target).toStringAsFixed(step < 1 ? 2 : 1)}$unit',
                style: TextStyle(fontSize: compact ? 8 : 10, color: Colors.black26)),
          ),
          SizedBox(height: compact ? 6 : 10),
          Expanded(
            child: history.length < 2
                ? Center(child: Text('...', style: TextStyle(
                    color: Colors.black12, fontSize: compact ? 9 : 11)))
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
                                  color: Colors.black38)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      const Icon(Icons.edit, size: 9, color: Colors.black26),
                      const SizedBox(width: 3),
                      Text('tap to edit',
                          style: const TextStyle(fontSize: 8, color: Colors.black26)),
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
        child: Icon(icon, size: compact ? 14 : 18, color: const Color(0xFF1A3A6E)),
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
          const Icon(Icons.tune, size: 16, color: Color(0xFF1A3A6E)),
          const SizedBox(width: 8),
          Text('Set $label Target',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Range: ${bounds.$1} – ${bounds.$2} $unit',
              style: const TextStyle(fontSize: 11, color: Colors.black38)),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                color: Color(0xFF1A3A6E)),
            decoration: InputDecoration(
              suffixText: unit,
              suffixStyle: const TextStyle(fontSize: 13, color: Colors.black38),
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
            child: const Text('Cancel',
                style: TextStyle(color: Colors.black38)),
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
          colors: [color.withOpacity(0.2), color.withOpacity(0.0)],
        )),
      )],
    );
  }
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
  const OncologyPanel({super.key});
  @override
  State<OncologyPanel> createState() => _OncologyPanelState();
}

class _OncologyPanelState extends State<OncologyPanel> {
  List<WellData> _wells = [];
  List<RankedEntry> _ranked = [];
  String _bestDrug = '', _bestCategory = '';
  double _bestEfficacy = 0;
  bool _loading = false, _connected = false;
  String _status = 'Idle';
  int? _selectedWell;
  final String _url = 'http://localhost:8081/api/analyze';

  @override
  void initState() { super.initState(); _analyze(); }

  Future<void> _analyze() async {
    setState(() { _loading = true; _status = 'Analysing...'; });
    try {
      final r = await http.get(Uri.parse(_url)).timeout(const Duration(seconds: 30));
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
      }
    } catch (_) {
      setState(() { _connected = false; _status = 'Disconnected'; _loading = false; });
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
  Widget build(BuildContext context) => Padding(
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
        Expanded(child: Align(alignment: Alignment.centerRight,
            child: statusBadge(_connected, _status))),
      ]),
    ]),
  );

  Widget _recommendationBanner() {
    if (_bestDrug.isEmpty) return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black12)),
      child: const Row(children: [
        Icon(Icons.science_outlined, color: Colors.black26, size: 20),
        SizedBox(width: 10),
        Text('Run an analysis to get a treatment recommendation',
            style: TextStyle(color: Colors.black38, fontSize: 13)),
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
          child: const Icon(Icons.recommend_rounded, color: Colors.white, size: 24)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('RECOMMENDED TREATMENT',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: Colors.white60, letterSpacing: 1.2)),
          const SizedBox(height: 2),
          Text(_bestDrug, style: const TextStyle(fontSize: 20,
              fontWeight: FontWeight.w800, color: Colors.white)),
          Text('$_bestCategory  ·  ${_bestEfficacy.toStringAsFixed(1)}% tumour cell kill rate',
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            Text('${_bestEfficacy.toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
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
      decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: w != null ? col.withOpacity(0.4) : Colors.black12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: w == null
            ? const Center(child: Text('Run analysis to see frames',
                style: TextStyle(color: Colors.black26, fontSize: 13)))
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
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                color: Colors.white))),
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
        ? const Center(child: Text('No data', style: TextStyle(color: Colors.black26)))
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
                style: const TextStyle(fontSize: 8, color: Colors.black45),
                textAlign: TextAlign.center),
          ])),
          if (isBest) Positioned(top: 3, right: 3,
              child: Icon(Icons.star_rounded, size: 11, color: col)),
        ]),
      ),
    );
  }

  Widget _rankedSidebar() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Top 5 Treatments',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
      const Text('by tumour cell kill rate',
          style: TextStyle(fontSize: 10, color: Colors.black38)),
      const SizedBox(height: 12),
      if (_ranked.isEmpty)
        const Padding(padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text('...', style: TextStyle(color: Colors.black26)))),
      Expanded(child: Column(children: _ranked.isEmpty ? []
          : _ranked.map((r) => Expanded(child: _rankedRow(r))).toList())),
    ]),
  );

  Widget _rankedRow(RankedEntry r) {
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
            Text(r.drug, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E)), overflow: TextOverflow.ellipsis),
            Text(r.category, style: const TextStyle(fontSize: 9, color: Colors.black38),
                overflow: TextOverflow.ellipsis),
          ])),
          Text('${r.efficacy.toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: col)),
        ]),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

Widget statusBadge(bool connected, String status) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    color: connected ? const Color(0xFF26C6A0).withOpacity(0.12) : Colors.red.withOpacity(0.12),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: connected ? const Color(0xFF26C6A0) : Colors.red),
  ),
  child: Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.circle, size: 7, color: connected ? const Color(0xFF26C6A0) : Colors.red),
    const SizedBox(width: 6),
    Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
        color: connected ? const Color(0xFF26C6A0) : Colors.red)),
  ]),
);

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
