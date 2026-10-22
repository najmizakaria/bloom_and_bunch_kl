import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/services/commerce_service.dart';

class MessageCardPreview extends StatelessWidget {
  const MessageCardPreview({
    super.key,
    required this.designName,
    required this.message,
    required this.senderName,
    this.imageUrl = '',
  });
  final String designName, message, senderName, imageUrl;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF5EF),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFEBD8CB)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (imageUrl.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Image.network(
              imageUrl,
              height: 120,
              width: double.infinity,
              fit: BoxFit.contain,
              errorBuilder: (_, error, stack) => const SizedBox.shrink(),
            ),
          ),
        Text(
          '${designName.toUpperCase()} CARD',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.brown,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          message.isEmpty ? 'Your message will appear here' : message,
          style: const TextStyle(fontSize: 18, height: 1.5),
        ),
        const SizedBox(height: 32),
        Align(
          alignment: Alignment.centerRight,
          child: Text('From,\n$senderName', textAlign: TextAlign.right),
        ),
      ],
    ),
  );
}

class MessageCardScreen extends StatefulWidget {
  const MessageCardScreen({super.key, required this.group});
  final String group;
  @override
  State<MessageCardScreen> createState() => _MessageCardScreenState();
}

class _MessageCardScreenState extends State<MessageCardScreen> {
  late final _designs = CommerceService.catalogue('card_designs');
  final _message = TextEditingController(), _sender = TextEditingController();
  final _form = GlobalKey<FormState>();
  String? _designId;
  bool _loaded = false, _senderEdited = false;
  @override
  void initState() {
    super.initState();
    _loadAccountName();
  }

  Future<void> _loadAccountName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final profile = await FirebaseFirestore.instance
          .doc('users/${user.uid}')
          .get();
      if (mounted && !_senderEdited && _sender.text.isEmpty) {
        setState(
          () => _sender.text =
              (profile.data()?['name'] ?? user.displayName ?? '').toString(),
        );
      }
    } catch (_) {
      /* Sender remains editable when the profile cannot load. */
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      final saved = context.read<CartProvider>().messageCards[widget.group];
      _designId = saved?['designId'] as String?;
      _message.text = saved?['message'] as String? ?? '';
      _sender.text = saved?['senderName'] as String? ?? '';
      _loaded = true;
    }
  }

  @override
  void dispose() {
    _message.dispose();
    _sender.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your message card')),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _designs,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Card designs could not be loaded. Reopen this screen to retry.',
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final designs = snapshot.data!.docs;
        final matches = designs.where((d) => d.id == _designId);
        final selected = matches.isEmpty ? null : matches.first;
        final data = selected?.data();
        return Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                '1. Choose a design',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (designs.isEmpty)
                const Text('No card designs are available yet.'),
              DropdownButtonFormField<String>(
                key: ValueKey(_designId),
                initialValue: selected?.id,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Card design',
                  border: OutlineInputBorder(),
                ),
                items: designs
                    .map(
                      (design) => DropdownMenuItem(
                        value: design.id,
                        child: Text(
                          '${design.data()['name']} · ${(design.data()['price'] as num) == 0 ? 'Free' : 'RM ${(design.data()['price'] as num).toStringAsFixed(2)}'}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                validator: (value) =>
                    value == null ? 'Choose a card design.' : null,
                onChanged: (value) => setState(() => _designId = value),
              ),
              const SizedBox(height: 24),
              const Text(
                '2. Write your message',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _message,
                maxLength: 1000,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Write something special…',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Write your message.' : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              const Text(
                '3. Name on the card',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sender,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'From',
                  helperText:
                      'Your account name is suggested. You can change it.',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Enter the sender name.'
                    : null,
                onChanged: (_) {
                  _senderEdited = true;
                  setState(() {});
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Preview',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              MessageCardPreview(
                designName: (data?['name'] ?? 'Your design').toString(),
                imageUrl: (data?['imageUrl'] ?? '').toString(),
                message: _message.text,
                senderName: _sender.text,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: designs.isEmpty
                    ? null
                    : () {
                        if (!_form.currentState!.validate() || data == null) {
                          return;
                        }
                        final cart = context.read<CartProvider>();
                        cart.setMessageCard(widget.group, {
                          'designId': selected!.id,
                          'designName': data['name'],
                          'imageUrl': data['imageUrl'] ?? '',
                          'price': data['price'],
                          'message': _message.text.trim(),
                          'senderName': _sender.text.trim(),
                        });
                        if (cart.errorMessage == null) Navigator.pop(context);
                      },
                child: const Text('Save message card'),
              ),
            ],
          ),
        );
      },
    ),
  );
}
