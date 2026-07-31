import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/business.dart';
import '../../../shared/models/store.dart';
import '../../../features/business/domain/business_repository.dart';
import '../../../features/poultry/ui/poultry_config_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.businessId});

  final String businessId;

  @override
  Widget build(BuildContext context) {
    final businessService = context.read<BusinessRepository>();

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Configuraciones')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStoreDialog(context, businessService),
        icon: const Icon(Icons.add_business),
        label: const Text('Sucursal'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StreamBuilder<Business>(
            stream: businessService.watchBusiness(businessId: businessId),
            builder: (context, snapshot) {
              final business = snapshot.data;
              if (business == null) {
                return const Card(child: Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()));
              }

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.storefront),
                  title: Text(business.name),
                  subtitle: Text('${business.currency} · ${business.timezone}'),
                  trailing: const Icon(Icons.edit),
                  onTap: () => _showBusinessDialog(context, businessService, business),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text('Sucursales', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          StreamBuilder<List<Store>>(
            stream: businessService.watchStores(businessId: businessId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final stores = snapshot.data ?? const <Store>[];
              if (stores.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Todavia no hay sucursales.'),
                  ),
                );
              }

              return Column(
                children: stores
                    .map(
                      (store) => Card(
                        child: ListTile(
                          leading: Icon(store.active ? Icons.store : Icons.store_outlined),
                          title: Text(store.name),
                          subtitle: Text([
                            if (store.address.isNotEmpty) store.address,
                            if (store.phone.isNotEmpty) store.phone,
                            store.active ? 'Activa' : 'Inactiva',
                          ].join(' · ')),
                          trailing: const Icon(Icons.edit),
                          onTap: () => _showStoreDialog(context, businessService, store: store),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.set_meal),
              title: const Text('Pollería'),
              subtitle: const Text('Configurar cortes y porcentajes'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (_) => PoultryConfigScreen(businessId: businessId),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showBusinessDialog(
    BuildContext context,
    BusinessRepository businessService,
    Business business,
  ) async {
    final result = await showDialog<_BusinessDialogResult>(
      context: context,
      builder: (context) => _BusinessDialog(business: business),
    );
    if (result == null || !context.mounted) return;

    try {
      await businessService.updateBusiness(
        businessId: businessId,
        name: result.name,
        currency: result.currency,
        timezone: result.timezone,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _showStoreDialog(
    BuildContext context,
    BusinessRepository businessService, {
    Store? store,
  }) async {
    final result = await showDialog<_StoreDialogResult>(
      context: context,
      builder: (context) => _StoreDialog(store: store),
    );
    if (result == null || !context.mounted) return;

    try {
      if (store == null) {
        await businessService.addStore(
          businessId: businessId,
          name: result.name,
          address: result.address,
          phone: result.phone,
        );
      } else {
        await businessService.updateStore(
          businessId: businessId,
          store: store,
          name: result.name,
          address: result.address,
          phone: result.phone,
          active: result.active,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

class _BusinessDialogResult {
  const _BusinessDialogResult({required this.name, required this.currency, required this.timezone});

  final String name;
  final String currency;
  final String timezone;
}

class _BusinessDialog extends StatefulWidget {
  const _BusinessDialog({required this.business});

  final Business business;

  @override
  State<_BusinessDialog> createState() => _BusinessDialogState();
}

class _BusinessDialogState extends State<_BusinessDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _currencyController;
  late final TextEditingController _timezoneController;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.business.name);
    _currencyController = TextEditingController(text: widget.business.currency);
    _timezoneController = TextEditingController(text: widget.business.timezone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currencyController.dispose();
    _timezoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar negocio'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _currencyController, decoration: const InputDecoration(labelText: 'Moneda', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _timezoneController, decoration: const InputDecoration(labelText: 'Zona horaria', border: OutlineInputBorder())),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }

  void _submit() {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'El nombre es obligatorio');
      return;
    }
    Navigator.pop(
      context,
      _BusinessDialogResult(
        name: _nameController.text,
        currency: _currencyController.text,
        timezone: _timezoneController.text,
      ),
    );
  }
}

class _StoreDialogResult {
  const _StoreDialogResult({required this.name, required this.address, required this.phone, required this.active});

  final String name;
  final String address;
  final String phone;
  final bool active;
}

class _StoreDialog extends StatefulWidget {
  const _StoreDialog({this.store});

  final Store? store;

  @override
  State<_StoreDialog> createState() => _StoreDialogState();
}

class _StoreDialogState extends State<_StoreDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late bool _active;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final store = widget.store;
    _nameController = TextEditingController(text: store?.name ?? '');
    _addressController = TextEditingController(text: store?.address ?? '');
    _phoneController = TextEditingController(text: store?.phone ?? '');
    _active = store?.active ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.store == null ? 'Nueva sucursal' : 'Editar sucursal'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _addressController, decoration: const InputDecoration(labelText: 'Direccion', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Telefono', border: OutlineInputBorder())),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Activa'),
              value: _active,
              onChanged: (value) => setState(() => _active = value),
            ),
            if (_errorMessage != null) Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }

  void _submit() {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'El nombre es obligatorio');
      return;
    }
    Navigator.pop(
      context,
      _StoreDialogResult(
        name: _nameController.text,
        address: _addressController.text,
        phone: _phoneController.text,
        active: _active,
      ),
    );
  }
}
