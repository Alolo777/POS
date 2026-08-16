import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/app_session.dart';
import '../../../shared/models/employee.dart';
import '../../../shared/models/store.dart';
import '../../../shared/providers/app_session_notifier.dart';
import 'back_office_screen.dart';
import '../../business/ui/business_setup_screen.dart';
import '../../employees/ui/employee_pin_screen.dart';
import '../../pos/ui/pos_screen.dart';
import '../../poultry/ui/receive_chicken_screen.dart';
import '../../butcher/ui/butcher_screen.dart';
import '../../transfers/ui/send_transfer_screen.dart';
import '../../transfers/ui/receive_transfer_screen.dart';
import '../../products/ui/products_screen.dart';
import '../../sales/ui/receipts_screen.dart';
import '../../settings/ui/settings_screen.dart';
import '../../shift/ui/shift_screen.dart';
import '../../../features/auth/domain/auth_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AuthRepository get _authService => context.read<AuthRepository>();

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSessionNotifier>(
      builder: (context, sessionNotifier, _) {
        if (sessionNotifier.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = sessionNotifier.session;
        if (session == null || session.stores.isEmpty) {
          return BusinessSetupScreen(
            onCreated: () => sessionNotifier.refreshSession(),
            authRepository: context.read<AuthRepository>(),
          );
        }

        if (sessionNotifier.needsStoreSelection) {
          return _StoreSelectionScreen(
            businessName: session.business.name,
            stores: session.stores,
            onSelected: (store) => sessionNotifier.selectStore(store),
            onSignOut: _authService.signOut,
          );
        }

        final selectedStore = sessionNotifier.resolvedStore;
        final employeesForStore = sessionNotifier.employeesForStore;

        if (sessionNotifier.needsPinEntry || !sessionNotifier.isCurrentEmployeeValid) {
          return EmployeePinScreen(
            store: selectedStore,
            stores: session.stores,
            employees: employeesForStore,
            onUnlocked: (employee) => sessionNotifier.selectEmployee(employee),
            onSelectStore: (store) => sessionNotifier.selectStore(store),
            onSignOut: _authService.signOut,
          );
        }

        return _buildMainScaffold(session, selectedStore, sessionNotifier.resolvedEmployee);
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
          IconButton(
            tooltip: 'Cambiar empleado',
            icon: const Icon(Icons.badge),
            onPressed: () => context.read<AppSessionNotifier>().clearEmployee(),
          ),
          IconButton(
            tooltip: 'Cerrar sesion',
            icon: const Icon(Icons.logout),
            onPressed: _authService.signOut,
          ),
        ],
      ),
      drawer: isWide ? null : Drawer(child: _buildNavigationList(session, selectedStore)),
      body: isWide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) => setState(() => _selectedIndex = index),
                  labelType: NavigationRailLabelType.all,
                  scrollable: true,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Text(
                      '${selectedStore.name}\n${activeEmployee.name}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
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

  Widget _buildNavigationList(AppSession session, Store selectedStore) {
    final activeEmployee = context.read<AppSessionNotifier>().resolvedEmployee;
    final items = _navItems(activeEmployee);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.business.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('${selectedStore.name} · ${activeEmployee.name}', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
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
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedPage(AppSession session, Store selectedStore) {
    final activeEmployee = context.read<AppSessionNotifier>().resolvedEmployee;
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
      case 'poultry':
        return ReceiveChickenScreen(
          businessId: session.business.id,
          storeId: selectedStore.id,
          employee: activeEmployee,
        );
      case 'butcher':
        return ButcherScreen(
          businessId: session.business.id,
          store: selectedStore,
          employee: activeEmployee,
        );
      case 'send_transfer':
        return SendTransferScreen(
          businessId: session.business.id,
          fromStore: selectedStore,
          employee: activeEmployee,
          onTransferSent: () => setState(() => _selectedIndex = 0),
        );
      case 'receive_transfer':
        return ReceiveTransferScreen(
          businessId: session.business.id,
          storeId: selectedStore.id,
          employee: activeEmployee,
        );
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

  List<_NavItem> _navItems(Employee employee) {
    return [
      const _NavItem('pos', Icons.point_of_sale, 'Venta'),
      if (employee.isManager || employee.isAdmin || employee.hasPermission('receipts'))
        const _NavItem('receipts', Icons.receipt_long, 'Recibos'),
      if (employee.isManager || employee.isAdmin || employee.hasPermission('products'))
        const _NavItem('products', Icons.inventory_2, 'Productos'),
      if (employee.isManager || employee.isAdmin || employee.hasPermission('shift'))
        const _NavItem('shift', Icons.account_balance_wallet, 'Turno'),
      if (employee.isAdmin || employee.hasPermission('poultry'))
        const _NavItem('poultry', Icons.egg_alt, 'Recibir Pollo'),
      if (employee.isAdmin || employee.hasPermission('butcher'))
        const _NavItem('butcher', Icons.set_meal, 'Destazar'),
      if (employee.isAdmin || employee.isManager || employee.hasPermission('transfers')) ...const [
        _NavItem('send_transfer', Icons.arrow_upward, 'Enviar'),
        _NavItem('receive_transfer', Icons.arrow_downward, 'Recibir'),
      ],
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
