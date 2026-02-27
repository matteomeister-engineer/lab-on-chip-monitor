// main.dart — Lab-on-Chip Medical Device Monitor

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert' show json, base64Decode, LineSplitter;
import 'dart:io' show Directory, File, Process, Platform, SystemEncoding;
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:window_manager/window_manager.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.setSize(const Size(1460, 870));
  await windowManager.setMinimumSize(const Size(900, 600));
  await windowManager.center();
  await windowManager.setTitle('Lab-on-Chip Monitor');
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
  final _userCtrl = TextEditingController(text: 'admin');
  final _passCtrl = TextEditingController(text: 'admin123');
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
                const Center(child: Text('Pre-filled: admin / admin123',
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
        icon:'🧫', durationSeconds:120),
    ProtocolStep(id:'dissociation', title:'Cell Dissociation',
        description:'Enzymatic dissociation of tumor tissue into single-cell suspension.',
        icon:'⚗️', durationSeconds:300),
    ProtocolStep(id:'droplets',     title:'Droplet Generation',
        description:'Cells encapsulated in picoliter droplets. Target: 1 cell / droplet.',
        icon:'💧', durationSeconds:180),
    ProtocolStep(id:'drug_loading', title:'Drug Combination Loading',
        description:'Combinatorial drug library injected into droplet array across 24 wells.',
        icon:'💊', durationSeconds:240),
    ProtocolStep(id:'incubation',   title:'Incubation',
        description:'Cells incubated with drugs at 37°C, 5% CO₂ for 48h. Environment monitored continuously.',
        icon:'🌡', durationSeconds:600),
    ProtocolStep(id:'imaging',      title:'Fluorescence Imaging',
        description:'Automated microscopy scan of all wells. Viability markers imaged per droplet.',
        icon:'🔬', durationSeconds:300),
    ProtocolStep(id:'analysis',     title:'Data Analysis & Ranking',
        description:'ML model scores drug efficacy. Top combinations ranked and quality-controlled.',
        icon:'📊', durationSeconds:120),
    ProtocolStep(id:'report',       title:'Report Ready',
        description:'Results validated. Clinical report available for physician review.',
        icon:'📋', durationSeconds:0),
  ];

  // Oncology is unlocked once imaging step is reached
  bool get _oncologyUnlocked {
    const unlockedAt = {'imaging', 'analysis', 'report'};
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
                      onGoToProtocol: () => setState(() => _tab = 1),
                    )),
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

  Widget _tabBtn(String label, int index,
      {String? badge, Color? badgeColor}) {
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
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: sel ? Colors.white : Colors.black45)),
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
            statusBadge(_connected, _status,
                onTap: _connected ? null
                    : () => launchDocker(context, 'temp-sensor', 8080)),
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
//  RUN PROTOCOL PANEL
// ══════════════════════════════════════════

enum ProtocolStatus { idle, running, paused, completed, aborted }
enum StepStatus     { pending, active, done, failed }

