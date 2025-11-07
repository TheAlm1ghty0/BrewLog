import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import 'package:image_picker/image_picker.dart'; // <-- NEW: For picking images
import 'dart:io'; // <-- NEW: For File object

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  // --- NEW: Image Picker and loading state ---
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  // --- END NEW ---

  // --- NEW: Function to handle image source selection ---
  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }
  // --- END NEW ---

  // --- NEW: Function to pick and upload the image ---
  Future<void> _pickImage(ImageSource source) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final colorScheme = Theme.of(context).colorScheme;

    try {
      final XFile? imageFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024, // Resize on the client side a bit
        maxHeight: 1024,
        imageQuality: 80, // Compress a bit
      );

      if (imageFile == null) {
        print("Image picking cancelled.");
        return; // User cancelled
      }

      setState(() => _isUploading = true);

      // Upload the file
      final updatedUserData = await _apiService.uploadProfilePicture(File(imageFile.path));

      // Update the AuthProvider with the new user data (which has the URL)
      authProvider.updateUser(updatedUserData);

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Profile picture updated!'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      print("Error picking/uploading image: $e");
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to update picture: $e', style: TextStyle(color: colorScheme.onErrorContainer)),
          backgroundColor: colorScheme.errorContainer,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }
  // --- END NEW ---


  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // --- NEW: Listen to AuthProvider for pfp changes ---
    final authProvider = Provider.of<AuthProvider>(context);
    final profilePicUrl = authProvider.profilePictureUrl;
    // --- END NEW ---

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- NEW: Profile Picture Display ---
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  // Show network image if URL exists, otherwise show placeholder
                  backgroundImage: (profilePicUrl != null && profilePicUrl.isNotEmpty)
                      ? NetworkImage(profilePicUrl)
                      : null,
                  child: (profilePicUrl == null || profilePicUrl.isEmpty)
                      ? Icon(
                    Icons.person,
                    size: 60,
                    color: colorScheme.primary,
                  )
                      : null,
                ),
                // Show loading indicator
                if (_isUploading)
                  const Positioned.fill(
                    child: CircularProgressIndicator(),
                  ),
                // Edit button
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Material(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: _isUploading ? null : _showImageSourceDialog,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.edit,
                          size: 20,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // --- END NEW ---

          // --- Warning Message with Theme-Aware Colors ---
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

    // --- Capture context before async gaps ---
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final navigator = Navigator.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    // --- End capture ---

    setState(() => _isLoading = true);

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

    // --- Capture context before async gaps ---
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final navigator = Navigator.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    // --- End capture ---

    setState(() => _isLoading = true);

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