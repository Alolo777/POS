import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class BusinessSetupScreen extends StatefulWidget {
  const BusinessSetupScreen({super.key, required this.onCreated});

  final VoidCallback onCreated;

  @override
  State<BusinessSetupScreen> createState() => _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends State<BusinessSetupScreen> {
  final _authService = AuthService();
  final _businessNameController = TextEditingController();

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _businessNameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final businessName = _businessNameController.text.trim();
    if (businessName.isEmpty) {
      setState(() => _errorMessage = 'Ingresa el nombre de tu empresa');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await _authService.createOwnerWorkspace(businessName: businessName);
      if (!mounted) return;
      widget.onCreated();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Configurar empresa')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                const Icon(Icons.storefront, size: 64, color: Colors.indigo),
                const SizedBox(height: 16),
                Text(
                  'Antes de vender, crea tu empresa',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _businessNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la empresa',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Crear empresa'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
