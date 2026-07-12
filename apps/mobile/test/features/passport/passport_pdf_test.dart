import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/documents/domain/entities/document.dart';
import 'package:navis_mobile/features/maintenance/data/maintenance_models.dart';
import 'package:navis_mobile/features/passport/data/passport_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const labels = PassportLabels(
    title: 'Pasaporte del barco',
    generatedOn: 'Generado el',
    boatDetails: 'Datos del barco',
    registration: 'Matrícula',
    type: 'Tipo',
    length: 'Eslora',
    homePort: 'Puerto base',
    documents: 'Documentos',
    expiry: 'Caducidad',
    status: 'Estado',
    maintenanceHistory: 'Historial de mantenimiento',
    date: 'Fecha',
    cost: 'Coste',
    expensesSummary: 'Resumen de gastos',
    total: 'Total',
    none: 'Nada registrado',
    statusExpired: 'Caducado',
    statusCritical: 'Crítico',
    statusWarning: 'Aviso',
    statusOk: 'Válido',
  );

  test('buildPassportPdf renders with Spanish/€ data without throwing',
      () async {
    const boat = Boat(
      id: 'b1',
      name: 'Mí Velero',
      registration: '7ª-BA-1234',
      type: 'sailboat',
      lengthMeters: 9.5,
      homePort: 'Málaga',
    );
    final docs = [
      Document(
        id: 'd1',
        boatId: 'b1',
        type: 'reparación', // accented API value
        expiryDate: DateTime(2027, 3, 15),
      ),
    ];
    final logs = [
      MaintenanceLog(
        id: 'm1',
        boatId: 'b1',
        type: 'Revisión motor',
        performedAt: DateTime(2026, 1, 15),
        cost: 320,
      ),
    ];
    const expenses = ExpenseSummary(
      totals: {'combustible': 120.0, 'reparación': 320.0},
      total: 440,
    );

    final bytes = await buildPassportPdf(
      boat: boat,
      documents: docs,
      maintenance: logs,
      expenses: expenses,
      labels: labels,
      generatedOnValue: '12 Jul 2026',
    );
    expect(bytes.lengthInBytes, greaterThan(1000));
  });
}