class ProtocolStep {
  final String id, title, description, icon;
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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(patient['diagnosis'] ?? '',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E))),
            const Text('TheraMeDx1 Sampler™ — Run Protocol',
                style: TextStyle(fontSize: 11, color: Colors.black38)),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: steps.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 52, endIndent: 16),
          itemBuilder: (_, i) => _stepRow(steps[i], i),
        ),
      ),
    );
  }

  Widget _stepRow(ProtocolStep step, int i) {
    final isActive = i == activeStep &&
        (runStatus == ProtocolStatus.running ||
         runStatus == ProtocolStatus.paused);
    final isDone   = step.status == StepStatus.done;
    final isFailed = step.status == StepStatus.failed;

    final col = isFailed ? const Color(0xFFEF5350)
              : isDone   ? const Color(0xFF26C6A0)
              : isActive ? const Color(0xFF388BFF)
              :            const Color(0xFFE0E0E0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      color: isActive
          ? const Color(0xFF388BFF).withOpacity(0.05)
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
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : isFailed
                  ? const Icon(Icons.close, size: 14, color: Colors.white)
                  : Text('${i+1}', style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800, color: col))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(children: [
            Text(step.icon, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 5),
            Flexible(child: Text(step.title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: isActive ? const Color(0xFF388BFF)
                       : isDone   ? const Color(0xFF1A1A2E)
                       :            Colors.black38,
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
        color: Colors.white,
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
          Text(step.icon, style: const TextStyle(fontSize: 28)),
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
            Text(step.title, style: const TextStyle(fontSize: 18,
                fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
          ])),
          if (step.durationSeconds > 0)
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_fmt(step.elapsedSeconds),
                  style: const TextStyle(fontSize: 22,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                      color: Color(0xFF388BFF))),
              Text('${_fmt(remaining)} remaining',
                  style: const TextStyle(fontSize: 9, color: Colors.black38)),
            ]),
        ]),

        const SizedBox(height: 20),

        // Description
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: const Color(0xFFF8F9FF),
              borderRadius: BorderRadius.circular(10)),
          child: Text(step.description,
              style: const TextStyle(fontSize: 12,
                  color: Colors.black54, height: 1.6)),
        ),

        const SizedBox(height: 14),

        // ── Step animation illustration ──
        Container(
          height: 90,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF388BFF).withOpacity(0.1)),
          ),
          child: _StepAnimationWidget(
            stepId: step.id,
            running: runStatus == ProtocolStatus.running,
          ),
        ),

        const SizedBox(height: 14),

        // Step progress bar
        if (step.durationSeconds > 0) ...[
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Step progress', style: TextStyle(fontSize: 10,
                color: Colors.black38, fontWeight: FontWeight.w600)),
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
          const Icon(Icons.info_outline, size: 13, color: Colors.black26),
          const SizedBox(width: 6),
          Expanded(child: Text(_qcNote(step.id),
              style: const TextStyle(fontSize: 10,
                  color: Colors.black38, fontStyle: FontStyle.italic))),
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
  Widget _idleCard() => Container(
    width: double.infinity,
    decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12)),
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
      const Text('Ready to Run', style: TextStyle(fontSize: 18,
          fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
      const SizedBox(height: 8),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          'Start the TheraMeDx1 Sampler™ protocol for this patient sample.\n'
          'Ensure chip is loaded and all environment sensors are nominal.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.black38, height: 1.6),
        ),
      ),
      const SizedBox(height: 24),
      Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center,
        children: steps.map((s) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: const Color(0xFFF3F3F3),
              borderRadius: BorderRadius.circular(20)),
          child: Text('${s.icon} ${s.title}',
              style: const TextStyle(fontSize: 10, color: Colors.black45)),
        )).toList()),
    ]),
  );

  Widget _completedCard() => Container(
    width: double.infinity,
    decoration: BoxDecoration(color: Colors.white,
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
      const Text('Run Completed', style: TextStyle(fontSize: 18,
          fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
      const SizedBox(height: 8),
      Text(
        'Total runtime: ${_fmt(totalElapsed)}\nAll ${steps.length} steps completed successfully.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: Colors.black45, height: 1.6)),
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
  );

  Widget _abortedCard() => Container(
    width: double.infinity,
    decoration: BoxDecoration(color: Colors.white,
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
      const Text('Run Aborted', style: TextStyle(fontSize: 18,
          fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
      const SizedBox(height: 8),
      Text(
        'Aborted at step ${activeStep + 1}: ${steps[activeStep].title}.\n'
        'Elapsed: ${_fmt(totalElapsed)}',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: Colors.black45, height: 1.6)),
    ]),
  );

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
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Overall progress  ·  $done / ${steps.length} steps',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                  color: Colors.black45)),
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
              color: const Color(0xFFF3F3F3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.fast_forward_rounded,
                  size: 14, color: Colors.black38),
              const SizedBox(width: 7),
              const Text('Skip Step',
                  style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w600, color: Colors.black45)),
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
                color: enabled ? color.withOpacity(0.4) : Colors.black12),
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

// ══════════════════════════════════════════
//  STEP ANIMATIONS
// ══════════════════════════════════════════

/// Self-contained animated illustration for the active protocol step.
/// Pauses automatically when [running] is false.
class _StepAnimationWidget extends StatefulWidget {
  final String stepId;
  final bool running;
  const _StepAnimationWidget({required this.stepId, required this.running});
  @override
  State<_StepAnimationWidget> createState() => _StepAnimationWidgetState();
}

class _StepAnimationWidgetState extends State<_StepAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.running) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(_StepAnimationWidget old) {
    super.didUpdateWidget(old);
    if (old.stepId != widget.stepId) {
      _ctrl.reset();
      if (widget.running) _ctrl.repeat();
    } else if (!old.running && widget.running) {
      _ctrl.repeat();
    } else if (old.running && !widget.running) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value; // 0..1 looping
        final painter = _painterFor(widget.stepId, t);
        if (painter == null) return const SizedBox.shrink();
        return SizedBox(
          height: 80,
          child: CustomPaint(
            painter: painter,
            size: const Size(double.infinity, 80),
          ),
        );
      },
    );
  }

  CustomPainter? _painterFor(String id, double t) => switch (id) {
    'intake'       => _IntakePainter(t),
    'dissociation' => _DissociationPainter(t),
    'droplets'     => _DropletPainter(t),
    'drug_loading' => _DrugLoadingPainter(t),
    'incubation'   => _IncubationPainter(t),
    'imaging'      => _ImagingPainter(t),
    'analysis'     => _AnalysisPainter(t),
    'report'       => _ReportPainter(t),
    _              => null,
  };
}

