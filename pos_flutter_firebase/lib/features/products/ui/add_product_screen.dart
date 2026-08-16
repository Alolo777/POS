import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/category.dart' as app_models;
import '../../../shared/models/product.dart';
import '../../../shared/models/store.dart';
import '../../../shared/providers/app_session_notifier.dart';
import '../../../features/inventory/domain/stock_repository.dart';
import '../../../features/pos/domain/category_repository.dart';
import '../../../features/products/domain/product_repository.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key, required this.businessId, required this.storeId, this.product});

  final String businessId;
  final String storeId;
  final Product? product;

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  ProductRepository get _productService => context.read<ProductRepository>();
  CategoryRepository get _categoryService => context.read<CategoryRepository>();
  final _imagePicker = ImagePicker();

  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _storePriceController = TextEditingController();
  final _costController = TextEditingController();
  final _refController = TextEditingController();
  final _stockController = TextEditingController();
  final _lowStockController = TextEditingController();

  String? _selectedCategoryId;
  String? _selectedCategoryName;
  String _sellBy = 'unit';
  bool _trackStock = false;
  String _presentationType = 'shape';
  String _presentationShape = 'square';
  int _presentationColor = 0xFF9E9E9E;
  XFile? _imageFile;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditMode => widget.product != null;

  static const _colors = [
    0xFF9E9E9E,
    0xFFE53935,
    0xFFFDD835,
    0xFF1E88E5,
    0xFF8E24AA,
    0xFF43A047,
    0xFFFF8F00,
  ];

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    if (product == null) {
      _loadSuggestedRef();
      return;
    }

    _nameController.text = product.name;
    _priceController.text = _formatNumber(product.price);
    _costController.text = product.cost == 0 ? '' : _formatNumber(product.cost);
    _refController.text = product.ref;
    _stockController.text = product.trackStock ? _formatNumber(product.stockQuantity) : '';
    _lowStockController.text = product.trackStock ? _formatNumber(product.lowStockAlertQuantity) : '';
    _selectedCategoryId = product.categoryId;
    _selectedCategoryName = product.categoryName;
    _sellBy = product.sellBy;
    _trackStock = product.trackStock;
    _presentationType = product.presentationType;
    _presentationShape = product.presentationShape;
    _presentationColor = product.presentationColor;
  }

  Future<void> _loadSuggestedRef() async {
    try {
      final suggestedRef = await context.read<ProductRepository>().getSuggestedRef(businessId: widget.businessId);
      if (!mounted || _refController.text.isNotEmpty) return;
      _refController.text = suggestedRef;
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _storePriceController.dispose();
    _costController.dispose();
    _refController.dispose();
    _stockController.dispose();
    _lowStockController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim().replaceAll(',', '.'));
    final storePriceText = _storePriceController.text.trim().replaceAll(',', '.');
    final storePrice = storePriceText.isEmpty ? null : double.tryParse(storePriceText);
    final cost = double.tryParse(_costController.text.trim().replaceAll(',', '.')) ?? 0;
    final ref = _refController.text.trim();
    final stockQuantity = double.tryParse(_stockController.text.trim().replaceAll(',', '.')) ?? 0;
    final lowStockQuantity = double.tryParse(_lowStockController.text.trim().replaceAll(',', '.')) ?? 0;

    if (name.isEmpty) {
      setState(() => _errorMessage = 'El nombre es obligatorio');
      return;
    }
    if (price == null || price < 0) {
      setState(() => _errorMessage = 'El precio es obligatorio');
      return;
    }
    if (storePrice != null && storePrice < 0) {
      setState(() => _errorMessage = 'El precio por sucursal no puede ser negativo');
      return;
    }
    if (storePrice == null && storePriceText.isNotEmpty) {
      setState(() => _errorMessage = 'El precio por sucursal no es valido');
      return;
    }
    if (cost < 0) {
      setState(() => _errorMessage = 'El coste no puede ser negativo');
      return;
    }
    if (ref.isEmpty) {
      setState(() => _errorMessage = 'El REF es obligatorio y no debe repetirse');
      return;
    }
    if (_trackStock && stockQuantity < 0) {
      setState(() => _errorMessage = 'La cantidad de inventario no es valida');
      return;
    }
    if (_trackStock && _sellBy == 'unit' && stockQuantity % 1 != 0) {
      setState(() => _errorMessage = 'Los productos por unidad deben usar cantidades enteras');
      return;
    }
    if (_presentationType == 'image' && _imageFile == null && widget.product?.localImagePath == null) {
      setState(() => _errorMessage = 'Selecciona o toma una imagen');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final product = widget.product;
      if (product == null) {
        await _productService.addProduct(
          businessId: widget.businessId,
          storeId: widget.storeId,
          name: name,
          categoryId: _selectedCategoryId,
          categoryName: _selectedCategoryName,
          sellBy: _sellBy,
          price: price,
          cost: cost,
          ref: ref,
          trackStock: _trackStock,
          stockQuantity: stockQuantity,
          lowStockAlertQuantity: lowStockQuantity,
          presentationType: _presentationType,
          presentationShape: _presentationShape,
          presentationColor: _presentationColor,
          storePrice: storePrice,
          imageFile: _presentationType == 'image' ? _imageFile : null,
        );
      } else {
        await _productService.updateProduct(
          businessId: widget.businessId,
          storeId: widget.storeId,
          product: product,
          name: name,
          categoryId: _selectedCategoryId,
          categoryName: _selectedCategoryName,
          sellBy: _sellBy,
          price: price,
          cost: cost,
          ref: ref,
          trackStock: _trackStock,
          stockQuantity: stockQuantity,
          lowStockAlertQuantity: lowStockQuantity,
          presentationType: _presentationType,
          presentationShape: _presentationShape,
          presentationColor: _presentationColor,
          storePrice: storePrice,
          imageFile: _presentationType == 'image' ? _imageFile : null,
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _showStorePricesDialog() async {
    final product = widget.product;
    if (product == null) return;
    final session = context.read<AppSessionNotifier>();
    final stores = session.session?.stores ?? const <Store>[];
    if (stores.isEmpty) return;

    final controllers = <String, TextEditingController>{
      for (final store in stores) store.id: TextEditingController(),
    };

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Precios por sucursal · ${product.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Precio general: \$${_formatNumber(product.price)}.\nDeja el campo vacio para usar el precio general en esa sucursal.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (final store in stores) ...[
                TextField(
                  controller: controllers[store.id],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: store.name,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    try {
      if (result != true || !mounted) return;
      final stockRepo = context.read<StockRepository>();
      for (final store in stores) {
        final text = controllers[store.id]!.text.trim().replaceAll(',', '.');
        if (text.isEmpty) continue;
        final price = double.tryParse(text);
        if (price == null || price < 0) continue;
        await stockRepo.setStorePrice(
          businessId: widget.businessId,
          storeId: store.id,
          productId: product.id,
          price: price,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Precios por sucursal guardados')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    }
  }

  Future<void> _addCategory() async {
    final category = await showDialog<app_models.Category>(
      context: context,
      builder: (context) => _AddCategoryDialog(
        businessId: widget.businessId,
        colors: _colors,
        categoryService: _categoryService,
      ),
    );

    if (category != null) {
      setState(() {
        _selectedCategoryId = category.id;
        _selectedCategoryName = category.name;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final image = await _imagePicker.pickImage(source: source, imageQuality: 80, maxWidth: 1200);
    if (image != null) {
      setState(() => _imageFile = image);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Editar producto' : 'Nuevo producto'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving ? const Text('Guardando...') : const Text('Guardar'),
          ),
        ],
      ),
      body: StreamBuilder<List<app_models.Category>>(
        stream: _categoryService.watchCategories(businessId: widget.businessId),
        builder: (context, snapshot) {
          final categories = snapshot.data ?? const <app_models.Category>[];
          final selectedCategoryIsMissing = _selectedCategoryId != null &&
              !categories.any((category) => category.id == _selectedCategoryId);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_errorMessage != null) ...[
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: _selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Categoria opcional',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Sin categoria'),
                        ),
                        ...categories.map(
                          (category) => DropdownMenuItem<String?>(
                            value: category.id,
                            child: Text(category.name),
                          ),
                        ),
                        if (selectedCategoryIsMissing)
                          DropdownMenuItem<String?>(
                            value: _selectedCategoryId,
                            child: Text(_selectedCategoryName ?? 'Categoria seleccionada'),
                          ),
                      ],
                      onChanged: (value) {
                        app_models.Category? selected;
                        for (final category in categories) {
                          if (category.id == value) {
                            selected = category;
                            break;
                          }
                        }
                        setState(() {
                          _selectedCategoryId = selected?.id;
                          _selectedCategoryName = selected?.name;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Agregar categoria',
                    onPressed: _addCategory,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Se vende por', style: Theme.of(context).textTheme.titleMedium),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'unit', label: Text('Unidad')),
                  ButtonSegment(value: 'weight', label: Text('Peso/volumen')),
                ],
                selected: {_sellBy},
                onSelectionChanged: (value) => setState(() => _sellBy = value.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Precio *',
                  helperText: 'Precio general del producto',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _storePriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Precio por sucursal (opcional)',
                  helperText: 'Dejalo vacio para usar el precio general en esta sucursal',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_isEditMode) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _showStorePricesDialog,
                    icon: const Icon(Icons.store),
                    label: const Text('Precios por sucursal'),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _costController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Coste', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _refController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'REF *',
                  helperText: 'Identificador unico asignado al articulo',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Inventario'),
                subtitle: const Text('Activa si quieres controlar existencias'),
                value: _trackStock,
                onChanged: (value) => setState(() => _trackStock = value),
              ),
              if (_trackStock) ...[
                TextField(
                  controller: _stockController,
                  keyboardType: TextInputType.numberWithOptions(decimal: _sellBy == 'weight'),
                  decoration: const InputDecoration(
                    labelText: 'Inventario inicial',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _lowStockController,
                  keyboardType: TextInputType.numberWithOptions(decimal: _sellBy == 'weight'),
                  decoration: const InputDecoration(
                    labelText: 'Inventario bajo',
                    helperText: 'Unidad: piezas enteras. Peso/volumen: puede usar decimales.',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text('Presentacion en el TPV *', style: Theme.of(context).textTheme.titleMedium),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'shape', label: Text('Color y forma')),
                  ButtonSegment(value: 'image', label: Text('Imagen')),
                ],
                selected: {_presentationType},
                onSelectionChanged: (value) => setState(() => _presentationType = value.first),
              ),
              const SizedBox(height: 12),
              if (_presentationType == 'shape') _buildShapeOptions() else _buildImageOptions(),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: const Icon(Icons.save),
                label: Text(_isEditMode ? 'Guardar cambios' : 'Guardar producto'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildShapeOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: const [
            ('square', Icons.crop_square, 'Cuadrado'),
            ('circle', Icons.circle_outlined, 'Circular'),
            ('hexagon', Icons.hexagon_outlined, 'Hexagonal'),
          ].map((shape) {
            return ChoiceChip(
              selected: _presentationShape == shape.$1,
              avatar: Icon(shape.$2),
              label: Text(shape.$3),
              onSelected: (_) => setState(() => _presentationShape = shape.$1),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _colors
              .map(
                (value) => ChoiceChip(
                  selected: _presentationColor == value,
                  label: Text(_colorName(value)),
                  avatar: CircleAvatar(backgroundColor: Color(value)),
                  onSelected: (_) => setState(() => _presentationColor = value),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildImageOptions() {
    final localImagePath = widget.product?.localImagePath;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_imageFile != null)
          Text('Imagen seleccionada: ${_imageFile!.name}'),
        if (_imageFile == null && localImagePath != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(localImagePath),
              height: 120,
              width: 120,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Text('No se pudo cargar la imagen guardada'),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Puedes conservar esta imagen o reemplazarla.'),
        ],
        if (_imageFile == null && localImagePath == null)
          const Text('Selecciona una imagen o toma una foto para mostrarla en el TPV.'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('Elegir foto'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.photo_camera),
              label: const Text('Tomar foto'),
            ),
          ],
        ),
      ],
    );
  }

  String _colorName(int value) {
    switch (value) {
      case 0xFFE53935:
        return 'Rojo';
      case 0xFFFDD835:
        return 'Amarillo';
      case 0xFF1E88E5:
        return 'Azul';
      case 0xFF8E24AA:
        return 'Morado';
      case 0xFF43A047:
        return 'Verde';
      case 0xFFFF8F00:
        return 'Naranja';
      default:
        return 'Gris';
    }
  }

  String _formatNumber(double value) {
    if (value % 1 == 0) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(2);
  }
}

class _AddCategoryDialog extends StatefulWidget {
  const _AddCategoryDialog({
    required this.businessId,
    required this.colors,
    required this.categoryService,
  });

  final String businessId;
  final List<int> colors;
  final CategoryRepository categoryService;

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  final _nameController = TextEditingController();
  var _color = 0xFF607D8B;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _isSaving) return;

    setState(() => _isSaving = true);

    final id = await widget.categoryService.addCategory(
      businessId: widget.businessId,
      name: name,
      color: _color,
    );

    if (!mounted) return;
    Navigator.pop(
      context,
      app_models.Category(id: id, name: name, color: _color, active: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva categoria'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: widget.colors
                .map(
                  (value) => ChoiceChip(
                    selected: _color == value,
                    label: const SizedBox(width: 18, height: 18),
                    avatar: CircleAvatar(backgroundColor: Color(value)),
                    onSelected: (_) => setState(() => _color = value),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving ? const Text('Guardando...') : const Text('Guardar'),
        ),
      ],
    );
  }
}
