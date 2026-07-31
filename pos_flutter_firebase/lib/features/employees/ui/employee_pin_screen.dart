import 'package:flutter/material.dart';

import '../../../shared/models/employee.dart';
import '../../../shared/models/store.dart';

class EmployeePinScreen extends StatefulWidget {
  const EmployeePinScreen({
    super.key,
    required this.store,
    required this.stores,
    required this.employees,
    required this.onUnlocked,
    required this.onSelectStore,
    required this.onSignOut,
  });

  final Store store;
  final List<Store> stores;
  final List<Employee> employees;
  final ValueChanged<Employee> onUnlocked;
  final ValueChanged<Store> onSelectStore;
  final VoidCallback onSignOut;

  @override
  State<EmployeePinScreen> createState() => _EmployeePinScreenState();
}

class _EmployeePinScreenState extends State<EmployeePinScreen> {
  Employee? _selectedEmployee;
  String _pin = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.employees.length == 1) {
      _selectedEmployee = widget.employees.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.employees.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: _storeDropdown(),
          actions: [
            IconButton(icon: const Icon(Icons.logout), onPressed: widget.onSignOut),
          ],
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No hay empleados activos asignados a esta sucursal.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: _storeDropdown(),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: widget.onSignOut),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.pin, size: 64, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text('Acceso de empleado', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                DropdownButtonFormField<Employee>(
                  initialValue: _selectedEmployee,
                  decoration: const InputDecoration(labelText: 'Empleado', border: OutlineInputBorder()),
                  items: widget.employees
                      .map((employee) => DropdownMenuItem(value: employee, child: Text(employee.name)))
                      .toList(),
                  onChanged: (employee) => setState(() {
                    _selectedEmployee = employee;
                    _pin = '';
                    _errorMessage = null;
                  }),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _pin.isEmpty ? 'Ingresa PIN' : '•' * _pin.length,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                ],
                const SizedBox(height: 16),
                _PinPad(onDigit: _addDigit, onBackspace: _backspace, onSubmit: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addDigit(String digit) {
    if (_pin.length >= 8) return;
    setState(() {
      _pin += digit;
      _errorMessage = null;
    });
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _submit() {
    final employee = _selectedEmployee;
    if (employee == null) {
      setState(() => _errorMessage = 'Selecciona un empleado');
      return;
    }
    if (!employee.verifyPin(_pin)) {
      setState(() {
        _pin = '';
        _errorMessage = 'PIN incorrecto';
      });
      return;
    }

    widget.onUnlocked(employee);
  }

  Widget _storeDropdown() {
    if (widget.stores.length <= 1) {
      return Text(widget.store.name);
    }
    return DropdownButton<Store>(
      value: widget.store,
      underline: const SizedBox.shrink(),
      isDense: true,
      items: widget.stores
          .map((store) => DropdownMenuItem(value: store, child: Text(store.name, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: (store) {
        if (store != null && store.id != widget.store.id) {
          widget.onSelectStore(store);
        }
      },
    );
  }
}

class _PinPad extends StatelessWidget {
  const _PinPad({required this.onDigit, required this.onBackspace, required this.onSubmit});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final buttons = ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'back', '0', 'ok'];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.8,
      ),
      itemCount: buttons.length,
      itemBuilder: (context, index) {
        final value = buttons[index];
        if (value == 'back') {
          return FilledButton.tonal(onPressed: onBackspace, child: const Icon(Icons.backspace));
        }
        if (value == 'ok') {
          return FilledButton(onPressed: onSubmit, child: const Icon(Icons.check));
        }
        return FilledButton.tonal(onPressed: () => onDigit(value), child: Text(value));
      },
    );
  }
}
