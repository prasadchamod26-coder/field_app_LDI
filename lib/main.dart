import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

void main() {
  runApp(const FieldOfficerApp());
}

class FieldOfficerApp extends StatelessWidget {
  const FieldOfficerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Field Officer Log',
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Database? _db;
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _regController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  
  String _selectedService = 'එලගව ගොවිපල පරික්ශාව';
  DateTime _selectedDate = DateTime.now();

  final List<String> _services = [
    'එලගව ගොවිපල පරික්ශාව',
    'මී ගව ගොවිපල පරික්ශාව',
    'කුකුලු ගොවිපල පරික්ශාව',
    'ඌරු ගොවිපල පරික්ශාව',
    'වටු ගොවිපල පරික්ශාව',
    'කෘතීම සිංචන'
  ];

  @override
  void initState() {
    super.initState();
    _initDb();
  }

  Future<void> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'farmer_logs.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE logs(id INTEGER PRIMARY KEY AUTOINCREMENT, reg_no TEXT, name TEXT, service TEXT, date TEXT)',
        );
      },
    );
  }

  Future<void> _saveData() async {
    if (_formKey.currentState!.validate()) {
      String regNo = _regController.text.trim();
      if (regNo.isEmpty) {
        regNo = "New Farmer";
      }

      String formattedDate = DateFormat('yyyy.MM.dd').format(_selectedDate);

      await _db?.insert('logs', {
        'reg_no': regNo,
        'name': _nameController.text.trim(),
        'service': _selectedService,
        'date': formattedDate,
      });

      _regController.clear();
      _nameController.clear();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('දත්ත සාර්ථකව Save විය (Offline)')),
        );
      }
    }
  }

  Future<void> _generateMonthlyReport() async {
    final now = DateTime.now();
    final firstDayOfMonth = DateFormat('yyyy.MM.dd').format(DateTime(now.year, now.month, 1));
    final lastDayOfMonth = DateFormat('yyyy.MM.dd').format(DateTime(now.year, now.month + 1, 0));

    final List>? results = await _db?.query(
      'logs',
      where: 'date >= ? AND date <= ?',
      whereArgs: [firstDayOfMonth, lastDayOfMonth],
      orderBy: 'date ASC',
    );

    if (results == null || results.isEmpty) {
      _showReportDialog("මෙම මාසය සඳහා දත්ත ඇතුළත් කර නොමැත.", "");
      return;
    }

    int totalFarmers = results.length;
    StringBuffer reportBuffer = StringBuffer();
    reportBuffer.writeln("මාසික වාර්තාව ($firstDayOfMonth සිට $lastDayOfMonth දක්වා)\n");
    reportBuffer.writeln("එකතු වූ මුළු ගොවීන් ගණන: $totalFarmers\n");
    reportBuffer.writeln("--- විස්තරාත්මක සටහන ---");

    for (var row in results) {
      reportBuffer.writeln("${row['date']} දින ${row['name']} මහතා ${row['service']} (ලියාපදිංචි අංකය: ${row['reg_no']})");
    }

    _showReportDialog("Monthly Report Complete", reportBuffer.toString());
  }

  void _showReportDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: SelectableText(content)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Field Log Book')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _regController,
                decoration: const InputDecoration(
                  labelText: 'ගොවිපල ලියාපදිංචි අංකය (optional)',
                  hintText: 'හිස්ව තිබුණොත් New Farmer ලෙස වැටේ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'ගොවි මහතාගේ නම',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.isEmpty ? 'නම ඇතුලත් කරන්න' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedService,
                decoration: const InputDecoration(
                  labelText: 'සේවා / පරික්ශාව',
                  border: OutlineInputBorder(),
                ),
                items: _services.map((String service) {
                  return DropdownMenuItem(value: service, child: Text(service));
                }).toList(),
                onChanged: (val) => setState(() => _selectedService = val!),
              ),
              const SizedBox(height: 12),
              ListTile(
                title: Text("දිනය: ${DateFormat('yyyy.MM.dd').format(_selectedDate)}"),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2025),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveData,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                child: const Text('Data Save කරන්න (Offline)'),
              ),
              const Divider(height: 40),
              ElevatedButton.icon(
                onPressed: _generateMonthlyReport,
                icon: const Icon(Icons.analytics),
                label: const Text('Monthly Report Generate කරන්න'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
