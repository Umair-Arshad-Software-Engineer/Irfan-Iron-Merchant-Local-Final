// lib/screens/sales/sale_image_manager.dart
//
// Two widgets exported from this file:
//
//  1. SaleImageManager  – full-screen page (push via Navigator) to add/view/delete
//  2. SaleImageGallery  – compact inline strip used inside the sale card
//
// Usage in sales_list_screen.dart inside _buildSaleCard():
//
//   // Inline gallery strip (add near action buttons)
//   SaleImageGallery(saleId: sale.id, isCompact: _isCompact),
//
//   // Navigate to manager
//   IconButton(
//     icon: Icon(Icons.image),
//     onPressed: () => Navigator.push(context,
//       MaterialPageRoute(builder: (_) =>
//         SaleImageManager(saleId: sale.id, invoiceNumber: sale.invoiceNumber))),
//   ),

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/sale_image_provider.dart';
import '../providers/lanprovider.dart';

// ═══════════════════════════════════════════════════════════════
//  HELPER – image type metadata
// ═══════════════════════════════════════════════════════════════
const _imageTypes = [
  {'type': 'signature', 'title': 'Signature',     'titleUr': 'دستخط',      'icon': Icons.edit},
  {'type': 'stamp',     'title': 'Stamp',          'titleUr': 'مہر',        'icon': Icons.approval},
  {'type': 'note',      'title': 'Note',           'titleUr': 'نوٹ',        'icon': Icons.note},
  {'type': 'delivery',  'title': 'Delivery Proof', 'titleUr': 'ڈیلیوری',   'icon': Icons.local_shipping},
  {'type': 'custom',    'title': 'Custom',         'titleUr': 'کسٹم',      'icon': Icons.photo},
];

String _typeLabel(String type, bool isEnglish) {
  final meta = _imageTypes.firstWhere(
        (m) => m['type'] == type,
    orElse: () => {'title': type, 'titleUr': type},
  );
  return isEnglish ? (meta['title'] as String) : (meta['titleUr'] as String);
}

// ═══════════════════════════════════════════════════════════════
//  SALE IMAGE MANAGER  (full-screen page)
// ═══════════════════════════════════════════════════════════════
class SaleImageManager extends StatefulWidget {
  final int saleId;
  final String invoiceNumber;

  const SaleImageManager({
    super.key,
    required this.saleId,
    required this.invoiceNumber,
  });

  @override
  State<SaleImageManager> createState() => _SaleImageManagerState();
}

