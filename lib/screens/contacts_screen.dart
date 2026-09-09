import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/firestore_service.dart';
import '../models/app_models.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ResponsiveContent(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: StreamBuilder<dynamic>(
            stream: FirestoreService.contactsStream(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              final contacts = docs
                  .map<ContactModel>((d) => ContactModel.fromDoc(d))
                  .toList();
              final family =
                  contacts.where((c) => c.type == 'family').toList();
              final bhw = contacts.where((c) => c.type == 'bhw').toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      'Contacts',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontSize: 22),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _EmergencyContactsBanner(total: contacts.length),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        size: 18,
                        color: Accent.pink,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Family Contacts',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontSize: 15),
                            ),
                            Text(
                              'People who will receive alerts first.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      Material(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () =>
                              _showAddContactSheet(context, defaultType: 'family'),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Add Contact',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        if (family.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'No family contacts added yet.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12.5,
                              ),
                            ),
                          )
                        else
                          for (int i = 0; i < family.length; i++) ...[
                            _ContactTile(contact: family[i]),
                            if (i != family.length - 1) const AppDivider(),
                          ],
                        const AppDivider(),
                        _EditLinkRow(
                          label: 'Add Family Contact',
                          onTap: () => _showAddContactSheet(
                            context,
                            defaultType: 'family',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(
                        Icons.shield_rounded,
                        size: 18,
                        color: Accent.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Barangay Health Worker',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontSize: 15),
                            ),
                            Text(
                              'Health worker who can assist during emergencies.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        if (bhw.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'No barangay health worker added yet.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12.5,
                              ),
                            ),
                          )
                        else
                          for (int i = 0; i < bhw.length; i++) ...[
                            _ContactTile(contact: bhw[i]),
                            if (i != bhw.length - 1) const AppDivider(),
                          ],
                        const AppDivider(),
                        _EditLinkRow(
                          label: 'Add Barangay Health Worker',
                          onTap: () =>
                              _showAddContactSheet(context, defaultType: 'bhw'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: Text(
                      'Make sure your contacts are updated so they can receive alerts when needed.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(fontSize: 11),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showAddContactSheet(
    BuildContext context, {
    required String defaultType,
  }) {
    final nameController = TextEditingController();
    final relationController = TextEditingController();
    final phoneController = TextEditingController();
    String type = defaultType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Contact',
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Name',
                    hint: 'Juan Santos',
                    controller: nameController,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: type == 'bhw' ? 'Role' : 'Relation',
                    hint: type == 'bhw' ? 'Barangay Health Worker' : 'Son',
                    controller: relationController,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Phone Number',
                    hint: '0917 123 4567',
                    keyboardType: TextInputType.phone,
                    controller: phoneController,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Family'),
                          selected: type == 'family',
                          onSelected: (_) =>
                              setSheetState(() => type = 'family'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('BHW'),
                          selected: type == 'bhw',
                          onSelected: (_) =>
                              setSheetState(() => type = 'bhw'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: 'Save Contact',
                    onPressed: () async {
                      if (nameController.text.trim().isEmpty ||
                          phoneController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(
                            content: Text('Please fill in name and phone.'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }
                      await FirestoreService.addContact(
                        name: nameController.text.trim(),
                        relation: relationController.text.trim(),
                        phone: phoneController.text.trim(),
                        type: type,
                      );
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _EmergencyContactsBanner extends StatelessWidget {
  final int total;
  const _EmergencyContactsBanner({required this.total});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.primary.withOpacity(0.06),
      borderColor: AppColors.primary.withOpacity(0.25),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.groups_rounded,
              size: 19,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Emergency Contacts',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  'These people will receive emergency alerts from your Alisto device.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontSize: 11, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$total',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.primary,
                  ),
                ),
                const Text(
                  'Total',
                  style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Note: the call button has been removed per request — tapping a
// contact now only shows a delete option via the trailing icon.
class _ContactTile extends StatelessWidget {
  final ContactModel contact;
  const _ContactTile({required this.contact});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          InitialsAvatar(
            initials: contact.initials,
            color: contact.type == 'bhw' ? Accent.green : Accent.purple,
            size: 40,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  contact.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  '${contact.relation} · ${contact.phone}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 19,
              color: AppColors.textSecondary,
            ),
            onPressed: () => FirestoreService.deleteContact(contact.id),
          ),
        ],
      ),
    );
  }
}

class _EditLinkRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _EditLinkRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }
}
