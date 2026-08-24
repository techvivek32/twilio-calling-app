import 'package:flutter/material.dart';

import '../core/call_launcher.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';
import 'contact_details_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key, this.session});

  final AppSession? session;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  AppSession get _session => widget.session ?? AppSession.instance;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Contact> _filter(List<Contact> contacts) {
    final sorted = [...contacts]..sort((a, b) => a.name.compareTo(b.name));
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return sorted;
    return sorted
        .where(
          (contact) =>
              contact.name.toLowerCase().contains(query) ||
              contact.phone.contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          BrandHeader(
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              color: AppColors.primary,
              padding: EdgeInsets.zero,
              tooltip: 'Back',
            ),
            onBellTap: () => showNotWired(context, 'Notification center'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.xl,
              AppSpace.lg,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contacts',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpace.lg),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    hintText: 'Search contacts or numbers...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncView<List<Contact>>(
              load: _session.loadContacts,
              builder: (context, contacts, reload) {
                final filtered = _filter(contacts);

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: reload,
                  child: filtered.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 80),
                            Center(
                              child: Text(
                                'No contacts yet.\nAdd one from the dialer.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpace.lg),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpace.md),
                          itemBuilder: (context, index) =>
                              _ContactTile(
                                contact: filtered[index],
                                session: widget.session,
                              ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact, this.session});

  final Contact contact;
  final AppSession? session;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ContactDetailsScreen(
            contact: contact,
            session: session,
          ),
        ),
      ),
      child: Row(
        children: [
          InitialsAvatar(name: contact.name, size: 52),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  contact.formattedPhone,
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          CircleActionButton(
            icon: Icons.phone_rounded,
            size: 44,
            iconSize: 20,
            foreground: AppColors.primary,
            tooltip: 'Call',
            onTap: () => _call(context),
          ),
        ],
      ),
    );
  }

  Future<void> _call(BuildContext context) => startCall(
    context,
    number: contact.phone,
    contactName: contact.name,
    displayName: contact.name,
    role: contact.role,
    session: session,
  );
}