class _SaleImageManagerState extends State<SaleImageManager> {
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SaleImageProvider>().fetchImages(widget.saleId);
    });
  }

  // ── Pick image from gallery or camera ──────────────────────
  Future<void> _pickAndUpload(String imageType) async {
    final source = await _showSourceSheet();
    if (source == null) return;

    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final base64 = base64Encode(bytes);

    setState(() => _isSaving = true);
    final result = await context.read<SaleImageProvider>().uploadImage(
      saleId: widget.saleId,
      base64Data: base64,
      imageType: imageType,
      description: 'Image for sale ${widget.invoiceNumber}',
    );
    setState(() => _isSaving = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result['success'] == true
          ? 'Image saved successfully'
          : result['message'] ?? 'Upload failed'),
      backgroundColor:
      result['success'] == true ? Colors.green : Colors.red,
    ));
  }

  Future<ImageSource?> _showSourceSheet() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choose from Gallery'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          if (!kIsWeb)
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
        ]),
      ),
    );
  }

  Future<void> _confirmDelete(int imageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Image'),
        content: const Text('Are you sure you want to delete this image?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await context
        .read<SaleImageProvider>()
        .deleteImage(widget.saleId, imageId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['success'] == true
            ? 'Image deleted'
            : result['message'] ?? 'Delete failed'),
        backgroundColor:
        result['success'] == true ? Colors.green : Colors.red,
      ));
    }
  }

  void _viewFullImage(SaleImageFull image, bool isEnglish) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(children: [
          Center(
            child: InteractiveViewer(
              child: Image.memory(
                Uint8List.fromList(image.imageBytes),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                const Icon(Icons.broken_image, color: Colors.white, size: 60),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _typeLabel(image.imageType, isEnglish).toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  if (image.description != null &&
                      image.description!.isNotEmpty)
                    Text(image.description!,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  Text(
                    'Uploaded: ${image.createdAt.toLocal().toString().split(' ').first}',
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          // Delete button inside full-image view
          Positioned(
            bottom: 80,
            right: 16,
            child: FloatingActionButton.small(
              backgroundColor: Colors.red,
              onPressed: () {
                Navigator.pop(context);
                _confirmDelete(image.id);
              },
              child: const Icon(Icons.delete, color: Colors.white),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final provider = context.watch<SaleImageProvider>();
    final images = provider.imagesFor(widget.saleId);
    final loading = provider.isLoading(widget.saleId);

    // Build a type→meta map for quick lookup
    final Map<String, SaleImageMeta> byType = {
      for (final img in images) img.imageType: img
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(
          lang.isEnglish
              ? 'Sale Images – ${widget.invoiceNumber}'
              : 'فروخت کی تصاویر – ${widget.invoiceNumber}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        backgroundColor: const Color(0xFF7C3AED),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Current images ─────────────────────────
                if (images.isNotEmpty) ...[
                  Text(
                    lang.isEnglish
                        ? 'Uploaded Images (${images.length})'
                        : 'اپ لوڈ تصاویر (${images.length})',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: images.length,
                    itemBuilder: (_, i) {
                      final meta = images[i];
                      return GestureDetector(
                        onTap: () async {
                          final full = await provider.fetchImageData(
                              widget.saleId, meta.id);
                          if (full != null && mounted) {
                            _viewFullImage(full, lang.isEnglish);
                          }
                        },
                        child: _ImageThumbnailCard(
                          meta: meta,
                          saleId: widget.saleId,
                          isEnglish: lang.isEnglish,
                          onDelete: () => _confirmDelete(meta.id),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 28),
                ],

                // ── Add / replace by type ──────────────────
                Text(
                  lang.isEnglish
                      ? 'Add / Replace Image:'
                      : 'تصویر شامل کریں / تبدیل کریں:',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _imageTypes.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final meta = _imageTypes[i];
                    final type = meta['type'] as String;
                    final hasImage = byType.containsKey(type);
                    final title = lang.isEnglish
                        ? meta['title'] as String
                        : meta['titleUr'] as String;

                    return Card(
                      color: hasImage
                          ? Colors.green.shade50
                          : Colors.grey.shade50,
                      child: ListTile(
                        leading: Icon(
                          meta['icon'] as IconData,
                          color: hasImage
                              ? Colors.green
                              : const Color(0xFF7C3AED),
                        ),
                        title: Text(title,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: hasImage
                                    ? Colors.green.shade800
                                    : Colors.black87)),
                        subtitle: Text(
                          hasImage
                              ? (lang.isEnglish
                              ? '✓ Image uploaded'
                              : '✓ تصویر موجود ہے')
                              : (lang.isEnglish
                              ? 'No image yet'
                              : 'ابھی کوئی تصویر نہیں'),
                          style: TextStyle(
                              color: hasImage
                                  ? Colors.green
                                  : Colors.grey),
                        ),
                        trailing: Icon(
                          hasImage
                              ? Icons.refresh
                              : Icons.add_photo_alternate,
                          color: hasImage
                              ? Colors.orange
                              : const Color(0xFF7C3AED),
                        ),
                        onTap: () => _pickAndUpload(type),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Saving overlay
          if (_isSaving)
            Container(
              color: Colors.black38,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Saving image…'),
                    ]),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  THUMBNAIL CARD  (used inside SaleImageManager grid)
// ═══════════════════════════════════════════════════════════════
class _ImageThumbnailCard extends StatefulWidget {
  final SaleImageMeta meta;
  final int saleId;
  final bool isEnglish;
  final VoidCallback onDelete;

  const _ImageThumbnailCard({
    required this.meta,
    required this.saleId,
    required this.isEnglish,
    required this.onDelete,
  });

  @override
  State<_ImageThumbnailCard> createState() => _ImageThumbnailCardState();
}

class _ImageThumbnailCardState extends State<_ImageThumbnailCard> {
  SaleImageFull? _full;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final full = await context
        .read<SaleImageProvider>()
        .fetchImageData(widget.saleId, widget.meta.id);
    if (mounted) setState(() => _full = full);
  }

  @override
  Widget build(BuildContext context) {
    final bytes =
    _full != null ? Uint8List.fromList(_full!.imageBytes) : null;

    return Stack(
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Column(
            children: [
              Expanded(
                child: bytes != null && bytes.isNotEmpty
                    ? Image.memory(bytes,
                    fit: BoxFit.cover, width: double.infinity)
                    : const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              Container(
                width: double.infinity,
                color: const Color(0xFF7C3AED).withOpacity(0.08),
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  _typeLabel(widget.meta.imageType, widget.isEnglish),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: widget.onDelete,
            child: Container(
              decoration: const BoxDecoration(
                  color: Colors.red, shape: BoxShape.circle),
              padding: const EdgeInsets.all(2),
              child:
              const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SALE IMAGE GALLERY  (inline strip used inside sale card)
// ═══════════════════════════════════════════════════════════════
class SaleImageGallery extends StatefulWidget {
  final int saleId;
  final bool isCompact;

  const SaleImageGallery({
    super.key,
    required this.saleId,
    this.isCompact = false,
  });

  @override
  State<SaleImageGallery> createState() => _SaleImageGalleryState();
}

class _SaleImageGalleryState extends State<SaleImageGallery> {
  // local full-image cache so we only fetch once per render
  final Map<int, SaleImageFull?> _fullCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SaleImageProvider>().fetchImages(widget.saleId);
    });
  }

  Future<SaleImageFull?> _getOrFetch(int imageId) async {
    if (_fullCache.containsKey(imageId)) return _fullCache[imageId];
    final full = await context
        .read<SaleImageProvider>()
        .fetchImageData(widget.saleId, imageId);
    if (mounted) setState(() => _fullCache[imageId] = full);
    return full;
  }

  void _showFull(SaleImageFull image, bool isEnglish) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.memory(
                  Uint8List.fromList(image.imageBytes),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image,
                      color: Colors.white,
                      size: 60),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close,
                    color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6)),
                child: Text(
                  _typeLabel(image.imageType, isEnglish).toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final provider = context.watch<SaleImageProvider>();
    final images = provider.imagesFor(widget.saleId);

    if (images.isEmpty) return const SizedBox.shrink();

    final tileSize = widget.isCompact ? 72.0 : 90.0;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.photo_library,
                color: Colors.purple.shade700, size: 16),
            const SizedBox(width: 6),
            Text(
              lang.isEnglish
                  ? 'Attached Images (${images.length})'
                  : 'منسلک تصاویر (${images.length})',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: widget.isCompact ? 12 : 14,
                color: Colors.purple.shade800,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: tileSize + 20,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final meta = images[i];
                return FutureBuilder<SaleImageFull?>(
                  future: _getOrFetch(meta.id),
                  builder: (_, snap) {
                    final full = snap.data ?? _fullCache[meta.id];
                    final bytes = full != null
                        ? Uint8List.fromList(full.imageBytes)
                        : null;

                    return GestureDetector(
                      onTap: full != null
                          ? () => _showFull(full, lang.isEnglish)
                          : null,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: tileSize,
                            height: tileSize,
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.purple.shade300, width: 1.5),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: bytes != null && bytes.isNotEmpty
                                ? Image.memory(bytes, fit: BoxFit.cover)
                                : const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          SizedBox(
                            width: tileSize,
                            child: Text(
                              _typeLabel(
                                  meta.imageType, lang.isEnglish),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: widget.isCompact ? 9 : 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}