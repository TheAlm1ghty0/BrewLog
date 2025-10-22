import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/leaderboard.dart';

class ManageLeaderboardsScreen extends StatefulWidget {
  final VoidCallback onDataChanged;

  const ManageLeaderboardsScreen({super.key, required this.onDataChanged});

  @override
  State<ManageLeaderboardsScreen> createState() => _ManageLeaderboardsScreenState();
}

class _ManageLeaderboardsScreenState extends State<ManageLeaderboardsScreen> {
  final ApiService _apiService = ApiService();
  Future<List<Leaderboard>>? _leaderboardsFuture;

  @override
  void initState() {
    super.initState();
    _fetchLeaderboards();
  }

  void _fetchLeaderboards() {
    if (mounted) {
      setState(() {
        _leaderboardsFuture = _apiService.getUserLeaderboards();
      });
    }
  }

  Future<void> _handleLeave(BuildContext context, Leaderboard leaderboard) async {
    // final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    AwesomeDialog(
      context: context,
      dialogType: DialogType.noHeader,
      animType: AnimType.bottomSlide,
      title: 'Leave Leaderboard',
      desc: 'Are you sure you want to leave "${leaderboard.name}"?',
      dialogBackgroundColor: Theme.of(context).cardColor,
      titleTextStyle: TextStyle(color: Theme.of(context).textTheme.titleLarge?.color),
      descTextStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
      customHeader: Icon(Icons.exit_to_app, size: 60, color: colorScheme.tertiary),
      btnCancelOnPress: () {},
      btnOkText: 'Leave',
      btnOkColor: colorScheme.tertiary,
      btnOkOnPress: () async {
        try {
          await _apiService.leaveLeaderboard(leaderboard.id);
          if (mounted) {
            scaffoldMessenger.showSnackBar(SnackBar(content: Text('You have left "${leaderboard.name}".')));
            widget.onDataChanged();
            _fetchLeaderboards();
          }
        } catch (e) {
          if (mounted) {
            scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: colorScheme.error));
          }
        }
      },
    ).show();
  }

  Future<void> _handleDelete(BuildContext context, Leaderboard leaderboard) async {
    // final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    AwesomeDialog(
      context: context,
      dialogType: DialogType.noHeader,
      animType: AnimType.bottomSlide,
      title: 'Delete Leaderboard',
      desc: 'Are you sure you want to permanently delete "${leaderboard.name}"? This action cannot be undone.',
      dialogBackgroundColor: Theme.of(context).cardColor,
      titleTextStyle: TextStyle(color: Theme.of(context).textTheme.titleLarge?.color),
      descTextStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
      customHeader: Icon(Icons.delete_forever, size: 60, color: colorScheme.error),
      btnCancelOnPress: () {},
      btnOkText: 'Delete',
      btnOkColor: colorScheme.error,
      btnOkOnPress: () async {
        try {
          await _apiService.deleteLeaderboard(leaderboard.id);
          if (mounted) {
            scaffoldMessenger.showSnackBar(SnackBar(content: Text('"${leaderboard.name}" has been deleted.')));
            widget.onDataChanged();
            _fetchLeaderboards();
          }
        } catch (e) {
          if (mounted) {
            scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: colorScheme.error));
          }
        }
      },
    ).show();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Leaderboards')),
      body: FutureBuilder<List<Leaderboard>>(
        future: _leaderboardsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('You are not part of any leaderboards.'));
          }

          final leaderboards = snapshot.data!;

          return ListView.builder(
            itemCount: leaderboards.length,
            itemBuilder: (context, index) {
              final lb = leaderboards[index];
              final isCreator = lb.creatorUsername == authProvider.username;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  title: Text(lb.name),
                  subtitle: Text(isCreator ? 'You are the creator' : 'Member'),
                  trailing: isCreator
                      ? IconButton(
                    icon: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
                    tooltip: 'Delete Leaderboard',
                    onPressed: () => _handleDelete(context, lb),
                  )
                      : TextButton(
                    onPressed: () => _handleLeave(context, lb),
                    child: Text(
                      'Leave',
                      style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}