import 'package:flutter/material.dart';
import '../../../core/services/rider_application_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../rider/screens/rider_home_screen.dart';

class BecomeRiderScreen extends StatefulWidget {
  const BecomeRiderScreen({super.key});

  @override
  State<BecomeRiderScreen> createState() => _BecomeRiderScreenState();
}

class _BecomeRiderScreenState extends State<BecomeRiderScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _reasonController = TextEditingController();
  String _vehicleType = 'Motorcycle';
  bool _submitting = false;

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty || _phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in your name and phone.')));
      return;
    }
    setState(() => _submitting = true);
    await RiderApplicationService().submitApplication(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      vehicleType: _vehicleType,
      reason: _reasonController.text.trim(),
    );
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Become a Rider')),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: RiderApplicationService().applicationStatusStream(),
        builder: (context, snapshot) {
          final application = snapshot.data;
          final status = application?['status'] as String?;

          if (status == 'approved') {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 64),
                    const SizedBox(height: 12),
                    const Text('You\'re an approved rider! 🎉', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primaryRosewood, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24)),
                      icon: const Icon(Icons.pedal_bike),
                      label: const Text('Switch to Rider Dashboard'),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const RiderHomeScreen()));
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          if (status == 'pending') {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hourglass_top, color: Colors.orange, size: 64),
                    const SizedBox(height: 12),
                    const Text('Application under review', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text(
                      'Our florist team will review your application shortly.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            );
          }

          if (status == 'rejected') {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 64),
                    const SizedBox(height: 12),
                    const Text('Application not approved', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('Contact the store for more details.', style: TextStyle(color: AppColors.textMuted)),
                  ],
                ),
              ),
            );
          }

          // Unapplied — show the form
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Deliver bouquets around your area and earn on your own schedule.', style: TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 20),
                TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _vehicleType,
                  decoration: const InputDecoration(labelText: 'Vehicle Type', border: OutlineInputBorder()),
                  items: ['Motorcycle', 'Car', 'Bicycle'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (val) => setState(() => _vehicleType = val ?? _vehicleType),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Why do you want to ride with us? (optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primaryRosewood),
                    onPressed: _submitting ? null : _submit,
                    child: _submitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit Application'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}