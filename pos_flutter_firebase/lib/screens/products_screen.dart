import 'package:flutter/material.dart';

import '../models/category.dart' as app_models;
import '../models/discount.dart';
import '../models/modifier.dart';
import '../models/product.dart';
import '../models/product_stock.dart';
import '../services/category_service.dart';
import '../services/discount_service.dart';
import '../services/modifier_service.dart';
import '../services/product_service.dart';
import '../services/stock_service.dart';
import '../widgets/product_presentation.dart';
import 'add_product_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key, required this.businessId, required this.storeId});

  final String businessId;
  final String storeId;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Items'),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Productos'),
              Tab(text: 'Categorias'),
              Tab(text: 'Modificadores'),
              Tab(text: 'Descuentos'),
            ],
          ),
        ),
        floatingActionButton: _buildFab(),
        body: TabBarView(
          controller: _tabController,
          children: [
            _ProductsTab(businessId: widget.businessId, storeId: widget.storeId),
            _CategoriesTab(businessId: widget.businessId),
            _ModifiersTab(businessId: widget.businessId),
            _DiscountsTab(businessId: widget.businessId),
          ],
        ),
    );
  }

  Widget? _buildFab() {
    if (_tabController.index == 0) {
      return FloatingActionButton(
        tooltip: 'Agregar producto',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddProductScreen(businessId: widget.businessId, storeId: widget.storeId),
            ),
          );
        },
        child: const Icon(Icons.add),
      );
    }

    if (_tabController.index == 1) {
      return FloatingActionButton(
        tooltip: 'Agregar categoria',
        onPressed: () => _showCategoryDialog(context, widget.businessId),
        child: const Icon(Icons.add),
      );
    }

    if (_tabController.index == 2) {
      return FloatingActionButton(
        tooltip: 'Agregar modificador',
        onPressed: () => _showModifierDialog(context, widget.businessId),
        child: const Icon(Icons.add),
      );
    }

    if (_tabController.index == 3) {
      return FloatingActionButton(
        tooltip: 'Agregar descuento',
        onPressed: () => _showDiscountDialog(context, widget.businessId),
        child: const Icon(Icons.add),
      );
    }

    return null;
  }
}

class _ProductsTab extends StatelessWidget {
  const _ProductsTab({required this.businessId, required this.storeId});

  final String businessId;
  final String storeId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Product>>(
      stream: ProductService().watchProducts(businessId: businessId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        return StreamBuilder<Map<String, ProductStock>>(
          stream: StockService().watchStockByStore(businessId: businessId, storeId: storeId),
          builder: (context, stockSnapshot) {
            final stocks = stockSnapshot.data ?? const <String, ProductStock>{};
            final products = (snapshot.data ?? const <Product>[]).map((product) {
              final stock = stocks[product.id];
              return Product(
                id: product.id,
                name: product.name,
                categoryId: product.categoryId,
                categoryName: product.categoryName,
                sellBy: product.sellBy,
                price: product.price,
                cost: product.cost,
                ref: product.ref,
                trackStock: product.trackStock,
                stock: stock?.stockQuantity.round() ?? 0,
                stockQuantity: stock?.stockQuantity ?? 0,
                lowStockAlert: stock?.lowStockAlertQuantity.round() ?? product.lowStockAlertQuantity.round(),
                lowStockAlertQuantity: stock?.lowStockAlertQuantity ?? product.lowStockAlertQuantity,
                presentationType: product.presentationType,
                presentationShape: product.presentationShape,
                presentationColor: product.presentationColor,
                imageUrl: product.imageUrl,
                localImagePath: product.localImagePath,
                active: product.active,
              );
            }).toList();
            if (products.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 56, color: Colors.indigo),
                  const SizedBox(height: 16),
                  Text(
                    'Aqui puedes anadir tus productos',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Toca el boton + para crear tu primer producto y despues aparecera en el punto de venta.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

            return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: products.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final product = products[index];
            return ListTile(
              leading: ProductPresentation(product: product),
              title: Text(product.name),
              subtitle: Text(_productSubtitle(product)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('\$${product.price.toStringAsFixed(2)}'),
                  PopupMenuButton<String>(
                    tooltip: 'Opciones de producto',
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddProductScreen(
                              businessId: businessId,
                              storeId: storeId,
                              product: product,
                            ),
                          ),
                        );
                        return;
                      }

                      if (value == 'delete') {
                        await _confirmDeactivateProduct(context, businessId, product);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Editar')),
                      PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                    ],
                  ),
                ],
              ),
            );
          },
            );
          },
        );
      },
    );
  }

  String _productSubtitle(Product product) {
    final parts = <String>[
      'REF: ${product.ref}',
      product.sellBy == 'weight' ? 'Peso' : 'Unidad',
    ];

    if (product.categoryName != null && product.categoryName!.isNotEmpty) {
      parts.add(product.categoryName!);
    }
    if (product.trackStock) {
      parts.add('Stock: ${_formatStock(product)}');
    }

    return parts.join(' · ');
  }

  String _formatStock(Product product) {
    if (product.sellBy == 'weight') {
      return '${product.stockQuantity.toStringAsFixed(2)} peso/vol.';
    }

    return '${product.stockQuantity.round()} pzas';
  }
}