// ── INTAKE: fluid flowing left→right through a channel ─────────────────────
class _IntakePainter extends CustomPainter {
  final double t;
  _IntakePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    final mid = h / 2;
    final paint = Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;

    // Channel walls
    paint.color = const Color(0xFF388BFF).withOpacity(0.18);
    paint.strokeWidth = 1;
    canvas.drawLine(Offset(20, mid - 12), Offset(w - 20, mid - 12), paint);
    canvas.drawLine(Offset(20, mid + 12), Offset(w - 20, mid + 12), paint);

    // Inlet port (left circle)
    paint.style = PaintingStyle.fill;
    paint.color = const Color(0xFF388BFF).withOpacity(0.12);
    canvas.drawCircle(Offset(20, mid), 12, paint);
    paint.style = PaintingStyle.stroke;
    paint.color = const Color(0xFF388BFF).withOpacity(0.5);
    paint.strokeWidth = 1.5;
    canvas.drawCircle(Offset(20, mid), 12, paint);

    // Outlet port (right circle)
    paint.style = PaintingStyle.fill;
    paint.color = const Color(0xFF388BFF).withOpacity(0.08);
    canvas.drawCircle(Offset(w - 20, mid), 9, paint);
    paint.style = PaintingStyle.stroke;
    paint.color = const Color(0xFF388BFF).withOpacity(0.3);
    canvas.drawCircle(Offset(w - 20, mid), 9, paint);

    // Fluid boluses moving right
    const numBoluses = 4;
    paint.style = PaintingStyle.fill;
    for (int i = 0; i < numBoluses; i++) {
      final phase = (t + i / numBoluses) % 1.0;
      final x = 32 + (w - 64) * phase;
      final alpha = (math.sin(phase * math.pi)).clamp(0.0, 1.0);
      paint.color = const Color(0xFF388BFF).withOpacity(0.55 * alpha);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, mid), width: 18, height: 14),
          const Radius.circular(7),
        ),
        paint,
      );
    }

    // Arrow tip on right
    paint.style = PaintingStyle.stroke;
    paint.color = const Color(0xFF388BFF).withOpacity(0.35);
    paint.strokeWidth = 1.5;
    final ax = w - 34.0;
    canvas.drawLine(Offset(ax, mid - 5), Offset(ax + 7, mid), paint);
    canvas.drawLine(Offset(ax, mid + 5), Offset(ax + 7, mid), paint);
  }

  @override bool shouldRepaint(_IntakePainter old) => old.t != t;
}

// ── DISSOCIATION: cluster of dots breaking apart ────────────────────────────
class _DissociationPainter extends CustomPainter {
  final double t;
  _DissociationPainter(this.t);

  static const List<Offset> _startPos = [
    Offset(0, 0), Offset(10, -8), Offset(-10, -8),
    Offset(10, 8), Offset(-10, 8), Offset(0, 14), Offset(0, -14),
  ];
  static const List<Offset> _endDir = [
    Offset(0, -18), Offset(22, -18), Offset(-22, -18),
    Offset(22, 18),  Offset(-22, 18),  Offset(0, 28),  Offset(0, -28),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2; final cy = size.height / 2;
    // ease in
    final ease = t < 0.5
        ? 2 * t * t
        : 1 - math.pow(-2 * t + 2, 2) / 2;

    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < _startPos.length; i++) {
      final s = _startPos[i]; final d = _endDir[i];
      final x = cx + s.dx + d.dx * ease;
      final y = cy + s.dy + d.dy * ease;
      final r = 5.5 - 1.5 * ease;
      final alpha = 1.0 - ease * 0.3;
      paint.color = i == 0
          ? const Color(0xFF388BFF).withOpacity(0.85 * alpha)
          : const Color(0xFF26C6A0).withOpacity(0.7 * alpha);
      canvas.drawCircle(Offset(x, y), r, paint);
    }

