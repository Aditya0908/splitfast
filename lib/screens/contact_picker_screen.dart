import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/permission_service.dart';
import '../services/recent_contacts_service.dart';

/// A selected contact entry returned from this screen.
class SelectedContact {
  final String displayName;
  final String phone;

  const SelectedContact({required this.displayName, this.phone = ''});
}

/// Multi-select contact picker with search and recents section.
/// Returns a list of [SelectedContact] on pop, or null if cancelled.
class ContactPickerScreen extends StatefulWidget {
  const ContactPickerScreen({super.key});

  @override
  State<ContactPickerScreen> createState() => _ContactPickerScreenState();
}

class _ContactPickerScreenState extends State<ContactPickerScreen> {
  List<Contact> _allContacts = [];
  List<Contact> _filtered = [];
  List<RecentContact> _recents = [];
  final Set<String> _selectedIds = {}; // Contact.id
  final Set<String> _selectedRecentNames = {}; // fallback for recents w/o id
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    // Load recents (no permission needed)
    _recents = await RecentContactsService.instance.getRecents();

    // Request permission
    final granted = await PermissionService.instance.requestContacts();
    if (!granted) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _permissionDenied = true;
      });
      return;
    }

    // Fetch device contacts
    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
      sorted: true,
    );

    if (!mounted) return;
    setState(() {
      _allContacts = contacts;
      _filtered = contacts;
      _loading = false;
    });
  }

  void _onSearchChanged(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      if (q.isEmpty) {
        _filtered = _allContacts;
      } else {
        _filtered = _allContacts
            .where((c) => c.displayName.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  void _toggleContact(Contact contact) {
    setState(() {
      if (_selectedIds.contains(contact.id)) {
        _selectedIds.remove(contact.id);
      } else {
        _selectedIds.add(contact.id);
      }
    });
  }

  void _toggleRecent(RecentContact recent) {
    setState(() {
      if (_selectedRecentNames.contains(recent.name)) {
        _selectedRecentNames.remove(recent.name);
      } else {
        _selectedRecentNames.add(recent.name);
      }
    });
  }

  void _confirm() {
    final results = <SelectedContact>[];

    // From device contacts
    for (final contact in _allContacts) {
      if (_selectedIds.contains(contact.id)) {
        final phone = contact.phones.isNotEmpty ? contact.phones.first.number : '';
        results.add(SelectedContact(displayName: contact.displayName, phone: phone));
      }
    }

    // From recents (only those not already added via device contacts)
    final addedPhones = results.map((r) => r.phone).toSet();
    for (final recent in _recents) {
      if (_selectedRecentNames.contains(recent.name)) {
        if (recent.phone.isNotEmpty && addedPhones.contains(recent.phone)) continue;
        results.add(SelectedContact(displayName: recent.name, phone: recent.phone));
      }
    }

    Navigator.of(context).pop(results);
  }

  int get _totalSelected => _selectedIds.length + _selectedRecentNames.length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _totalSelected > 0
              ? 'Select Friends ($_totalSelected)'
              : 'Select Friends',
        ),
        actions: [
          TextButton(
            onPressed: _totalSelected > 0 ? _confirm : null,
            child: const Text('Done'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _permissionDenied
              ? _PermissionDeniedBody(
                  onOpenSettings: () => openAppSettings(),
                  onSkip: () => Navigator.of(context).pop(<SelectedContact>[]),
                )
              : Column(
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Search contacts...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),

                    Expanded(
                      child: CustomScrollView(
                        slivers: [
                          // ── Recents section ──────────────────
                          if (_recents.isNotEmpty && _searchCtrl.text.isEmpty) ...[
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                                child: Text(
                                  'Recent',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final recent = _recents[index];
                                  final isSelected =
                                      _selectedRecentNames.contains(recent.name);
                                  return ListTile(
                                    dense: true,
                                    leading: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: theme.colorScheme.primaryContainer,
                                      child: Text(
                                        recent.name.isNotEmpty
                                            ? recent.name[0].toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          color: theme.colorScheme.onPrimaryContainer,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(recent.name),
                                    subtitle: recent.phone.isNotEmpty
                                        ? Text(
                                            recent.phone,
                                            style: theme.textTheme.bodySmall,
                                          )
                                        : null,
                                    trailing: isSelected
                                        ? Icon(Icons.check_circle,
                                            color: theme.colorScheme.primary)
                                        : const Icon(Icons.circle_outlined,
                                            color: Colors.grey),
                                    onTap: () => _toggleRecent(recent),
                                  );
                                },
                                childCount: _recents.length,
                              ),
                            ),
                            const SliverToBoxAdapter(child: Divider()),
                          ],

                          // ── All contacts section ─────────────
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                              child: Text(
                                'All Contacts (${_filtered.length})',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          _filtered.isEmpty
                              ? SliverFillRemaining(
                                  child: Center(
                                    child: Text(
                                      _searchCtrl.text.isEmpty
                                          ? 'No contacts found on device.'
                                          : 'No results for "${_searchCtrl.text}"',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                )
                              : SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final contact = _filtered[index];
                                      final isSelected =
                                          _selectedIds.contains(contact.id);
                                      final phone = contact.phones.isNotEmpty
                                          ? contact.phones.first.number
                                          : '';

                                      return ListTile(
                                        dense: true,
                                        leading: CircleAvatar(
                                          radius: 18,
                                          backgroundColor:
                                              theme.colorScheme.surfaceContainerHighest,
                                          child: Text(
                                            contact.displayName.isNotEmpty
                                                ? contact.displayName[0].toUpperCase()
                                                : '?',
                                            style: TextStyle(
                                              color: theme.colorScheme.onSurface,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        title: Text(contact.displayName),
                                        subtitle: phone.isNotEmpty
                                            ? Text(phone,
                                                style: theme.textTheme.bodySmall)
                                            : null,
                                        trailing: isSelected
                                            ? Icon(Icons.check_circle,
                                                color: theme.colorScheme.primary)
                                            : const Icon(Icons.circle_outlined,
                                                color: Colors.grey),
                                        onTap: () => _toggleContact(contact),
                                      );
                                    },
                                    childCount: _filtered.length,
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Shown when contacts permission is denied.
// ─────────────────────────────────────────────────────────────────
class _PermissionDeniedBody extends StatelessWidget {
  final VoidCallback onOpenSettings;
  final VoidCallback onSkip;

  const _PermissionDeniedBody({
    required this.onOpenSettings,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.contacts_rounded,
                size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'Contacts permission is needed to select friends.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onOpenSettings,
              child: const Text('Open Settings'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onSkip,
              child: const Text('Skip — add manually'),
            ),
          ],
        ),
      ),
    );
  }
}
