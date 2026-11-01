import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/commerce_service.dart';
import '../../../core/services/order_service.dart';
import '../../../core/services/product_image.dart';
import '../../../core/widgets/firestore_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../admin/admin_theme.dart';

class CommerceCatalogueScreen extends StatefulWidget {
  const CommerceCatalogueScreen({super.key, required this.kind});
  final String kind;
  @override
  State<CommerceCatalogueScreen> createState() =>
      _CommerceCatalogueScreenState();
}

class _CommerceCatalogueScreenState extends State<CommerceCatalogueScreen> {
  late final _query = FirebaseFirestore.instance
      .collection(widget.kind)
      .orderBy(FieldPath.documentId);
  final _updating = <String>{};

  Future<void> _updateProduct(
    String id,
    Map<String, dynamic> saved,
    Map<String, dynamic> changes,
  ) async {
    if (_updating.contains(id)) return;
    setState(() => _updating.add(id));
    try {
      await CommerceService.saveProduct(
        widget.kind,
        id,
        (saved['revision'] as num?)?.toInt() ?? 0,
        {
          'name': saved['name'],
          'price': saved['price'],
          'imageUrl': saved['imageUrl'] ?? '',
          'isPublished': saved['isPublished'] == true,
          if (widget.kind == 'addons') ...{
            'category': saved['category'],
            'stockQuantity': saved['stockQuantity'] ?? 0,
          },
          ...changes,
        },
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(OrderService.message(error))));
      }
    } finally {
      if (mounted) setState(() => _updating.remove(id));
    }
  }

  Future<void> _edit({String? id, Map<String, dynamic>? saved}) async {
    final name = TextEditingController(text: saved?['name'] as String? ?? ''),
        price = TextEditingController(text: '${saved?['price'] ?? 0}'),
        image = TextEditingController(
          text: saved?['imageUrl'] as String? ?? '',
        ),
        category = TextEditingController(
          text: saved?['category'] as String? ?? 'Plush',
        ),
        stock = TextEditingController(text: '${saved?['stockQuantity'] ?? 0}');
    var published = saved?['isPublished'] == true, busy = false;
    var picking = false;
    ProductImage? selectedImage;
    String? uploadedImageUrl;
    String? error;
    final form = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, setDialog) => PopScope(
          canPop: !busy && !picking,
          child: AlertDialog(
            title: Text(
              '${id == null ? 'Add' : 'Edit'} ${widget.kind == 'addons' ? 'Add-on' : 'Card Design'}',
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: AbsorbPointer(
                  absorbing: busy || picking,
                  child: Form(
                    key: form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: image,
                          builder: (context, value, child) => Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 150,
                                  child: selectedImage != null
                                      ? Image.memory(
                                          selectedImage!.bytes,
                                          fit: BoxFit.contain,
                                        )
                                      : _CataloguePhoto(
                                          url: value.text.trim(),
                                          isCard: widget.kind == 'card_designs',
                                        ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      setDialog(() {
                                        picking = true;
                                        error = null;
                                      });
                                      try {
                                        final file = await ImagePicker()
                                            .pickImage(
                                              source: ImageSource.gallery,
                                            );
                                        if (file == null) return;
                                        final photo = await ProductImage.read(
                                          file,
                                        );
                                        if (!dialog.mounted) return;
                                        setDialog(() {
                                          selectedImage = photo;
                                          uploadedImageUrl = null;
                                        });
                                      } catch (e) {
                                        if (dialog.mounted) {
                                          setDialog(
                                            () => error = e is StateError
                                                ? e.message.toString()
                                                : 'Could not open this image. Please try again.',
                                          );
                                        }
                                      } finally {
                                        if (dialog.mounted) {
                                          setDialog(() => picking = false);
                                        }
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.add_photo_alternate_outlined,
                                    ),
                                    label: Text(
                                      picking
                                          ? 'Opening photos…'
                                          : selectedImage != null ||
                                                value.text.trim().isNotEmpty
                                          ? 'Replace image'
                                          : 'Choose image',
                                    ),
                                  ),
                                  if (selectedImage != null ||
                                      value.text.trim().isNotEmpty)
                                    TextButton.icon(
                                      onPressed: () => setDialog(() {
                                        selectedImage = null;
                                        uploadedImageUrl = null;
                                        image.clear();
                                      }),
                                      icon: const Icon(Icons.delete_outline),
                                      label: const Text('Remove image'),
                                    ),
                                ],
                              ),

                              if (selectedImage != null)
                                const Text(
                                  'New image will upload when you save.',
                                ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                        TextFormField(
                          controller: name,
                          maxLength: 160,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: widget.kind == 'addons'
                                ? 'Add-on name'
                                : 'Card design name',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              (v ?? '').trim().isEmpty ? 'Enter a name.' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: price,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Price',
                            prefixText: 'RM ',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final n = double.tryParse(v ?? '');
                            return n == null ||
                                    !n.isFinite ||
                                    n < 0 ||
                                    n > 100000
                                ? 'Enter a valid price.'
                                : null;
                          },
                        ),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Use an image link instead'),
                          children: [
                            TextFormField(
                              controller: image,
                              enabled: selectedImage == null,
                              maxLength: 2048,
                              decoration: const InputDecoration(
                                labelText: 'Image URL (HTTPS, optional)',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  (v ?? '').isNotEmpty &&
                                      !(v ?? '').startsWith('https://')
                                  ? 'Use an HTTPS URL.'
                                  : null,
                            ),
                          ],
                        ),
                        if (widget.kind == 'addons') ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: category,
                            maxLength: 60,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              hintText: 'Example: Plush, Chocolates, Toppers',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v ?? '').trim().isEmpty
                                ? 'Enter a category.'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: stock,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Available stock',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              return n == null || n < 0 || n > 999999
                                  ? 'Enter a whole number from 0 to 999999.'
                                  : null;
                            },
                          ),
                        ],
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Published to customers'),
                          value: published,
                          onChanged: busy
                              ? null
                              : (v) => setDialog(() => published = v),
                        ),
                        if (error != null)
                          Text(
                            error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy || picking ? null : () => Navigator.pop(dialog),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AdminTheme.sharedColor(
                    context,
                    AppColors.primary,
                  ),
                  foregroundColor: AppColors.onPrimary,
                ),
                onPressed: busy || picking
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        FocusScope.of(dialog).unfocus();
                        final data = <String, dynamic>{
                          'name': name.text.trim(),
                          'price': double.parse(price.text),
                          'imageUrl': image.text.trim(),
                          'isPublished': published,
                          if (widget.kind == 'addons')
                            'category': category.text.trim(),
                          if (widget.kind == 'addons')
                            'stockQuantity': int.parse(stock.text),
                        };
                        setDialog(() {
                          busy = true;
                          error = null;
                        });
                        try {
                          if (selectedImage != null) {
                            uploadedImageUrl ??= await selectedImage!.upload(
                              widget.kind,
                            );
                            data['imageUrl'] = uploadedImageUrl;
                          }
                          await CommerceService.saveProduct(
                            widget.kind,
                            id ??
                                FirebaseFirestore.instance
                                    .collection(widget.kind)
                                    .doc()
                                    .id,
                            (saved?['revision'] as num?)?.toInt() ?? 0,
                            data,
                          );
                          if (dialog.mounted) Navigator.pop(dialog);
                        } catch (e) {
                          if (dialog.mounted) {
                            setDialog(() {
                              error = OrderService.message(e);
                              busy = false;
                            });
                          }
                        }
                      },
                child: busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        id != null
                            ? 'Save Changes'
                            : widget.kind == 'addons'
                            ? 'Add Add-on'
                            : 'Add Card Design',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    // Dialog route transitions finish before its text controllers are disposed.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    name.dispose();
    price.dispose();
    image.dispose();
    category.dispose();
    stock.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AdminTheme.sharedColor(context, AppColors.background),
    floatingActionButton: FloatingActionButton.extended(
      backgroundColor: AdminTheme.sharedColor(context, AppColors.primary),
      foregroundColor: AppColors.onPrimary,
      onPressed: () => _edit(),
      icon: const Icon(Icons.add),
      label: Text(widget.kind == 'addons' ? 'Add Add-on' : 'Add Card Design'),
    ),
    body: FirestorePage(
      query: _query,
      emptyMessage: widget.kind == 'addons'
          ? 'No add-ons yet. Use Add Add-on to create one.'
          : 'No card designs yet. Use Add Card Design to create one.',
      builder: (context, products) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final document = products[index];
          final data = document.data();
          final stock = (data['stockQuantity'] as num?)?.toInt() ?? 0;
          return CommerceInventoryCard(
            product: data,
            isCard: widget.kind == 'card_designs',
            busy: _updating.contains(document.id),
            onEdit: () => _edit(id: document.id, saved: data),
            onDecreaseStock: () =>
                _updateProduct(document.id, data, {'stockQuantity': stock - 1}),
            onIncreaseStock: () =>
                _updateProduct(document.id, data, {'stockQuantity': stock + 1}),
            onPublishedChanged: (value) =>
                _updateProduct(document.id, data, {'isPublished': value}),
          );
        },
      ),
    ),
  );
}