    // Dashed ring showing original cluster boundary, fading out
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF388BFF).withOpacity((1 - ease) * 0.3);
    canvas.drawCircle(Offset(cx, cy), 20, ringPaint);
  }

  @override bool shouldRepaint(_DissociationPainter old) => old.t != t;
}

// ── DROPLETS: small circles encapsulating dots, flowing right ───────────────
class _DropletPainter extends CustomPainter {
  final double t;
  _DropletPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    final paint = Paint();

    // Track (thin line)
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1;
    paint.color = const Color(0xFF388BFF).withOpacity(0.12);
    canvas.drawLine(Offset(10, h / 2), Offset(w - 10, h / 2), paint);

    // 5 droplets at staggered positions
    const n = 5;
    for (int i = 0; i < n; i++) {
      final phase = (t + i / n) % 1.0;
      final x = 14 + (w - 28) * phase;
      final y = h / 2;
      final alpha = math.sin(phase * math.pi).clamp(0.0, 1.0);

      // Outer droplet shell
      paint.style = PaintingStyle.fill;
      paint.color = const Color(0xFF388BFF).withOpacity(0.13 * alpha);
      canvas.drawCircle(Offset(x, y), 11, paint);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 1.2;
      paint.color = const Color(0xFF388BFF).withOpacity(0.5 * alpha);
      canvas.drawCircle(Offset(x, y), 11, paint);

      // Inner cell dot
      paint.style = PaintingStyle.fill;
      paint.color = const Color(0xFF26C6A0).withOpacity(0.8 * alpha);
      canvas.drawCircle(Offset(x, y), 4, paint);
    }
  }

  @override bool shouldRepaint(_DropletPainter old) => old.t != t;
}

// ── DRUG LOADING: wells filling up column by column ─────────────────────────
class _DrugLoadingPainter extends CustomPainter {
  final double t;
  _DrugLoadingPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    const cols = 6; const rows = 2;
    const wellW = 28.0; const wellH = 22.0; const gap = 6.0;

    final totalW = cols * wellW + (cols - 1) * gap;
    final totalH = rows * wellH + gap;
    final ox = (w - totalW) / 2; final oy = (h - totalH) / 2;

    final bgPaint  = Paint()..style = PaintingStyle.fill;
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke..strokeWidth = 1.2;

    // Drug colors cycling
    const drugColors = [
      Color(0xFF388BFF), Color(0xFF26C6A0), Color(0xFFFFA726),
      Color(0xFFEF5350), Color(0xFFAB47BC), Color(0xFF26C6DA),
    ];

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final wx = ox + col * (wellW + gap);
        final wy = oy + row * (wellH + gap);
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(wx, wy, wellW, wellH),
          const Radius.circular(5),
        );

        // Fill threshold: animate by column then row
        final wellIndex = row * cols + col;
        final fillPhase = (t * (rows * cols) - wellIndex).clamp(0.0, 1.0);

        bgPaint.color = const Color(0xFFF3F3F3);
        canvas.drawRRect(rect, bgPaint);

        if (fillPhase > 0) {
          final col0 = drugColors[col % drugColors.length];
          bgPaint.color = col0.withOpacity(0.25 * fillPhase);
          // Clip fill to well
          canvas.save();
          canvas.clipRRect(rect);
          final fillH = wellH * fillPhase;
          canvas.drawRect(
            Rect.fromLTWH(wx, wy + wellH - fillH, wellW, fillH),
            Paint()..color = col0.withOpacity(0.35 * fillPhase),
          );
          canvas.restore();
        }

        rimPaint.color = const Color(0xFF388BFF).withOpacity(0.25);
        canvas.drawRRect(rect, rimPaint);
      }
    }
  }

  @override bool shouldRepaint(_DrugLoadingPainter old) => old.t != t;
}

// ── INCUBATION: concentric pulsing rings (heat / temperature waves) ─────────
class _IncubationPainter extends CustomPainter {
  final double t;
  _IncubationPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2; final cy = size.height / 2;

