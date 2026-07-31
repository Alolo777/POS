import 'package:provider/provider.dart';

import '../domain/app_context_repository.dart';
import '../app_context_service.dart';
import '../network/connectivity_service.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/auth/data/auth_service.dart';
import '../../features/business/domain/business_repository.dart';
import '../../features/business/data/business_service.dart';
import '../../features/business/domain/backup_repository.dart';
import '../../features/business/data/backup_service.dart';
import '../../features/butcher/domain/butcher_repository.dart';
import '../../features/butcher/data/butcher_service.dart';
import '../../features/employees/domain/employee_repository.dart';
import '../../features/employees/data/employee_service.dart';
import '../../features/inventory/domain/inventory_repository.dart';
import '../../features/inventory/data/inventory_service.dart';
import '../../features/inventory/domain/stock_repository.dart';
import '../../features/inventory/data/stock_service.dart';
import '../../features/pos/domain/category_repository.dart';
import '../../features/pos/data/category_service.dart';
import '../../features/pos/domain/discount_repository.dart';
import '../../features/pos/data/discount_service.dart';
import '../../features/pos/domain/modifier_repository.dart';
import '../../features/pos/data/modifier_service.dart';
import '../../features/pos/domain/open_ticket_repository.dart';
import '../../features/pos/data/open_ticket_service.dart';
import '../../features/products/domain/product_repository.dart';
import '../../features/products/data/product_service.dart';
import '../../features/poultry/domain/poultry_repository.dart';
import '../../features/poultry/data/poultry_service.dart';
import '../../features/transfers/domain/transfer_repository.dart';
import '../../features/transfers/data/transfer_service.dart';
import '../../features/sales/domain/pdf_repository.dart';
import '../../features/sales/data/pdf_service.dart';
import '../../features/sales/domain/sale_repository.dart';
import '../../features/sales/data/sale_service.dart';
import '../../features/shift/domain/shift_repository.dart';
import '../../features/shift/data/shift_service.dart';

class ServiceLocator {
  late final ConnectivityService connectivityService;
  late final AppContextRepository appContextRepository;
  late final AuthRepository authRepository;
  late final BusinessRepository businessRepository;
  late final BackupRepository backupRepository;
  late final EmployeeRepository employeeRepository;
  late final ProductRepository productRepository;
  late final CategoryRepository categoryRepository;
  late final ModifierRepository modifierRepository;
  late final DiscountRepository discountRepository;
  late final OpenTicketRepository openTicketRepository;
  late final StockRepository stockRepository;
  late final InventoryRepository inventoryRepository;
  late final SaleRepository saleRepository;
  late final ShiftRepository shiftRepository;
  late final ButcherRepository butcherRepository;
  late final PdfRepository pdfRepository;
  late final PoultryRepository poultryRepository;
  late final TransferRepository transferRepository;

  ServiceLocator() {
    connectivityService = ConnectivityService();
    appContextRepository = AppContextService();
    authRepository = AuthService();
    businessRepository = BusinessService();
    backupRepository = BackupService();
    employeeRepository = EmployeeService();
    productRepository = ProductService(
      connectivityService: connectivityService,
    );
    categoryRepository = CategoryService();
    modifierRepository = ModifierService();
    discountRepository = DiscountService();
    openTicketRepository = OpenTicketService();
    stockRepository = StockService();
    inventoryRepository = InventoryService(
      connectivityService: connectivityService,
    );
    saleRepository = SaleService(
      connectivityService: connectivityService,
      stockService: stockRepository as StockService,
    );
    shiftRepository = ShiftService(
      connectivityService: connectivityService,
    );
    butcherRepository = ButcherService.create(
      connectivityService: connectivityService,
    );
    pdfRepository = PdfService();
    poultryRepository = PoultryService();
    transferRepository = TransferService();
  }

  List<Provider> get providers => [
    Provider<ConnectivityService>.value(value: connectivityService),
    Provider<AppContextRepository>.value(value: appContextRepository),
    Provider<AuthRepository>.value(value: authRepository),
    Provider<BusinessRepository>.value(value: businessRepository),
    Provider<BackupRepository>.value(value: backupRepository),
    Provider<EmployeeRepository>.value(value: employeeRepository),
    Provider<ProductRepository>.value(value: productRepository),
    Provider<CategoryRepository>.value(value: categoryRepository),
    Provider<ModifierRepository>.value(value: modifierRepository),
    Provider<DiscountRepository>.value(value: discountRepository),
    Provider<OpenTicketRepository>.value(value: openTicketRepository),
    Provider<StockRepository>.value(value: stockRepository),
    Provider<InventoryRepository>.value(value: inventoryRepository),
    Provider<SaleRepository>.value(value: saleRepository),
    Provider<ShiftRepository>.value(value: shiftRepository),
    Provider<ButcherRepository>.value(value: butcherRepository),
    Provider<PdfRepository>.value(value: pdfRepository),
    Provider<PoultryRepository>.value(value: poultryRepository),
    Provider<TransferRepository>.value(value: transferRepository),
  ];
}
