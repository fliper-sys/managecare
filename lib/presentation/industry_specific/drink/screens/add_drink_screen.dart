import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../providers/drink_provider.dart';
import '../../../../services/email_service.dart';

class AddDrinkScreen extends StatefulWidget {
  final DrinkItem? editDrink;
  const AddDrinkScreen({this.editDrink, super.key});

  @override
  State<AddDrinkScreen> createState() => _AddDrinkScreenState();
}

class _AddDrinkScreenState extends State<AddDrinkScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _bottlesPerCarton = TextEditingController();
  final _emoji = TextEditingController();
  final _imageUrl = TextEditingController();
  final _category = TextEditingController();
  final _description = TextEditingController();

  File? _selectedImageFile;
  bool _saving = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final e = widget.editDrink;
    if (e != null) {
      _name.text = e.name;
      _price.text = e.pricePerBottle.toString();
      _bottlesPerCarton.text = e.bottlesPerCarton.toString();
      _emoji.text = e.emoji;
      _imageUrl.text = e.imageUrl ?? '';
      _category.text = e.category;
      _description.text = e.description;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _bottlesPerCarton.dispose();
    _emoji.dispose();
    _imageUrl.dispose();
    _category.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      final file = File(pickedFile.path);
      setState(() {
        _selectedImageFile = file;
        _saving = true;
      });

      try {
        // Upload using EmailService (PHP endpoint)
        final url = await EmailService().uploadFile(file);
        if (url != null) {
          setState(() => _imageUrl.text = url);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Image uploaded successfully')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Upload failed')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload error: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _saving = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final provider = Provider.of<DrinkProvider>(context, listen: false);
    final id = widget.editDrink?.id ??
        DateTime.now().millisecondsSinceEpoch.toString();
    final drink = DrinkItem(
      id: id,
      name: _name.text.trim(),
      pricePerBottle: double.tryParse(_price.text) ?? 0.0,
      bottlesPerCarton: int.tryParse(_bottlesPerCarton.text) ?? 1,
      emoji: _emoji.text.isNotEmpty ? _emoji.text : '🥤',
      imageUrl: _imageUrl.text.isNotEmpty ? _imageUrl.text : null,
      category: _category.text.isNotEmpty ? _category.text : 'Drinks',
      description: _description.text,
    );

    // Update local provider
    final existingIndex = provider.drinks.indexWhere((d) => d.id == id);
    if (existingIndex >= 0) {
      provider.drinks[existingIndex] = drink;
    } else {
      provider.drinks.add(drink);
    }

    // Persist via repository if available
    try {
      if (provider.repository != null) {
        await provider.repository!.saveDrink(drink);
        // ensure there is an inventory entry
        final s = provider.getStock(drink.id);
        if (s == null) {
          provider
              .addStock(StockItem(drinkId: drink.id, bottles: 0, cartons: 0));
          await provider.repository!
              .updateStock(drink.id, provider.getStock(drink.id)!);
        }
      }
    } catch (e) {
      // ignore persistence errors for now but notify
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Save warning: $e')));
    }

    setState(() => _saving = false);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.editDrink != null ? 'Edit Drink' : 'Add Drink')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null),
              TextFormField(
                  controller: _price,
                  decoration:
                      const InputDecoration(labelText: 'Price per bottle'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null),
              TextFormField(
                  controller: _bottlesPerCarton,
                  decoration:
                      const InputDecoration(labelText: 'Bottles per carton'),
                  keyboardType: TextInputType.number),
              TextFormField(
                  controller: _emoji,
                  decoration:
                      const InputDecoration(labelText: 'Emoji (optional)')),
              TextFormField(
                  controller: _category,
                  decoration: const InputDecoration(labelText: 'Category')),
              TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2),
              const SizedBox(height: 16),
              // Image preview and picker
              _selectedImageFile != null || _imageUrl.text.isNotEmpty
                  ? Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[200],
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _selectedImageFile != null
                              ? Image.file(_selectedImageFile!,
                                  fit: BoxFit.cover)
                              : _imageUrl.text.startsWith('http')
                                  ? CachedNetworkImage(
                                      imageUrl: _imageUrl.text,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                          const Center(
                                              child:
                                                  CircularProgressIndicator()),
                                      errorWidget: (context, url, error) =>
                                          const Center(
                                              child: Icon(Icons.error)),
                                    )
                                  : const Center(child: Text('No image')),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: FloatingActionButton.small(
                              onPressed: _pickAndUploadImage,
                              child: const Icon(Icons.edit),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.image_not_supported,
                                size: 48, color: Colors.grey),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _pickAndUploadImage,
                              child: const Text('Pick Image'),
                            ),
                          ],
                        ),
                      ),
                    ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const CircularProgressIndicator()
                        : const Text('Save'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