    // Central cell cluster dot
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFA726).withOpacity(0.9);
    canvas.drawCircle(Offset(cx, cy), 7, dotPaint);

    // 3 ripple rings expanding outward
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const numRings = 3;
    for (int i = 0; i < numRings; i++) {
      final phase = (t + i / numRings) % 1.0;
      final r = 10 + phase * 32;
      final alpha = (1 - phase) * 0.6;
      ringPaint.color = const Color(0xFFFFA726).withOpacity(alpha);
      canvas.drawCircle(Offset(cx, cy), r, ringPaint);
    }

    // Temp label tick marks
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFFFA726).withOpacity(0.2);
    for (int i = 0; i < 6; i++) {
      final angle = i * math.pi / 3;
      final r1 = 48.0; final r2 = 55.0;
      canvas.drawLine(
        Offset(cx + math.cos(angle) * r1, cy + math.sin(angle) * r1),
        Offset(cx + math.cos(angle) * r2, cy + math.sin(angle) * r2),
        linePaint,
      );
    }
  }

  @override bool shouldRepaint(_IncubationPainter old) => old.t != t;
}

// ── IMAGING: scanning beam sweeping across a grid of wells ──────────────────
class _ImagingPainter extends CustomPainter {
  final double t;
  _ImagingPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    const cols = 5; const rows = 2;
    const cellW = 30.0; const cellH = 22.0; const gap = 5.0;

    final totalW = cols * cellW + (cols - 1) * gap;
    final totalH = rows * cellH + gap;
    final ox = (w - totalW) / 2; final oy = (h - totalH) / 2;

    // Total wells for scan progress
    final totalCells = cols * rows;
    final scanned = (t * totalCells).floor();

    final bgPaint  = Paint()..style = PaintingStyle.fill;
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke..strokeWidth = 1.2;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final index = row * cols + col;
        final cx = ox + col * (cellW + gap) + cellW / 2;
        final cy = oy + row * (cellH + gap) + cellH / 2;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - cellW / 2, cy - cellH / 2, cellW, cellH),
          const Radius.circular(4),
        );

        if (index < scanned) {
          // Scanned: green glow
          bgPaint.color = const Color(0xFF26C6A0).withOpacity(0.15);
          canvas.drawRRect(rect, bgPaint);
          rimPaint.color = const Color(0xFF26C6A0).withOpacity(0.5);
          // Draw a tiny cell dot
          canvas.drawCircle(Offset(cx, cy), 3,
              Paint()..color = const Color(0xFF26C6A0).withOpacity(0.6));
        } else if (index == scanned) {
          // Currently being scanned: bright highlight
          bgPaint.color = const Color(0xFF388BFF).withOpacity(0.18);
          canvas.drawRRect(rect, bgPaint);
          rimPaint.color = const Color(0xFF388BFF).withOpacity(0.8);
          // Scan line animation
          final subPhase = (t * totalCells) - scanned;
          final lineY = (cy - cellH / 2) + cellH * subPhase;
          canvas.drawLine(
            Offset(cx - cellW / 2 + 2, lineY),
            Offset(cx + cellW / 2 - 2, lineY),
            Paint()
              ..color = const Color(0xFF388BFF).withOpacity(0.7)
              ..strokeWidth = 1.5,
          );
        } else {
          bgPaint.color = const Color(0xFFF3F3F3);
          canvas.drawRRect(rect, bgPaint);
          rimPaint.color = const Color(0xFF388BFF).withOpacity(0.15);
        }
        canvas.drawRRect(rect, rimPaint);
      }
    }
  }

  @override bool shouldRepaint(_ImagingPainter old) => old.t != t;
}

// ── ANALYSIS: bar chart bars animating up ───────────────────────────────────
class _AnalysisPainter extends CustomPainter {
  final double t;
  _AnalysisPainter(this.t);

