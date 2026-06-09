// lib/screens/products/product_images_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/product_image_provider.dart';
import '../../models/product_image_model.dart';
import '../components/loading_indicator.dart';
import '../providers/lanprovider.dart';

class ProductImagesScreen extends StatefulWidget {
  final int productId;
  final String productName;

  const ProductImagesScreen({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  State<ProductImagesScreen> createState() => _ProductImagesScreenState();
}

class _ProductImagesScreenState extends State<ProductImagesScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    final provider = Provider.of<ProductImageProvider>(context, listen: false);
    await provider.fetchProductImages(widget.productId);
  }

  Future<void> _pickImages() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    try {
      final List<XFile>? pickedFiles = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFiles != null && pickedFiles.isNotEmpty) {
        final List<File> imageFiles = pickedFiles.map((xfile) => File(xfile.path)).toList();

        setState(() {
          _isUploading = true;
        });

        final provider = Provider.of<ProductImageProvider>(context, listen: false);
        final result = await provider.uploadImages(widget.productId, imageFiles);

        setState(() {
          _isUploading = false;
        });

        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                languageProvider.isEnglish
                    ? '${imageFiles.length} image(s) uploaded successfully'
                    : '${imageFiles.length} تصویر(یں) کامیابی سے اپ لوڈ ہوگئیں',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['error'] ?? (languageProvider.isEnglish ? 'Failed to upload images' : 'تصاویر اپ لوڈ کرنے میں ناکامی'),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.isEnglish
                ? 'Error picking images: $e'
                : 'تصاویر منتخب کرنے میں خرابی: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _takePhoto() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);

        setState(() {
          _isUploading = true;
        });

        final provider = Provider.of<ProductImageProvider>(context, listen: false);
        final result = await provider.uploadImages(widget.productId, [imageFile]);

        setState(() {
          _isUploading = false;
        });

        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                languageProvider.isEnglish
                    ? 'Image uploaded successfully'
                    : 'تصویر کامیابی سے اپ لوڈ ہوگئی',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['error'] ?? (languageProvider.isEnglish ? 'Failed to upload image' : 'تصویر اپ لوڈ کرنے میں ناکامی'),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.isEnglish
                ? 'Error taking photo: $e'
                : 'تصویر لینے میں خرابی: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImageSourceDialog() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              languageProvider.isEnglish ? 'Add Images' : 'تصاویر شامل کریں',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3142),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library, color: Color(0xFF7C3AED)),
              ),
              title: Text(languageProvider.isEnglish ? 'Choose from Gallery' : 'گیلری سے منتخب کریں'),
              subtitle: Text(languageProvider.isEnglish ? 'Select multiple images' : 'متعدد تصاویر منتخب کریں'),
              onTap: () {
                Navigator.pop(context);
                _pickImages();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt, color: Color(0xFF7C3AED)),
              ),
              title: Text(languageProvider.isEnglish ? 'Take Photo' : 'تصویر لیں'),
              subtitle: Text(languageProvider.isEnglish ? 'Use camera' : 'کیمرہ استعمال کریں'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteImage(ProductImage image) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.isEnglish ? 'Delete Image' : 'تصویر حذف کریں'),
        content: Text(
          languageProvider.isEnglish
              ? 'Are you sure you want to delete this image?'
              : 'کیا آپ واقعی اس تصویر کو حذف کرنا چاہتے ہیں؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(languageProvider.isEnglish ? 'Delete' : 'حذف کریں'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      final provider = Provider.of<ProductImageProvider>(context, listen: false);
      final result = await provider.deleteImage(image.id);

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.isEnglish
                  ? 'Image deleted successfully'
                  : 'تصویر کامیابی سے حذف ہوگئی',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['error'] ?? (languageProvider.isEnglish ? 'Failed to delete image' : 'تصویر حذف کرنے میں ناکامی'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _setAsPrimary(ProductImage image) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final provider = Provider.of<ProductImageProvider>(context, listen: false);
    final result = await provider.setPrimaryImage(image.id);

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.isEnglish
                ? 'Primary image updated'
                : 'مرکزی تصویر اپ ڈیٹ ہوگئی',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['error'] ?? (languageProvider.isEnglish ? 'Failed to set primary image' : 'مرکزی تصویر سیٹ کرنے میں ناکامی'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImageOptions(ProductImage image) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.star, color: Color(0xFF7C3AED)),
              title: Text(languageProvider.isEnglish ? 'Set as Primary' : 'بطور مرکزی سیٹ کریں'),
              onTap: () {
                Navigator.pop(context);
                _setAsPrimary(image);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text(languageProvider.isEnglish ? 'Delete Image' : 'تصویر حذف کریں'),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteImage(image);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFFAFAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  languageProvider.isEnglish ? 'Product Images' : 'پروڈکٹ کی تصاویر',
                  style: const TextStyle(
                    color: Color(0xFF2D3142),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  widget.productName,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontFamily: languageProvider.fontFamily,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF7C3AED)),
                onPressed: _showImageSourceDialog,
                tooltip: languageProvider.isEnglish ? 'Add Images' : 'تصاویر شامل کریں',
              ),
            ],
          ),
          body: Consumer<ProductImageProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading && provider.images.isEmpty) {
                return const LoadingIndicator();
              }

              final images = provider.getImagesForProduct(widget.productId);

              if (images.isEmpty && !_isUploading) {
                return _buildEmptyState(languageProvider);
              }

              return Stack(
                children: [
                  GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1,
                    ),
                    itemCount: images.length,
                    itemBuilder: (context, index) {
                      final image = images[index];
                      return _buildImageCard(image, languageProvider);
                    },
                  ),
                  if (_isUploading)
                    Container(
                      color: Colors.black.withOpacity(0.3),
                      child: const Center(
                        child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildImageCard(ProductImage image, LanguageProvider languageProvider) {
    return GestureDetector(
      onTap: () => _showFullScreenImage(image),
      onLongPress: () => _showImageOptions(image),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: image.isPrimary ? const Color(0xFF7C3AED) : const Color(0xFFF0F0F5),
            width: image.isPrimary ? 2 : 1.5,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                image.imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                            : null,
                        color: const Color(0xFF7C3AED),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, color: Colors.grey, size: 40),
                  );
                },
              ),
            ),
            if (image.isPrimary)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        languageProvider.isEnglish ? 'Primary' : 'مرکزی',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white, size: 18),
                  onPressed: () => _showImageOptions(image),
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(LanguageProvider languageProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            languageProvider.isEnglish ? 'No Images' : 'کوئی تصویر نہیں',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              fontFamily: languageProvider.fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            languageProvider.isEnglish
                ? 'Add images to showcase your product'
                : 'اپنی پروڈکٹ دکھانے کے لیے تصاویر شامل کریں',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
              fontFamily: languageProvider.fontFamily,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showImageSourceDialog,
            icon: const Icon(Icons.add_photo_alternate),
            label: Text(languageProvider.isEnglish ? 'Add Images' : 'تصاویر شامل کریں'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(ProductImage image) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                image.imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                          : null,
                      color: Colors.white,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[800],
                    child: const Center(
                      child: Icon(Icons.broken_image, color: Colors.white, size: 50),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}