class CommerceInventoryCard extends StatelessWidget {
  const CommerceInventoryCard({
    super.key,
    required this.product,
    required this.isCard,
    required this.onEdit,
    required this.onDecreaseStock,
    required this.onIncreaseStock,
    required this.onPublishedChanged,
    this.busy = false,
  });

  final Map<String, dynamic> product;
  final bool isCard, busy;
  final VoidCallback onEdit, onDecreaseStock, onIncreaseStock;
  final ValueChanged<bool> onPublishedChanged;

  @override
  Widget build(BuildContext context) {
    final stock = (product['stockQuantity'] as num?)?.toInt() ?? 0;
    final published = product['isPublished'] == true;
    final primary = AdminTheme.sharedColor(context, AppColors.primary);
    final statusColor = published && (isCard || stock > 0)
        ? primary
        : Colors.grey.shade600;
    final status = !published
        ? 'Unpublished'
        : isCard
        ? 'Published'
        : stock == 0
        ? 'Out of stock'
        : stock <= 5
        ? 'Low stock'
        : 'In stock';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 78,
                  height: 88,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _CataloguePhoto(
                      url: product['imageUrl'] as String? ?? '',
                      isCard: isCard,
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['name'] as String? ?? 'Unnamed',
                        style: const AppTypography.productTitle(),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isCard
                            ? 'Message card'
                            : product['category'] as String? ?? 'Uncategorised',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'RM ${(product['price'] as num? ?? 0).toStringAsFixed(2)}',
                        style: AppTypography.price(color: primary),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 5,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Icon(
                            !published
                                ? Icons.visibility_off_outlined
                                : !isCard && stock == 0
                                ? Icons.cancel_outlined
                                : !isCard && stock <= 5
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_outline,
                            size: 16,
                            color: statusColor,
                          ),
                          Text(
                            status,
                            style: AppTypography.badge(color: statusColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: isCard ? 'Edit card design' : 'Edit add-on',
                  onPressed: busy ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              children: [
                if (!isCard) ...[
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Stock', style: AppTypography.label()),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Decrease stock',
                            onPressed: busy || stock <= 0
                                ? null
                                : onDecreaseStock,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              minWidth: 38,
                              maxWidth: 84,
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '$stock',
                                style: const AppTypography.productTitle(),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Increase stock',
                            onPressed: busy || stock >= 999999
                                ? null
                                : onIncreaseStock,
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: MergeSemantics(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (busy) ...[
                          const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                        ],
                        const Flexible(
                          child: Text(
                            'Published',
                            style: AppTypography.caption(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch.adaptive(
                          value: published,
                          activeThumbColor: primary,
                          onChanged: busy ? null : onPublishedChanged,
                        ),
                      ],
                    ),
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

class _CataloguePhoto extends StatelessWidget {
  const _CataloguePhoto({required this.url, required this.isCard});
  final String url;
  final bool isCard;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: AdminTheme.sharedColor(context, AppColors.inputFill),
      child: Center(
        child: Icon(
          isCard ? Icons.mail_outline : Icons.redeem,
          color: AdminTheme.sharedColor(context, AppColors.primary),
          size: 36,
        ),
      ),
    );
    if (url.isEmpty) return placeholder;
    return Image.network(
      url,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stack) => Tooltip(
        message: 'Image unavailable. Edit this item to replace it.',
        child: placeholder,
      ),
    );
  }
}