  static const List<double> _targets = [0.55, 0.9, 0.4, 0.75, 0.65, 0.85, 0.5];
  static const List<Color> _barColors = [
    Color(0xFF388BFF), Color(0xFF26C6A0), Color(0xFF388BFF),
    Color(0xFF26C6A0), Color(0xFF388BFF), Color(0xFF26C6A0), Color(0xFF388BFF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    final n = _targets.length;
    const barW = 18.0; const gap = 8.0;
    final totalW = n * barW + (n - 1) * gap;
    final ox = (w - totalW) / 2; final baseY = h - 8.0;
    final maxH = h - 20;

    final paint = Paint()..style = PaintingStyle.fill;
    final axisPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF388BFF).withOpacity(0.15);
    canvas.drawLine(Offset(ox - 4, baseY), Offset(ox + totalW + 4, baseY), axisPaint);

    for (int i = 0; i < n; i++) {
      // Stagger bar appearance
      final delay = i / n * 0.5;
      final localT = ((t - delay) / 0.6).clamp(0.0, 1.0);
      // Ease out
      final ease = 1 - math.pow(1 - localT, 3);
      final bh = _targets[i] * maxH * ease;
      final x = ox + i * (barW + gap);

      paint.color = _barColors[i % _barColors.length].withOpacity(0.75);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, baseY - bh, barW, bh),
          const Radius.circular(3),
        ),
        paint,
      );

      // Highlight top
      if (i == 1 || i == 5) {
        paint.color = const Color(0xFF26C6A0).withOpacity(0.5);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, baseY - bh, barW, 3),
            const Radius.circular(2),
          ),
          paint,
        );
      }
    }
  }

  @override bool shouldRepaint(_AnalysisPainter old) => old.t != t;
}

// ── REPORT: checkmark drawing itself ────────────────────────────────────────
class _ReportPainter extends CustomPainter {
  final double t;
  _ReportPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2; final cy = size.height / 2;

