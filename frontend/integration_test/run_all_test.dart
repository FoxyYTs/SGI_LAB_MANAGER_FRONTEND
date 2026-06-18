// Punto de entrada único para correr todos los integration tests.
//
// Uso:
//   flutter test integration_test/run_all_test.dart \
//     --dart-define=SERVER_URL=https://dev-apisgi.foxyyts.qzz.io \
//     -d linux
import 'package:integration_test/integration_test.dart';

import '01_login_test.dart'     as login;
import '02_inventario_test.dart' as inventario;
import '03_prestamos_test.dart'  as prestamos;
import '04_bitacora_test.dart'   as bitacora;
import '05_sga_test.dart'        as sga;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  login.main();
  inventario.main();
  prestamos.main();
  bitacora.main();
  sga.main();
}
