import 'package:flutter/material.dart';
import '../../../core/services/address_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/saved_address_model.dart';

class AddressBookScreen extends StatelessWidget {
  const AddressBookScreen({super.key});

  void _openAddressForm(BuildContext context, {SavedAddressModel? existing}) {
    final labelController = TextEditingController(text: existing?.label ?? '');
    final addressController = TextEditingController(text: existing?.address ?? '');
    final nameController = TextEditingController(text: existing?.recipientName ?? '');
    final phoneController = TextEditingController(text: existing?.recipientPhone ?? '');
    final noteController = TextEditingController(text: existing?.note ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(existing == null ? 'Add Address' : 'Edit Address', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: labelController, decoration: const InputDecoration(labelText: 'Label (e.g. Home, Office)')),
              const SizedBox(height: 10),
              TextField(controller: addressController, maxLines: 2, decoration: const InputDecoration(labelText: 'Full Address')),
              const SizedBox(height: 10),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Recipient Name')),
              const SizedBox(height: 10),
              TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Recipient Phone')),
              const SizedBox(height: 10),
              TextField(controller: noteController, decoration: const InputDecoration(labelText: 'Drop-off note (optional)', hintText: 'e.g. Leave with receptionist')),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primaryRosewood, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () async {
                    if (labelController.text.trim().isEmpty || addressController.text.trim().isEmpty) return;
                    await AddressService().saveAddress(SavedAddressModel(
                      id: existing?.id ?? '',
                      label: labelController.text.trim(),
                      address: addressController.text.trim(),
                      recipientName: nameController.text.trim(),
                      recipientPhone: phoneController.text.trim(),
                      note: noteController.text.trim(),
                      isDefault: existing?.isDefault ?? false,
                    ));
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Save Address'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Address Book'),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: () => _openAddressForm(context))],
      ),
      body: StreamBuilder<List<SavedAddressModel>>(
        stream: AddressService().addressesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final addresses = snapshot.data ?? [];
          if (addresses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 64, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    const Text('No saved addresses yet', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primaryRosewood),
                      onPressed: () => _openAddressForm(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add your first address'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: addresses.length,
            itemBuilder: (context, index) {
              final addr = addresses[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.secondarySurface,
                    child: Icon(Icons.location_on, color: AppColors.primaryRosewood),
                  ),
                  title: Text(addr.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${addr.address}\n${addr.recipientName} · ${addr.recipientPhone}'),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') _openAddressForm(context, existing: addr);
                      if (value == 'delete') AddressService().deleteAddress(addr.id);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
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