import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Warning Message with Theme-Aware Colors
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: colorScheme.onTertiaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Changing your username or password will log you out of your current session.',
                    style: TextStyle(color: colorScheme.onTertiaryContainer),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _ChangeUsernameCard(apiService: _apiService),
          const SizedBox(height: 24),
          _ChangePasswordCard(apiService: _apiService),
        ],
      ),
    );
  }
}

class _ChangeUsernameCard extends StatefulWidget {
  final ApiService apiService;
  const _ChangeUsernameCard({required this.apiService});

  @override
  State<_ChangeUsernameCard> createState() => _ChangeUsernameCardState();
}

class _ChangeUsernameCardState extends State<_ChangeUsernameCard> {
  final _formKey = GlobalKey<FormState>();
  final _newUsernameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _updateUsername() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final navigator = Navigator.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    try {
      await widget.apiService.updateUsername(_newUsernameController.text);

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Username updated successfully! Please log in again.')),
      );

      authProvider.logout();
      navigator.popUntil((route) => route.isFirst);

    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
            style: TextStyle(color: colorScheme.onError),
          ),
          backgroundColor: colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUsername = Provider.of<AuthProvider>(context, listen: false).username;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Change Username', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Text('Current Username: $currentUsername'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newUsernameController,
                decoration: const InputDecoration(
                  labelText: 'New Username',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter a new username.';
                  if (value == currentUsername) return 'New username must be different.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: _updateUsername,
                  child: const Text('Save Username'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangePasswordCard extends StatefulWidget {
  final ApiService apiService;
  const _ChangePasswordCard({required this.apiService});

  @override
  State<_ChangePasswordCard> createState() => _ChangePasswordCardState();
}

class _ChangePasswordCardState extends State<_ChangePasswordCard> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final navigator = Navigator.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    try {
      await widget.apiService.updatePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Password updated successfully! Please log in again.')),
      );

      authProvider.logout();
      navigator.popUntil((route) => route.isFirst);

    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
            style: TextStyle(color: colorScheme.onError),
          ),
          backgroundColor: colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Change Password', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _currentPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) => value!.isEmpty ? 'Please enter your current password.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter a new password.';
                  if (value.length < 8) return 'Password must be at least 8 characters.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: _updatePassword,
                  child: const Text('Save Password'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}