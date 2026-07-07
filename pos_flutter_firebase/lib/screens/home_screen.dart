import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/employee.dart';
import '../models/store.dart';
import '../services/app_context_service.dart';
import 'back_office_screen.dart';
import 'business_setup_screen.dart';
import 'employee_pin_screen.dart';
import 'pos_screen.dart';
import 'products_screen.dart';
import 'receipts_screen.dart';
import 'settings_screen.dart';
import 'shift_screen.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _appContextService = AppContextService();

  Store? _selectedStore;
  Employee? _activeEmployee;
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppSession?>(
      future: _appContextService.loadSession(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data;
        if (session == null || session.stores.isEmpty) {
          return BusinessSetupScreen(
            onCreated: () => setState(() {}),
          );
        }

        if (_selectedStore == null && session.stores.length > 1) {
          return _StoreSelectionScreen(
            businessName: session.business.name,
            stores: session.stores,
            onSelected: (store) => setState(() => _selectedStore = store),
            onSignOut: _authService.signOut,
          );
        }

        final selectedStore = _resolveSelectedStore(session.stores);
        final employeesForStore = _employeesForSelectedStore(session, selectedStore);
        if (_activeEmployee == null || !_activeEmployeeIsValid(employeesForStore)) {
          return EmployeePinScreen(
            store: selectedStore,
            employees: employeesForStore,
            onUnlocked: (employee) => setState(() => _activeEmployee = employee),
            onChangeStore: () => setState(() {
              _selectedStore = null;
              _activeEmployee = null;
            }),
            onSignOut: _authService.signOut,
          );
        }

        return _buildMainScaffold(session, selectedStore, _activeEmployee!);
      },
    );
  }

  Widget _buildMainScaffold(AppSession session, Store selectedStore, Employee activeEmployee) {
    final isWide = MediaQuery.sizeOf(context).width >= 800;
    final page = _buildSelectedPage(session, selectedStore);

    return Scaffold(
      appBar: AppBar(
        title: Text(session.business.name),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text(
                '${selectedStore.name} · ${activeEmployee.name}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Cambiar empleado',
            icon: const Icon(Icons.badge),
            onPressed: () => setState(() => _activeEmployee = null),
          ),
          IconButton(
            tooltip: 'Cerrar sesion',
            icon: const Icon(Icons.logout),
            onPressed: _authService.signOut,
          ),
        ],
      ),
      drawer: isWide ? null : Drawer(child: _buildNavigationList()),
      body: isWide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) => setState(() => _selectedIndex = index),
                  labelType: NavigationRailLabelType.all,
                  destinations: _navItems(activeEmployee)
                      .map((item) => NavigationRailDestination(icon: Icon(item.icon), label: Text(item.label)))
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: page),
              ],
            )
          : page,
    );
  }

  Widget _buildNavigationList() {
    final activeEmployee = _activeEmployee;
    final items = activeEmployee == null ? const <_NavItem>[] : _navItems(activeEmployee);

    return SafeArea(
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            selected: _selectedIndex == index,
            leading: Icon(item.icon),
            title: Text(item.label),
            onTap: () {
              Navigator.pop(context);
              setState(() => _selectedIndex = index);
            },
          );
        },
      ),
    );
  }

  Widget _buildSelectedPage(AppSession session, Store selectedStore) {
    final activeEmployee = _activeEmployee ?? session.employee;
    final items = _navItems(activeEmployee);
    if (_selectedIndex >= items.length) {
      _selectedIndex = 0;
    }

    switch (items[_selectedIndex].key) {
      case 'pos':
        return PosScreen(
          businessId: session.business.id,
          store: selectedStore,
          employee: activeEmployee,
        );
      case 'receipts':
        return ReceiptsScreen(
          businessId: session.business.id,
          businessName: session.business.name,
          store: selectedStore,
          employee: activeEmployee,
        );
      case 'products':
        return ProductsScreen(businessId: session.business.id, storeId: selectedStore.id);
      case 'shift':
        return ShiftScreen(
          businessId: session.business.id,
          store: selectedStore,
          employee: activeEmployee,
        );
      case 'settings':
        return SettingsScreen(businessId: session.business.id);
      default:
        return BackOfficeScreen(
          businessId: session.business.id,
          stores: session.stores,
          currentEmployee: activeEmployee,
        );
    }
  }

  Store _resolveSelectedStore(List<Store> stores) {
    final current = _selectedStore;
    if (current != null) {
      for (final store in stores) {
        if (store.id == current.id) {
          _selectedStore = store;
          return store;
        }
      }
    }

    _selectedStore = stores.first;
    return stores.first;
  }

  List<Employee> _employeesForSelectedStore(AppSession session, Store selectedStore) {
    return session.employees
        .where((employee) => employee.active && (employee.isOwner || employee.storeIds.contains(selectedStore.id)))
        .toList();
  }

  bool _activeEmployeeIsValid(List<Employee> employees) {
    final activeEmployee = _activeEmployee;
    if (activeEmployee == null) return false;
    return employees.any((employee) => employee.id == activeEmployee.id && employee.active);
  }

  List<_NavItem> _navItems(Employee employee) {
    return [
      const _NavItem('pos', Icons.point_of_sale, 'Venta'),
      if (employee.isManager || employee.isAdmin || employee.hasPermission('receipts'))
        const _NavItem('receipts', Icons.receipt_long, 'Recibos'),
      if (employee.isManager || employee.isAdmin || employee.hasPermission('products'))
        const _NavItem('products', Icons.inventory_2, 'Productos'),
      if (employee.isManager || employee.isAdmin || employee.hasPermission('shift'))
        const _NavItem('shift', Icons.account_balance_wallet, 'Turno'),
      if (employee.isAdmin) const _NavItem('settings', Icons.settings, 'Config'),
      if (employee.isAdmin) const _NavItem('backOffice', Icons.admin_panel_settings, 'Back Office'),
    ];
  }
}

class _NavItem {
  const _NavItem(this.key, this.icon, this.label);

  final String key;
  final IconData icon;
  final String label;
}

class _StoreSelectionScreen extends StatelessWidget {
  const _StoreSelectionScreen({
    required this.businessName,
    required this.stores,
    required this.onSelected,
    required this.onSignOut,
  });

  final String businessName;
  final List<Store> stores;
  final ValueChanged<Store> onSelected;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(businessName),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesion',
            icon: const Icon(Icons.logout),
            onPressed: onSignOut,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.store, size: 64, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Selecciona la sucursal que vas a abrir',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                ...stores.map(
                  (store) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.storefront),
                      title: Text(store.name),
                      subtitle: Text([
                        if (store.address.isNotEmpty) store.address,
                        if (store.phone.isNotEmpty) store.phone,
                      ].join(' · ')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => onSelected(store),
                    ),
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