    // Document outline
    final docPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFF26C6A0).withOpacity(0.3);
    const dw = 44.0; const dh = 54.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: dw, height: dh),
        const Radius.circular(5),
      ),
      docPaint,
    );

    // Horizontal lines (text placeholders)
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF26C6A0).withOpacity(0.2);
    for (int i = 0; i < 3; i++) {
      final lx = cx - 14 + (i == 2 ? 6 : 0);
      final rx = cx + (i == 2 ? 2 : 14);
      final ly = cy - 10 + i * 10.0;
      canvas.drawLine(Offset(lx, ly), Offset(rx, ly), linePaint);
    }

    // Animated checkmark
    final checkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF26C6A0).withOpacity(0.9);

    // Checkmark path: two segments
    // segment 1: small down-left stroke (0..0.4)
    // segment 2: long up-right stroke (0.4..1.0)
    final p1 = Offset(cx - 14, cy + 16);
    final p2 = Offset(cx - 6,  cy + 25);
    final p3 = Offset(cx + 14, cy + 5);

    if (t < 0.4) {
      final s = t / 0.4;
      canvas.drawLine(p1, Offset.lerp(p1, p2, s)!, checkPaint);
    } else {
      canvas.drawLine(p1, p2, checkPaint);
      final s = (t - 0.4) / 0.6;
      canvas.drawLine(p2, Offset.lerp(p2, p3, s)!, checkPaint);
    }
  }

  @override bool shouldRepaint(_ReportPainter old) => old.t != t;
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
  final VoidCallback onGoToProtocol;

  const OncologyPanel({
    super.key,
    required this.unlocked,
    required this.runStatus,
    required this.activeStepId,
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
  String _status = 'Idle';
  int? _selectedWell;
  final String _url = 'http://localhost:8081/api/analyze';

  @override
  void initState() { super.initState(); if (widget.unlocked) _analyze(); }

  @override
  void didUpdateWidget(OncologyPanel old) {
    super.didUpdateWidget(old);
    // Auto-fetch when protocol unlocks oncology for the first time
    if (!old.unlocked && widget.unlocked && _wells.isEmpty) _analyze();
  }

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
  Widget build(BuildContext context) {
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
        Expanded(child: Align(alignment: Alignment.centerRight,
            child: statusBadge(_connected, _status,
                onTap: _connected ? null
                    : () => launchDocker(context, 'cell-analyzer', 8081)))),
      ]),
    ]),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black12),
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
            Text(title, style: const TextStyle(fontSize: 20,
                fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
            const SizedBox(height: 10),
            Text(subtitle, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12,
                    color: Colors.black45, height: 1.65)),
            const SizedBox(height: 28),

            // Mini step pills showing protocol progress
            if (isRunning) ...[
              const Text('Protocol progress',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                      color: Colors.black38)),
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center,
                children: [
                  '🧫 Intake', '⚗️ Dissociation', '💧 Droplets',
                  '💊 Drug Loading', '🌡 Incubation', '🔬 Imaging',
                ].asMap().entries.map((e) {
                  const unlockedAt = {'imaging', 'analysis', 'report'};
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
                      size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(btnLabel, style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: Colors.white)),
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
  try {
    final exe = Platform.resolvedExecutable;
    var d = Directory(File(exe).parent.path); // start at MacOS/
    for (int i = 0; i < 9; i++) d = d.parent;
    // Confirm we landed in the right place
    if (Directory('${d.path}/backend').existsSync()) return d.path;
    // If standard depth didn't work, search upward for a dir containing backend/
    d = Directory(File(exe).parent.path);
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
                style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w700, color: Colors.white),
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
        creator: 'TheraMeDx1 Sampler',
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
                pw.Text('TheraMeDx1 Sampler\u2122  \u2014  IVD Device',
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
            'This report is generated automatically by the TheraMeDx1 Sampler\u2122 '
            'software and is intended for authorised laboratory personnel only. '
            'Not for direct clinical use without physician review.',
            style: ts(7.5, color: grey),
          ),
        ],
      ));

      // ── Save file (sandbox-safe via path_provider) ───────────────────────
      // Platform.environment['HOME'] returns the sandbox container path on
      // macOS, not the real home. Use getDownloadsDirectory() instead which
      // is always accessible without extra entitlements.
      final dir = await getDownloadsDirectory() ??
                  await getApplicationDocumentsDirectory();
      final filename =
          'protocol_report_${patient['id']}_'
          '${now.year}${now.month.toString().padLeft(2,'0')}'
          '${now.day.toString().padLeft(2,'0')}'
          '_${now.hour.toString().padLeft(2,'0')}'
          '${now.minute.toString().padLeft(2,'0')}.pdf';
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(await pdf_doc.save());

      setState(() {
        _exporting     = false;
        _exportedPath  = file.path;
      });

      // Open the PDF immediately
      if (Platform.isMacOS) {
        await Process.run('open', [file.path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [file.path]);
      } else if (Platform.isWindows) {
        await Process.run('start', [file.path], runInShell: true);
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
        cell(pw.Text(step.icon,
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
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Protocol Run Report',
                      style: TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w800, color: Colors.white)),
                  Text('TheraMeDx1 Sampler™  —  IVD Device',
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
                const Text(
                  'This report is generated automatically by the TheraMeDx1 Sampler™ '
                  'software and is intended for authorised laboratory personnel only. '
                  'Not for direct clinical use without physician review.',
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
                      const SizedBox(width: 13, height: 13,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    else
                      const Icon(Icons.picture_as_pdf_outlined,
                          size: 14, color: Colors.white),
                    const SizedBox(width: 7),
                    Text(
                      _exporting ? 'Exporting…' : 'Export PDF',
                      style: const TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close',
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
    Text(text, style: const TextStyle(fontSize: 12,
        fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E),
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
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.black45)),
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
            decoration: const BoxDecoration(color: Color(0xFFF3F3F3)),
            children: ['#', '', 'Step', 'QC Note', 'Duration', 'Status']
                .map((h) => Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 9),
              child: Text(h, style: const TextStyle(fontSize: 9,
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
        ? Colors.white
        : const Color(0xFFFAFAFA);

    return TableRow(
      decoration: BoxDecoration(color: bg),
      children: [
        // #
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Text('${i+1}', style: const TextStyle(
                fontSize: 10, color: Colors.black38))),
        // Icon
        Padding(padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(step.icon,
                style: const TextStyle(fontSize: 13))),
        // Title
        Padding(padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 10),
            child: Text(step.title, style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E)))),
        // QC note
        Padding(padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 10),
            child: Text(_qcNote(step.id), style: const TextStyle(
                fontSize: 10, color: Colors.black45, height: 1.4))),
        // Duration
        Padding(padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 10),
            child: Text(
              step.elapsedSeconds > 0 ? _fmt(step.elapsedSeconds) : '—',
              style: const TextStyle(fontSize: 10,
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
          style: const TextStyle(fontSize: 12,
              fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
        const SizedBox(height: 3),
        Text('Operator: $tech  ·  $dateStr',
            style: const TextStyle(fontSize: 10, color: Colors.black38)),
      ])),
    ]),
  );

  Widget _kv(String key, String val) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(key, style: const TextStyle(fontSize: 9, color: Colors.black38,
        fontWeight: FontWeight.w700, letterSpacing: 0.4)),
    const SizedBox(height: 3),
    Text(val, style: const TextStyle(fontSize: 12,
        fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
  ]);
}