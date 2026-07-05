import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';

/// New account creation, posts to /api/auth/register/ and logs the user
/// in immediately on success (matching how login already stores the JWT).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _firstName = TextEditingController();
  final _schoolName = TextEditingController();
  String _studentClass = '12';
  String _targetExam = 'BOTH';
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (_username.text.trim().isEmpty || _password.text.length < 8) {
      setState(() => _error = 'Username required, password must be at least 8 characters.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authProvider.notifier).register({
        'username': _username.text.trim(),
        'email': _email.text.trim(),
        'password': _password.text,
        'first_name': _firstName.text.trim(),
        'school_name': _schoolName.text.trim(),
        'student_class': _studentClass,
        'target_exam': _targetExam,
      });
    } catch (e) {
      setState(() => _error = 'Registration failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Center(
        child: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(controller: _username, decoration: const InputDecoration(labelText: 'Username')),
                const SizedBox(height: 12),
                TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 12),
                TextField(controller: _password, decoration: const InputDecoration(labelText: 'Password (min 8 chars)'), obscureText: true),
                const SizedBox(height: 12),
                TextField(controller: _firstName, decoration: const InputDecoration(labelText: 'First name')),
                const SizedBox(height: 12),
                TextField(controller: _schoolName, decoration: const InputDecoration(labelText: 'School name')),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _studentClass,
                      decoration: const InputDecoration(labelText: 'Class'),
                      items: const [
                        DropdownMenuItem(value: '11', child: Text('Class 11')),
                        DropdownMenuItem(value: '12', child: Text('Class 12')),
                        DropdownMenuItem(value: 'DROP', child: Text('Dropper')),
                      ],
                      onChanged: (v) => setState(() => _studentClass = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _targetExam,
                      decoration: const InputDecoration(labelText: 'Target'),
                      items: const [
                        DropdownMenuItem(value: 'JEE', child: Text('JEE')),
                        DropdownMenuItem(value: 'NEET', child: Text('NEET')),
                        DropdownMenuItem(value: 'BOTH', child: Text('Both')),
                      ],
                      onChanged: (v) => setState(() => _targetExam = v!),
                    ),
                  ),
                ]),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12.5)),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Create Account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