Future<void> _confirmDeactivateProduct(
  BuildContext context,
  String businessId,
  Product product,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Eliminar producto'),
      content: Text('Se ocultara "${product.name}" del catalogo y del TPV. Las ventas anteriores no se borran.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await ProductService().deactivateProduct(businessId: businessId, product: product);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Producto eliminado')));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
  }
}

class _CategoriesTab extends StatelessWidget {
  const _CategoriesTab({required this.businessId});

  final String businessId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<app_models.Category>>(
      stream: CategoryService().watchCategories(businessId: businessId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final categories = snapshot.data ?? const <app_models.Category>[];
        if (categories.isEmpty) {
          return const Center(
            child: Text('Todavia no hay categorias. Puedes crearlas al agregar un producto.'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: categories.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final category = categories[index];
            return ListTile(
              leading: CircleAvatar(backgroundColor: Color(category.color)),
              title: Text(category.name),
              trailing: PopupMenuButton<String>(
                tooltip: 'Opciones de categoria',
                onSelected: (value) async {
                  if (value == 'edit') {
                    await _showCategoryDialog(context, businessId, category: category);
                    return;
                  }

                  if (value == 'delete') {
                    await _confirmDeactivateCategory(context, businessId, category);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

const _categoryColors = [
  0xFF607D8B,
  0xFFE53935,
  0xFFFDD835,
  0xFF1E88E5,
  0xFF8E24AA,
  0xFF43A047,
  0xFFFF8F00,
];

Future<void> _showCategoryDialog(
  BuildContext context,
  String businessId, {
  app_models.Category? category,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) => _CategoryDialog(
      businessId: businessId,
      category: category,
    ),
  );
}

Future<void> _confirmDeactivateCategory(
  BuildContext context,
  String businessId,
  app_models.Category category,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Eliminar categoria'),
      content: Text(
        'Se ocultara "${category.name}" y se quitara de los productos que la usan. Los productos no se eliminan.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await CategoryService().deactivateCategory(businessId: businessId, categoryId: category.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Categoria eliminada')));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
  }
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({required this.businessId, this.category});

  final String businessId;
  final app_models.Category? category;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _categoryService = CategoryService();
  final _nameController = TextEditingController();
  late int _color;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    _nameController.text = category?.name ?? '';
    _color = category?.color ?? _categoryColors.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'El nombre es obligatorio');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final category = widget.category;
      if (category == null) {
        await _categoryService.addCategory(
          businessId: widget.businessId,
          name: name,
          color: _color,
        );
      } else {
        await _categoryService.updateCategory(
          businessId: widget.businessId,
          categoryId: category.id,
          name: name,
          color: _color,
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category == null ? 'Nueva categoria' : 'Editar categoria'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _isSaving ? null : _save(),
              decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categoryColors
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
      ),
      actions: [
        TextButton(onPressed: _isSaving ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving ? const Text('Guardando...') : const Text('Guardar'),
        ),
      ],
    );
  }
}

class _ModifiersTab extends StatelessWidget {
  const _ModifiersTab({required this.businessId});

  final String businessId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Modifier>>(
      stream: ModifierService().watchModifiers(businessId: businessId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final modifiers = snapshot.data ?? const <Modifier>[];
        if (modifiers.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Todavia no hay modificadores. Agrega extras como queso, salsa, sin cebolla o topping adicional.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: modifiers.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final modifier = modifiers[index];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.tune)),
              title: Text(modifier.name),
              subtitle: Text(modifier.price == 0 ? 'Sin costo extra' : '+\$${modifier.price.toStringAsFixed(2)}'),
              trailing: PopupMenuButton<String>(
                tooltip: 'Opciones de modificador',
                onSelected: (value) async {
                  if (value == 'edit') {
                    await _showModifierDialog(context, businessId, modifier: modifier);
                    return;
                  }

                  if (value == 'delete') {
                    await _confirmDeactivateModifier(context, businessId, modifier);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

Future<void> _showModifierDialog(
  BuildContext context,
  String businessId, {
  Modifier? modifier,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) => _ModifierDialog(
      businessId: businessId,
      modifier: modifier,
    ),
  );
}

Future<void> _confirmDeactivateModifier(
  BuildContext context,
  String businessId,
  Modifier modifier,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Eliminar modificador'),
      content: Text('Se ocultara "${modifier.name}" para nuevas ventas. Las ventas anteriores no cambian.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await ModifierService().deactivateModifier(businessId: businessId, modifierId: modifier.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Modificador eliminado')));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
  }
}

class _ModifierDialog extends StatefulWidget {
  const _ModifierDialog({required this.businessId, this.modifier});

  final String businessId;
  final Modifier? modifier;

  @override
  State<_ModifierDialog> createState() => _ModifierDialogState();
}

class _ModifierDialogState extends State<_ModifierDialog> {
  final _modifierService = ModifierService();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final modifier = widget.modifier;
    _nameController.text = modifier?.name ?? '';
    _priceController.text = modifier == null || modifier.price == 0 ? '' : modifier.price.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim().replaceAll(',', '.')) ?? 0;
    if (name.isEmpty) {
      setState(() => _errorMessage = 'El nombre es obligatorio');
      return;
    }
    if (price < 0) {
      setState(() => _errorMessage = 'El precio no puede ser negativo');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final modifier = widget.modifier;
      if (modifier == null) {
        await _modifierService.addModifier(
          businessId: widget.businessId,
          name: name,
          price: price,
        );
      } else {
        await _modifierService.updateModifier(
          businessId: widget.businessId,
          modifierId: modifier.id,
          name: name,
          price: price,
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.modifier == null ? 'Nuevo modificador' : 'Editar modificador'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Ej. Extra queso',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _isSaving ? null : _save(),
              decoration: const InputDecoration(
                labelText: 'Precio extra',
                prefixText: '\$',
                hintText: '0.00',
                border: OutlineInputBorder(),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _isSaving ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving ? const Text('Guardando...') : const Text('Guardar'),
        ),
      ],
    );
  }
}

class _DiscountsTab extends StatelessWidget {
  const _DiscountsTab({required this.businessId});

  final String businessId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Discount>>(
      stream: DiscountService().watchDiscounts(businessId: businessId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final discounts = snapshot.data ?? const <Discount>[];
        if (discounts.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Todavia no hay descuentos. Crea descuentos por porcentaje o cantidad fija.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: discounts.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final discount = discounts[index];
            final subtitle = discount.isPercentage
                ? '${discount.value.toStringAsFixed(0)}% de descuento'
                : '\$${discount.value.toStringAsFixed(2)} de descuento';
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.discount)),
              title: Text(discount.name),
              subtitle: Text(subtitle),
              trailing: PopupMenuButton<String>(
                tooltip: 'Opciones de descuento',
                onSelected: (value) async {
                  if (value == 'edit') {
                    await _showDiscountDialog(context, businessId, discount: discount);
                    return;
                  }
                  if (value == 'delete') {
                    await _confirmDeactivateDiscount(context, businessId, discount);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

Future<void> _showDiscountDialog(
  BuildContext context,
  String businessId, {
  Discount? discount,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) => _DiscountDialog(
      businessId: businessId,
      discount: discount,
    ),
  );
}

Future<void> _confirmDeactivateDiscount(
  BuildContext context,
  String businessId,
  Discount discount,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Eliminar descuento'),
      content: Text('Se ocultara "${discount.name}" para nuevas ventas. Las ventas anteriores no cambian.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await DiscountService().deactivateDiscount(businessId: businessId, discountId: discount.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Descuento eliminado')));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
  }
}

class _DiscountDialog extends StatefulWidget {
  const _DiscountDialog({required this.businessId, this.discount});

  final String businessId;
  final Discount? discount;

  @override
  State<_DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<_DiscountDialog> {
  final _discountService = DiscountService();
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();
  String _type = 'fixed';
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final discount = widget.discount;
    _nameController.text = discount?.name ?? '';
    _valueController.text = discount == null ? '' : discount.value.toStringAsFixed(discount.isPercentage ? 0 : 2);
    _type = discount?.type ?? 'fixed';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final value = double.tryParse(_valueController.text.trim().replaceAll(',', '.'));
    if (name.isEmpty) {
      setState(() => _errorMessage = 'El nombre es obligatorio');
      return;
    }
    if (value == null || value <= 0) {
      setState(() => _errorMessage = 'El valor debe ser mayor a cero');
      return;
    }
    if (_type == 'percentage' && value > 100) {
      setState(() => _errorMessage = 'El porcentaje no puede superar 100');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final discount = widget.discount;
      if (discount == null) {
        await _discountService.addDiscount(
          businessId: widget.businessId,
          name: name,
          type: _type,
          value: value,
        );
      } else {
        await _discountService.updateDiscount(
          businessId: widget.businessId,
          discountId: discount.id,
          name: name,
          type: _type,
          value: value,
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.discount == null ? 'Nuevo descuento' : 'Editar descuento'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Ej. Descuento empleado',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'fixed', label: Text('Fijo')),
                ButtonSegment(value: 'percentage', label: Text('Porcentaje')),
              ],
              selected: {_type},
              onSelectionChanged: (selected) => setState(() => _type = selected.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _valueController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _isSaving ? null : _save(),
              decoration: InputDecoration(
                labelText: _type == 'percentage' ? 'Porcentaje' : 'Cantidad',
                prefixText: _type == 'percentage' ? null : '\$',
                suffixText: _type == 'percentage' ? '%' : null,
                hintText: _type == 'percentage' ? '10' : '5.00',
                border: const OutlineInputBorder(),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _isSaving ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving ? const Text('Guardando...') : const Text('Guardar'),
        ),
      ],
    );
  }
}
