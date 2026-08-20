// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Navis';

  @override
  String get login => 'Iniciar sesión';

  @override
  String get register => 'Registrarse';

  @override
  String get email => 'Correo electronico';

  @override
  String get password => 'Contraseña';

  @override
  String get confirmPassword => 'Confirmar contraseña';

  @override
  String get forgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get noAccount => '¿No tienes cuenta?';

  @override
  String get hasAccount => '¿Ya tienes cuenta?';

  @override
  String get boats => 'Barcos';

  @override
  String get documents => 'Documentos';

  @override
  String get trips => 'Viajes';

  @override
  String get weather => 'Clima';

  @override
  String get events => 'Eventos';

  @override
  String get charts => 'Mapa';

  @override
  String get profile => 'Perfil';

  @override
  String get settings => 'Ajustes';

  @override
  String get save => 'Guardar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Eliminar';

  @override
  String get edit => 'Editar';

  @override
  String get add => 'Agregar';

  @override
  String get retry => 'Reintentar';

  @override
  String get loading => 'Cargando...';

  @override
  String get error => 'Error';

  @override
  String get success => 'Exito';

  @override
  String get noBoats => 'Aún no tienes barcos';

  @override
  String get noDocuments => 'Aún no tienes documentos';

  @override
  String get noTrips => 'Aún no has registrado viajes';

  @override
  String get statsEmptyDescription =>
      'Registra viajes para ver aquí distancia, horas en el mar y actividad mensual.';

  @override
  String get noEvents => 'No hay eventos proximos.';

  @override
  String get expired => 'Vencido';

  @override
  String get warning => 'Advertencia';

  @override
  String get critical => 'Crítico';

  @override
  String get ok => 'OK';

  @override
  String get valid => 'Vigente';

  @override
  String daysRemaining(int count) {
    return '$count días restantes';
  }

  @override
  String daysOverdue(int count) {
    return '$count días de retraso';
  }

  @override
  String get readinessTitle => 'Estado de a bordo';

  @override
  String get readinessReady => 'Listo para navegar';

  @override
  String get readinessAttention => 'Requiere atención';

  @override
  String get readinessNotReady => 'No está listo';

  @override
  String get readinessAllGood => 'Todo en regla';

  @override
  String readinessItemsNeedAttention(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cosas pendientes',
      one: '1 cosa pendiente',
    );
    return '$_temp0';
  }

  @override
  String readinessScoreOf(int score) {
    return 'Puntuación $score / 100';
  }

  @override
  String get readinessNeedsAttention => 'Requiere atención';

  @override
  String get readinessCatDocuments => 'Documentos';

  @override
  String get readinessCatSafetyGear => 'Equipo de seguridad';

  @override
  String get readinessCatMaintenance => 'Mantenimiento';

  @override
  String readinessOkOfTotal(int ok, int total) {
    return '$ok/$total al día';
  }

  @override
  String get readinessUpgradeForFull =>
      'Desbloquea el estado completo (equipo de seguridad + mantenimiento) con Pro';

  @override
  String get readinessExpired => 'caducado';

  @override
  String readinessExpiresInDays(int days) {
    return 'en $days días';
  }

  @override
  String get readinessServiceOverdue => 'sin revisión reciente';

  @override
  String get readinessRefItb => 'Inspección técnica (ITB)';

  @override
  String get readinessRefInsurance => 'Seguro';

  @override
  String get readinessRefLifeRaft => 'Balsa salvavidas';

  @override
  String get readinessRefExtinguisher => 'Extintor';

  @override
  String get readinessRefFlares => 'Bengalas';

  @override
  String get readinessRefFirstAid => 'Botiquín';

  @override
  String get readinessRefMedicalCert => 'Certificado médico';

  @override
  String get readinessRefRadioCert => 'Certificado de radio';

  @override
  String get readinessRefNavLicense => 'Licencia de navegación';

  @override
  String get readinessRefEngineService => 'Mantenimiento';

  @override
  String get readinessRefDocument => 'Documento';

  @override
  String get costTitle => 'Inteligencia de costes';

  @override
  String get costTotalSpend => 'Gasto total';

  @override
  String get costPerNmLabel => 'Coste / MN';

  @override
  String get costPerTripLabel => 'Coste / viaje';

  @override
  String get costFuelEfficiency => 'Combustible / MN';

  @override
  String get costByCategory => 'Por categoría';

  @override
  String get costMonthlySpend => 'Gasto mensual';

  @override
  String get costTotalForPeriod => 'Coste total';

  @override
  String get costBreakdownExpenses => 'Gastos';

  @override
  String get costBreakdownMaintenance => 'Mantenimiento';

  @override
  String get costBreakdownDocuments => 'Renovaciones de documentos';

  @override
  String costPeriodUsage(String nm, int trips) {
    String _temp0 = intl.Intl.pluralLogic(
      trips,
      locale: localeName,
      other: '$trips viajes',
      one: '1 viaje',
    );
    return '$nm MN · $_temp0';
  }

  @override
  String costVsPrevious(String delta, String period) {
    return '$delta vs. $period';
  }

  @override
  String get costRunRateTitle => 'Ritmo de coste';

  @override
  String costPerMonthValue(String value) {
    return '$value/mes';
  }

  @override
  String costPerYearValue(String value) {
    return '$value/año';
  }

  @override
  String costRunRateBasis(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'Sobre $months meses con registros',
      one: 'Sobre 1 mes con registros',
    );
    return '$_temp0';
  }

  @override
  String get costPerEngineHourLabel => 'Coste / h motor';

  @override
  String get costLitersPurchased => 'Litros comprados';

  @override
  String get costFixedVsVariable => 'Fijos y variables';

  @override
  String get costFixed => 'Fijos';

  @override
  String get costVariable => 'Variables';

  @override
  String get costFixedExplainer =>
      'Los fijos (amarre, seguro, documentos) los pagas aunque el barco no salga.';

  @override
  String get costTrend => 'Tendencia';

  @override
  String costTrendAverage(String value) {
    return 'Media: $value';
  }

  @override
  String get costViewExpenses => 'Ver gastos';

  @override
  String get costEmptyMessage => 'Todavía no hay costes';

  @override
  String get costEmptyDescription =>
      'Apunta un gasto, un mantenimiento con coste o la renovación de un documento y aquí verás lo que cuesta tu barco.';

  @override
  String get costEmptyAction => 'Añadir un gasto';

  @override
  String get costLoadError => 'No se han podido cargar los costes';

  @override
  String get costNoSpendInPeriod => 'Sin costes en este periodo';

  @override
  String anomalyExcessCost(String value) {
    return '$value de combustible de más';
  }

  @override
  String get anomaliesExplainer =>
      'Viajes que gastaron mucho más por milla que la media del barco.';

  @override
  String get paywallReasonCostAnalytics =>
      'Desbloquea la inteligencia de costes con Navis Pro';

  @override
  String get costAnalyticsSubtitle =>
      'Gasto en combustible, €/MN, tendencias de coste y anomalías';

  @override
  String get proBadge => 'PRO';

  @override
  String get plusBadge => 'PLUS';

  @override
  String get status => 'Estado';

  @override
  String get total => 'Total';

  @override
  String get passportTitle => 'Pasaporte del barco';

  @override
  String get passportGeneratedOn => 'Generado el';

  @override
  String get passportBoatDetails => 'Datos del barco';

  @override
  String get passportMaintenanceHistory => 'Historial de mantenimiento';

  @override
  String get passportExpensesSummary => 'Resumen de gastos';

  @override
  String get passportNone => 'Nada registrado';

  @override
  String get passportExportFailed => 'No se pudo generar el pasaporte';

  @override
  String get passportExport => 'Exportar pasaporte';

  @override
  String get paywallReasonPassport =>
      'Exporta el pasaporte de tu barco con Navis Pro';

  @override
  String get bookingsTitle => 'Reservas';

  @override
  String get bookingsSubtitle => 'Calendario compartido de tu barco';

  @override
  String get bookingAdd => 'Reservar';

  @override
  String get bookingRangeHint =>
      'De la salida a la llegada. Misma fecha para un día de barco.';

  @override
  String get bookingDeparture => 'Salida';

  @override
  String get bookingArrival => 'Llegada';

  @override
  String get bookingDepartureDate => 'Fecha de salida';

  @override
  String get bookingDepartureTime => 'Hora de salida';

  @override
  String get bookingArrivalDate => 'Fecha de llegada';

  @override
  String get bookingArrivalTime => 'Hora de llegada';

  @override
  String get bookingEndBeforeStart =>
      'La llegada debe ser posterior a la salida';

  @override
  String bookingOverlapDetail(String range) {
    return 'Ya reservado: $range';
  }

  @override
  String get bookingsEmpty => 'Aún no hay reservas';

  @override
  String get bookingsEmptyDescription =>
      'Reserva días del barco para que copropietarios y tripulación sepan quién lo tiene y cuándo.';

  @override
  String get bookingPurposeHint => 'Motivo (opcional)';

  @override
  String get bookingDelete => 'Eliminar reserva';

  @override
  String get bookingDeleteConfirm => 'Se eliminará esta reserva.';

  @override
  String get bookingYou => 'Tú';

  @override
  String get bookingCrew => 'Tripulación';

  @override
  String get bookingOverlapsBadge => 'Se solapa con otra reserva';

  @override
  String get bookingOverlapTitle => 'Se solapa con otra reserva';

  @override
  String get bookingOverlapMessage =>
      'Estas fechas se solapan con otra reserva de este barco. ¿Reservar igualmente?';

  @override
  String get bookingBookAnyway => 'Reservar igualmente';

  @override
  String get bookingsViewCalendar => 'Vista de calendario';

  @override
  String get bookingsViewList => 'Vista de lista';

  @override
  String get bookingPrevMonth => 'Mes anterior';

  @override
  String get bookingNextMonth => 'Mes siguiente';

  @override
  String get bookingsNoneOnDay => 'No hay reservas este día';

  @override
  String get splitTitle => 'Repartir gasto';

  @override
  String get splitEqually => 'A partes iguales';

  @override
  String get splitAssigned => 'Asignado';

  @override
  String get splitSettled => 'Saldado';

  @override
  String splitYouOwe(int amount) {
    return 'Te tocan $amount €';
  }

  @override
  String splitSharedAmong(int count) {
    return 'Repartido entre $count';
  }

  @override
  String get paywallReasonShared =>
      'Coordina un barco compartido con Navis Pro';

  @override
  String get anomaliesTitle => 'Anomalías';

  @override
  String anomalyFuelHigh(int pct) {
    return 'Consumió un $pct% más de combustible por milla de lo habitual';
  }

  @override
  String get readinessMaintNoPlan => 'configura un plan de mantenimiento';

  @override
  String get readinessMaintOverdue => 'vencida';

  @override
  String get readinessMaintPending => 'sin registrar';

  @override
  String get engineHoursCurrent => 'Horas de motor actuales';

  @override
  String get engineSectionTitle => 'Motor';

  @override
  String get engineSectionHint =>
      'Horas de motor actuales. Configura las tareas de servicio en la pestaña Mantenimiento.';

  @override
  String readinessMaintInHours(int hours) {
    return 'a $hours h';
  }

  @override
  String get noMaintenanceTasks => 'Aún no hay tareas de mantenimiento';

  @override
  String get maintenanceUpcomingTitle => 'Próximos';

  @override
  String get maintenanceHistoryTitle => 'Historial';

  @override
  String get maintenanceSeeAll => 'Ver todo';

  @override
  String get suggestedTasksLabel => 'Sugeridas';

  @override
  String get editTask => 'Editar tarea';

  @override
  String get taskName => 'Nombre de la tarea';

  @override
  String get taskIntervalMonthsLabel => 'Cada (meses)';

  @override
  String get taskIntervalHoursLabel => 'Cada (horas de motor)';

  @override
  String get recordService => 'Registrar servicio';

  @override
  String get maintenanceDueSoonLabel => 'pronto';

  @override
  String get maintenanceNoInterval => 'sin intervalo';

  @override
  String get maintenanceHistoryEmpty => 'Aún no hay servicios registrados';

  @override
  String get maintenancePartOfPlan => 'Del plan (opcional)';

  @override
  String get maintenanceWhatWasDone =>
      '¿Qué se ha hecho? (ej. cambio de aceite)';

  @override
  String get maintenanceRepeatEvery => 'Se repite cada';

  @override
  String get maintenanceIntervalMonths => 'Meses';

  @override
  String get maintenanceIntervalHours => 'Horas de motor';

  @override
  String get maintenanceRepeatHint =>
      'Déjalo vacío si es puntual. Con un intervalo entra en el plan y te avisamos cuando toque.';

  @override
  String get maintenanceRepeatHintFree =>
      'Déjalo vacío si es puntual. Con un intervalo entra en el plan y la app te muestra cuándo toca.';

  @override
  String get maintenanceRemindersPlus => 'Que te avisemos es de Navis Plus';

  @override
  String get paywallReasonMaintenanceReminders =>
      'Recibe recordatorios de mantenimiento con Navis Plus';

  @override
  String maintenanceEveryMonths(int months) {
    return 'cada $months meses';
  }

  @override
  String maintenanceEveryHours(int hours) {
    return 'cada $hours h';
  }

  @override
  String maintenanceInDays(int days) {
    return 'en $days d';
  }

  @override
  String maintenanceNextDue(String date) {
    return 'próxima $date';
  }

  @override
  String maintenanceLastDone(String date) {
    return 'última $date';
  }

  @override
  String get taskEngineOil => 'Aceite de motor';

  @override
  String get taskFilters => 'Filtros';

  @override
  String get taskAnodes => 'Ánodos';

  @override
  String get taskAntifouling => 'Antifouling';

  @override
  String get taskImpeller => 'Rodete (impeller)';

  @override
  String get taskCoolant => 'Refrigerante';

  @override
  String get nauticalMiles => 'MN';

  @override
  String get knots => 'kt';

  @override
  String get kilometers => 'km';

  @override
  String get meters => 'm';

  @override
  String get boatName => 'Nombre del barco';

  @override
  String get registration => 'Número de registro';

  @override
  String get boatType => 'Tipo de barco';

  @override
  String get length => 'Eslora';

  @override
  String get homePort => 'Puerto base';

  @override
  String get sailboat => 'Velero';

  @override
  String get motorboat => 'Lancha a Motor';

  @override
  String get catamaran => 'Catamaran';

  @override
  String get other => 'Otro';

  @override
  String get documentType => 'Tipo de Documento';

  @override
  String get expiryDate => 'Fecha de Vencimiento';

  @override
  String get alertDays => 'Días de aviso antes del vencimiento';

  @override
  String get notes => 'Notas';

  @override
  String get photo => 'Foto';

  @override
  String get addPhoto => 'Agregar Foto';

  @override
  String get departure => 'Salida';

  @override
  String get arrival => 'Llegada';

  @override
  String get tripRoute => 'Ruta';

  @override
  String get distance => 'Distancia';

  @override
  String get duration => 'Duración';

  @override
  String get maxSpeed => 'Velocidad máxima';

  @override
  String get avgSpeed => 'Velocidad Promedio';

  @override
  String get resumeTripAction => 'Continuar viaje';

  @override
  String get sailWindowGoodHint =>
      'Viento flojo y mar tranquila. Buen día para salir.';

  @override
  String get sailWindowModerateHint =>
      'Se puede, sin perder de vista el viento.';

  @override
  String get sailWindowAdverseHint => 'Mejor esperar a que baje.';

  @override
  String get startTrip => 'Zarpar';

  @override
  String get stopTrip => 'Detener Viaje';

  @override
  String get pauseTrip => 'Pausar';

  @override
  String get resumeTrip => 'Reanudar';

  @override
  String get recording => 'Grabando...';

  @override
  String get totalTrips => 'Viajes Totales';

  @override
  String get tripStatistics => 'Estadísticas de viajes';

  @override
  String get tripStatisticsSubtitle => 'Distancia, horas de motor y puertos';

  @override
  String get totalDistanceNm => 'MN navegadas';

  @override
  String get totalHoursAtSea => 'Horas en el mar';

  @override
  String get portsVisited => 'Puertos visitados';

  @override
  String get topSpeed => 'Velocidad máxima';

  @override
  String get fuelConsumed => 'Combustible consumido';

  @override
  String get engineHoursTotal => 'Horas de motor';

  @override
  String get yearInReview => 'Resumen del Año';

  @override
  String get monthlyActivity => 'Actividad Mensual';

  @override
  String get tripsLabel => 'Viajes';

  @override
  String get distanceNmLabel => 'MN';

  @override
  String get hoursLabel => 'Horas';

  @override
  String get allTime => 'Todo el tiempo';

  @override
  String get totalDistance => 'Distancia Total';

  @override
  String get totalHours => 'Horas Totales';

  @override
  String get temperature => 'Temperatura';

  @override
  String get windSpeed => 'Velocidad del Viento';

  @override
  String get windDirection => 'Dirección del viento';

  @override
  String get waveHeight => 'Altura de Olas';

  @override
  String get forecast => 'Pronostico';

  @override
  String get today => 'Hoy';

  @override
  String get tomorrow => 'Mañana';

  @override
  String get eventDate => 'Fecha del Evento';

  @override
  String get eventLocation => 'Ubicación';

  @override
  String get registerForEvent => 'Registrarse';

  @override
  String get theme => 'Tema';

  @override
  String get darkMode => 'Modo Oscuro';

  @override
  String get lightMode => 'Modo Claro';

  @override
  String get language => 'Idioma';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get logout => 'Cerrar sesión';

  @override
  String get logoutConfirm => '¿Seguro que quieres cerrar sesión?';

  @override
  String get deleteConfirm => '¿Seguro que quieres eliminar esto?';

  @override
  String get requiredField => 'Este campo es obligatorio';

  @override
  String get invalidEmail => 'Por favor ingresa un correo valido';

  @override
  String get passwordTooShort =>
      'La contraseña debe tener al menos 6 caracteres';

  @override
  String get passwordsDoNotMatch => 'Las contrasenas no coinciden';

  @override
  String get engineHours => 'Horas de Motor';

  @override
  String get fuelUsed => 'Combustible Usado';

  @override
  String get crew => 'Tripulación';

  @override
  String get logbook => 'Bitácora';

  @override
  String get tripDetails => 'Detalles del viaje';

  @override
  String get editBoat => 'Editar barco';

  @override
  String get myBoats => 'Mis barcos';

  @override
  String get addBoat => 'Añadir barco';

  @override
  String get newDocument => 'Nuevo Documento';

  @override
  String get editDocument => 'Editar Documento';

  @override
  String get renewDocument => 'Renovar Documento';

  @override
  String get documentDetails => 'Detalles del Documento';

  @override
  String get renewalCost => 'Coste de Renovacion';

  @override
  String get renewalProvider => 'Proveedor / Empresa';

  @override
  String get lastRenewal => 'Última renovación';

  @override
  String get date => 'Fecha';

  @override
  String get cost => 'Coste';

  @override
  String get provider => 'Proveedor';

  @override
  String get deleteDocument => 'Eliminar Documento';

  @override
  String get deleteDocumentConfirm =>
      '¿Seguro que quieres eliminar este documento?';

  @override
  String get documentDeleted => 'Documento eliminado';

  @override
  String get documentSaved => 'Documento guardado';

  @override
  String get documentUpdated => 'Documento actualizado';

  @override
  String get documentRenewed => 'Documento renovado';

  @override
  String get failedToSave => 'Error al guardar documento';

  @override
  String get failedToDelete => 'Error al eliminar';

  @override
  String get takePhoto => 'Tomar Foto';

  @override
  String get chooseFromGallery => 'Elegir de la Galeria';

  @override
  String get addScan => 'Agregar Escaneo';

  @override
  String get notesOptional => 'Notas (opcional)';

  @override
  String get alertDaysBeforeExpiry => 'Días de aviso antes del vencimiento';

  @override
  String get validNumber => 'Introduce un número válido';

  @override
  String get uploading => 'Subiendo...';

  @override
  String get noInternetConnection => 'Sin conexión a internet';

  @override
  String offlineWithPending(int count) {
    return 'Sin conexión • $count pendientes';
  }

  @override
  String syncingChanges(int count) {
    return 'Sincronizando $count cambios…';
  }

  @override
  String get searchEvents => 'Buscar eventos...';

  @override
  String get noEventsFound => 'No se encontraron eventos';

  @override
  String get featured => 'Destacado';

  @override
  String get appearance => 'Apariencia';

  @override
  String get darkThemeActive => 'Tema oscuro activo';

  @override
  String get lightThemeActive => 'Tema claro activo';

  @override
  String get systemDefault => 'Predeterminado del sistema';

  @override
  String get selectLanguage => 'Seleccionar idioma';

  @override
  String get dataAndStorage => 'Datos y almacenamiento';

  @override
  String get clearImageCache => 'Limpiar caché de imágenes';

  @override
  String get clearImageCacheSubtitle => 'Eliminar fotos y mapas en caché';

  @override
  String get clearOfflineData => 'Limpiar datos offline';

  @override
  String get clearOfflineDataSubtitle =>
      'Eliminar barcos, documentos y viajes en caché';

  @override
  String get imageCacheCleared => 'Caché de imágenes limpiada';

  @override
  String get offlineDataCleared => 'Datos offline eliminados';

  @override
  String get account => 'Cuenta';

  @override
  String get deleteAccount => 'Eliminar cuenta';

  @override
  String get deleteAccountSubtitle =>
      'Elimina permanentemente tu cuenta y todos tus datos';

  @override
  String get deleteAccountWarning =>
      'Esto elimina permanentemente tu cuenta: barcos, documentos, viajes, historial de mantenimiento, grupos que posees y todos los archivos subidos. No se puede deshacer.';

  @override
  String deleteAccountTypeToConfirm(String word) {
    return 'Escribe $word para confirmar';
  }

  @override
  String get deleteAccountConfirmWord => 'ELIMINAR';

  @override
  String get deleteAccountFailed =>
      'No se pudo eliminar la cuenta. Inténtalo de nuevo.';

  @override
  String get deleteBoat => 'Eliminar barco';

  @override
  String deleteBoatConfirm(String name) {
    return '¿Estás seguro de que deseas eliminar \"$name\"? También se eliminarán todos los documentos y viajes asociados.';
  }

  @override
  String get certificates => 'Certificados, seguros, inspecciones';

  @override
  String get tripHistory => 'Historial de viajes e iniciar uno nuevo';

  @override
  String get modifyBoatDetails => 'Modificar detalles del barco';

  @override
  String get removePermanently => 'Eliminar este barco permanentemente';

  @override
  String get details => 'Detalles';

  @override
  String get type => 'Tipo';

  @override
  String get recordTrip => 'Registrar viaje';

  @override
  String get boat => 'Barco';

  @override
  String get boatPhoto => 'Foto del barco';

  @override
  String get goBack => 'Volver';

  @override
  String get addNewBoat => 'Añadir barco';

  @override
  String get homePortOptional => 'Puerto Base (opcional)';

  @override
  String get wind => 'Viento';

  @override
  String get waves => 'Olas';

  @override
  String get humidity => 'Humedad';

  @override
  String get dirN => 'N';

  @override
  String get dirNE => 'NE';

  @override
  String get dirE => 'E';

  @override
  String get dirSE => 'SE';

  @override
  String get dirS => 'S';

  @override
  String get dirSW => 'SO';

  @override
  String get dirW => 'O';

  @override
  String get dirNW => 'NO';

  @override
  String get currentConditions => 'Condiciones Actuales';

  @override
  String get calm => 'Calma';

  @override
  String get moderate => 'Moderado';

  @override
  String get rough => 'Fuerte';

  @override
  String get sendResetLink => 'Enviar enlace';

  @override
  String get passwordResetSent =>
      'Si existe una cuenta con ese correo, le hemos enviado un enlace. Mira también en spam.';

  @override
  String get failedToSendResetEmail =>
      'Error al enviar email de restablecimiento';

  @override
  String get newPasswordTitle => 'Establece una nueva contraseña';

  @override
  String get newPasswordSubtitle =>
      'Elige una contraseña segura para proteger tu cuenta.';

  @override
  String get newPasswordLabel => 'Nueva contraseña';

  @override
  String get resetPwSubmit => 'Actualizar contraseña';

  @override
  String get resetPwSuccess =>
      'Contraseña actualizada. Ya has iniciado sesión.';

  @override
  String get resetPwFailed =>
      'No se pudo actualizar la contraseña. Inténtalo de nuevo.';

  @override
  String get tripSaved => '¡Viaje guardado!';

  @override
  String get failedToSaveTrip => 'Error al guardar viaje';

  @override
  String get tripDeleted => 'Viaje eliminado';

  @override
  String get selectArrivalPort => 'Seleccionar Puerto de Llegada';

  @override
  String get commaSeparatedNames => 'Nombres separados por comas';

  @override
  String get crewMembers => 'Miembros de la Tripulación';

  @override
  String get updateTrip => 'Actualizar Viaje';

  @override
  String get saveTrip => 'Guardar Viaje';

  @override
  String get notLoggedIn => 'No has iniciado sesión';

  @override
  String get helpAndSupport => 'Ayuda y Soporte';

  @override
  String get contactByEmail => 'Escríbenos un correo';

  @override
  String get aboutNavis => 'Acerca de Navis';

  @override
  String get close => 'Cerrar';

  @override
  String get privacyPolicy => 'Política de privacidad';

  @override
  String get termsOfService => 'Términos de servicio';

  @override
  String get paywallAutoRenewNotice =>
      'La suscripción se renueva automáticamente salvo que la canceles en los ajustes de tu cuenta del App Store al menos 24 horas antes del fin del período en curso.';

  @override
  String aboutVersion(String version) {
    return 'Versión $version';
  }

  @override
  String get aboutDescription =>
      'El cuaderno de bitácora digital de tu barco: documentos, viajes, mantenimiento y meteo en un solo sitio.';

  @override
  String get couldNotOpenLink => 'No se pudo abrir el enlace';

  @override
  String get speedAbbr => 'VEL';

  @override
  String get headingAbbr => 'RUM';

  @override
  String get distanceAbbr => 'DIST';

  @override
  String get timeAbbr => 'TIEMPO';

  @override
  String get alert => 'Alerta';

  @override
  String get daysBeforeExpiry => 'días antes del vencimiento';

  @override
  String get selectLocation => 'Seleccionar Ubicación';

  @override
  String get totalEngineHours => 'Total horas de motor';

  @override
  String get averageSpeed => 'Velocidad promedio';

  @override
  String thisYear(String year) {
    return 'Este Año ($year)';
  }

  @override
  String get locationAccessNeeded =>
      'Se necesita acceso a la ubicación\npara datos meteorológicos.';

  @override
  String get sevenDayForecast => 'Pronóstico de 7 días';

  @override
  String get forecastNotAvailable => 'Datos de pronóstico no disponibles.';

  @override
  String get planCheckFailed =>
      'No hemos podido comprobar tu plan. Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get weatherLoadFailed =>
      'No hemos podido cargar el pronóstico. Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get hourlyLoadFailed =>
      'No se han podido cargar las horas de este día.';

  @override
  String memberSince(String date) {
    return 'Miembro desde $date';
  }

  @override
  String get deleteTrip => 'Eliminar Viaje';

  @override
  String get deleteTripConfirm =>
      '¿Estás seguro de que deseas eliminar este viaje?';

  @override
  String get shareTrip => 'Compartir viaje';

  @override
  String get editTrip => 'Editar viaje';

  @override
  String get notRecorded => 'No registrado';

  @override
  String get enterValidNumber => 'Ingresa un número válido';

  @override
  String get completeTrip => 'Completar Viaje';

  @override
  String get arrivalPort => 'Puerto de Llegada';

  @override
  String get savingTrip => 'Guardando viaje...';

  @override
  String get fuelUnit => 'L';

  @override
  String get locationPermissionRequired =>
      'Se requiere permiso de ubicación para grabar viajes';

  @override
  String get locationPermissionDenied =>
      'Permiso de ubicación denegado. Habilita en ajustes.';

  @override
  String get resetPassword => 'Restablecer Contraseña';

  @override
  String get boatManagement => 'GESTIÓN NÁUTICA';

  @override
  String get showPassword => 'Mostrar contraseña';

  @override
  String get hidePassword => 'Ocultar contraseña';

  @override
  String get pleaseEnterBoatName => 'Ingresa el nombre del barco';

  @override
  String get pleaseEnterRegistration => 'Ingresa el número de registro';

  @override
  String get pleaseEnterLength => 'Introduce la eslora';

  @override
  String get pleaseEnterEmail => 'Ingresa tu correo electrónico';

  @override
  String get pleaseEnterPassword => 'Ingresa tu contraseña';

  @override
  String get boatUpdated => 'Barco actualizado correctamente';

  @override
  String get boatCreated => 'Barco creado correctamente';

  @override
  String get failedToSaveBoat => 'Error al guardar barco';

  @override
  String get newBoat => 'Nuevo Barco';

  @override
  String get boatDetailsSection => 'Detalles del Barco';

  @override
  String locationSetAt(String lat, String lon) {
    return 'Ubicación fijada ($lat, $lon)';
  }

  @override
  String get pickLocationOnMap => 'Seleccionar ubicación en mapa';

  @override
  String get updateBoat => 'Actualizar Barco';

  @override
  String get createBoat => 'Crear Barco';

  @override
  String get createAccount => 'Crear Cuenta';

  @override
  String get joinNavisSubtitle => 'ÚNETE A NAVIS Y GESTIONA TU BARCO';

  @override
  String get pleaseConfirmPassword => 'Por favor confirma tu contraseña';

  @override
  String get confirm => 'Confirmar';

  @override
  String get selectHomePort => 'Seleccionar Puerto Base';

  @override
  String get documentInfo => 'Información del Documento';

  @override
  String get alertsAndNotes => 'Alertas y Notas';

  @override
  String get renewalDetails => 'Detalles de Renovación';

  @override
  String get documentScan => 'Escaneo de documento';

  @override
  String get saveDocument => 'Guardar Documento';

  @override
  String get updateDocument => 'Actualizar Documento';

  @override
  String get interested => 'Me interesa';

  @override
  String get notInterested => 'No me interesa';

  @override
  String get eventDetails => 'Detalles del Evento';

  @override
  String get departurePort => 'Puerto de Salida';

  @override
  String get pleaseEnterDeparturePort => 'Ingresa el puerto de salida';

  @override
  String get arrivalPortOptional => 'Puerto de Llegada (opcional)';

  @override
  String get engineHoursOptional => 'Horas de Motor (opcional)';

  @override
  String get fuelUsedOptional => 'Combustible Usado (litros, opcional)';

  @override
  String get crewMembersCommaSeparated => 'Tripulación (separados por comas)';

  @override
  String get tripUpdated => 'Viaje actualizado';

  @override
  String get failedToUpdateTrip => 'Error al actualizar viaje';

  @override
  String get somethingWentWrong => 'Algo salió mal';

  @override
  String get navisUser => 'Usuario Navis';

  @override
  String get editNameTitle => 'Tu nombre';

  @override
  String get yourName => '¿Cómo te llamamos?';

  @override
  String get previousMonth => 'Mes anterior';

  @override
  String get nextMonth => 'Mes siguiente';

  @override
  String get nearbyPorts => 'Puertos Cercanos';

  @override
  String get portTypeMarina => 'Marina';

  @override
  String get portTypeAnchorage => 'Fondeo';

  @override
  String get portTypeFuel => 'Gasolinera';

  @override
  String get portTypeCommercial => 'Comercial';

  @override
  String get portTypeFishing => 'Puerto Pesquero';

  @override
  String get portTypeOther => 'Otro';

  @override
  String depthLabel(Object depth) {
    return 'Calado: ${depth}m';
  }

  @override
  String vhfChannelLabel(Object channel) {
    return 'VHF Ch $channel';
  }

  @override
  String get portFacilities => 'Servicios';

  @override
  String get noNearbyPorts => 'No se encontraron puertos cercanos';

  @override
  String get tapPortForDetails => 'Toca un marcador para ver detalles';

  @override
  String get docTypeItb => 'Inspección técnica (ITB)';

  @override
  String get docTypeInsuranceRc => 'Seguro de responsabilidad civil';

  @override
  String get docTypeInsuranceFull => 'Seguro a todo riesgo';

  @override
  String get docTypeNavigationLicense => 'Licencia de navegación';

  @override
  String get docTypeRegistration => 'Matrícula';

  @override
  String get docTypeInsurance => 'Seguro';

  @override
  String get docTypeInspection => 'Inspección';

  @override
  String get docTypeLicense => 'Licencia';

  @override
  String get docTypeSafetyCertificate => 'Certificado de Seguridad';

  @override
  String get docTypeRadioLicense => 'Licencia de Radio';

  @override
  String get docTypePollutionCertificate => 'Certificado Anticontaminación';

  @override
  String get docTypeMedicalCertificate => 'Certificado Médico';

  @override
  String get docTypeLifeRaft => 'Balsa Salvavidas';

  @override
  String get docTypeFireExtinguisher => 'Extintor';

  @override
  String get docTypeFlares => 'Bengalas';

  @override
  String get docTypeFirstAidKit => 'Botiquín';

  @override
  String get docTypeFishingPermit => 'Permiso de Pesca';

  @override
  String get confirmLocation => 'Confirmar ubicación';

  @override
  String get portNameHint => 'Nombre del puerto (ej. Cala Blava)';

  @override
  String get tapMapToSelect => 'Toca el mapa para seleccionar una ubicación';

  @override
  String get tapMapToSetHomePort =>
      'Toca el mapa para establecer tu puerto base';

  @override
  String get zoomIn => 'Acercar';

  @override
  String get zoomOut => 'Alejar';

  @override
  String get centerOnGps => 'Centrar en GPS';

  @override
  String get toggleSeamarks => 'Señales marítimas';

  @override
  String get togglePorts => 'Mostrar puertos';

  @override
  String get toggleTripTracks => 'Mostrar rutas';

  @override
  String get now => 'Ahora';

  @override
  String get hourlyForecast => 'Por horas';

  @override
  String get wcClear => 'Despejado';

  @override
  String get wcPartlyCloudy => 'Parcialmente nublado';

  @override
  String get wcCloudy => 'Nublado';

  @override
  String get wcFog => 'Niebla';

  @override
  String get wcDrizzle => 'Llovizna';

  @override
  String get wcRain => 'Lluvia';

  @override
  String get wcSnow => 'Nieve';

  @override
  String get wcThunderstorm => 'Tormenta';

  @override
  String get wcUnknown => '—';

  @override
  String get inviteCode => 'Código de invitación';

  @override
  String get codeCopied => 'Código copiado';

  @override
  String get copy => 'Copiar';

  @override
  String get share => 'Compartir';

  @override
  String get join => 'Unirse';

  @override
  String get leave => 'Salir';

  @override
  String get view => 'Ver';

  @override
  String get remove => 'Quitar';

  @override
  String get couldNotSave => 'No se pudo guardar';

  @override
  String get couldNotDelete => 'No se pudo eliminar';

  @override
  String errorWithMessage(String message) {
    return 'Error: $message';
  }

  @override
  String get membersLabel => 'Miembros';

  @override
  String get socialLoginFailed => 'No se pudo iniciar sesión con ese proveedor';

  @override
  String get continueWithApple => 'Continuar con Apple';

  @override
  String get continueWithGoogle => 'Continuar con Google';

  @override
  String get paywallDefaultReason =>
      'Mantén tu barco legal, mantenido y seguro. Por menos que una sola multa por documentación caducada.';

  @override
  String get purchaseFailed => 'No se pudo completar la compra.';

  @override
  String get nothingToRestore => 'No hay compras que restaurar.';

  @override
  String get welcomeToPro => '¡Bienvenido a Navis Pro!';

  @override
  String get subscribe => 'Suscribirse';

  @override
  String get restorePurchases => 'Restaurar compras';

  @override
  String get manageSubscription => 'Gestionar suscripción';

  @override
  String get subscriptionsUnavailable =>
      'Las suscripciones no están disponibles en este momento. Inténtalo de nuevo más tarde.';

  @override
  String get paywallMonthly => 'Mensual';

  @override
  String get paywallYearly => 'Anual';

  @override
  String get paywallWeekly => 'Semanal';

  @override
  String get paywallLifetime => 'De por vida';

  @override
  String get proBenefitReadiness =>
      'Estado de a bordo completo: documentos, equipo de seguridad y mantenimiento';

  @override
  String get proBenefitShared =>
      'Barco compartido: calendario de reservas y reparto de gastos';

  @override
  String get proBenefitPassport =>
      'Pasaporte del barco: dossier exportable de servicio y documentos';

  @override
  String get proBenefitCostAnalytics =>
      'Inteligencia de costes: coste por milla, por viaje y por temporada';

  @override
  String get proBenefitReminders =>
      'Recordatorios ilimitados de caducidad de documentos';

  @override
  String get proBenefitMaintenance =>
      'Recordatorios de mantenimiento programado';

  @override
  String get proBenefitBoats => 'Hasta 3 barcos';

  @override
  String get plusBenefitBoats => 'Hasta 2 barcos';

  @override
  String get paywallTitle => 'Navis Plus y Pro';

  @override
  String get paywallPlusName => 'Navis Plus';

  @override
  String get paywallProName => 'Navis Pro';

  @override
  String get paywallProIncludesPlus => 'Todo lo de Plus, y además:';

  @override
  String get proBenefitGroups => 'Crea clubes y eventos';

  @override
  String get proBenefitAttachments => 'Adjuntos ilimitados en documentos';

  @override
  String get planBoatLimitReached =>
      'Has alcanzado el máximo de barcos de tu plan.';

  @override
  String get paywallReasonBoatLimit =>
      'Tu plan Free permite 1 barco. Hazte Pro para gestionar hasta 3.';

  @override
  String get joinBoat => 'Unirse a un barco';

  @override
  String get joinedBoat => 'Te has unido al barco';

  @override
  String get invalidCodeOrJoinError => 'Código inválido o error al unirse';

  @override
  String get maintenanceAndExpenses => 'Mantenimiento y gastos';

  @override
  String get maintenanceAndExpensesSubtitle => 'Servicios y costes del barco';

  @override
  String get shareBoat => 'Compartir barco';

  @override
  String get shareBoatSubtitle => 'Tripulación y copropietarios';

  @override
  String get leaveSharedBoat => 'Salir del barco compartido';

  @override
  String get leaveSharedBoatSubtitle => 'Dejar de tener acceso';

  @override
  String get couldNotGetCode => 'No se pudo obtener el código';

  @override
  String get shareBoatExplainer =>
      'Comparte este código. Quien lo introduzca entra como espectador; dale más permisos desde \"Tripulación y permisos\".';

  @override
  String shareBoatMessage(String name, String code) {
    return 'Únete a mi barco \"$name\" en Navis con el código: $code';
  }

  @override
  String shareBoatMessageWithLink(String name, String code, String link) {
    return 'Únete a mi barco \"$name\" en Navis.\n\nCódigo: $code\nAbrir en Navis: $link';
  }

  @override
  String get withAccess => 'Con acceso';

  @override
  String get notSharedYet => 'Aún no has compartido con nadie.';

  @override
  String get leaveBoat => 'Salir del barco';

  @override
  String leaveBoatConfirm(String name) {
    return 'Dejarás de tener acceso a \"$name\".';
  }

  @override
  String get removeAccess => 'Quitar acceso';

  @override
  String get groupsTitle => 'Grupos';

  @override
  String get publicLabel => 'Público';

  @override
  String get privateLabel => 'Privado';

  @override
  String membersCount(int count) {
    return '$count miembros';
  }

  @override
  String get deleteGroup => 'Eliminar grupo';

  @override
  String get deleteGroupConfirm =>
      '¿Seguro que quieres eliminar este grupo? No se puede deshacer.';

  @override
  String get leaveGroup => 'Salir del grupo';

  @override
  String get leaveGroupConfirm => '¿Quieres salir de este grupo?';

  @override
  String get groupDeleted => 'Grupo eliminado';

  @override
  String get leftGroup => 'Has salido del grupo';

  @override
  String get couldNotLeave => 'No se pudo salir';

  @override
  String get admit => 'Admitir';

  @override
  String get rejectAction => 'Rechazar';

  @override
  String get couldNotProcess => 'No se pudo procesar';

  @override
  String get noScheduledRegattas => 'No hay regatas programadas.';

  @override
  String get expelMember => 'Expulsar';

  @override
  String get memberExpelled => 'Miembro expulsado';

  @override
  String get couldNotExpel => 'No se pudo expulsar';

  @override
  String get youLabel => 'Tú';

  @override
  String userLabel(String id) {
    return 'Usuario $id';
  }

  @override
  String get scheduleAction => 'Programar';

  @override
  String get groupCreated => 'Grupo creado';

  @override
  String get couldNotCreateGroup => 'No se pudo crear el grupo';

  @override
  String get createGroup => 'Crear club';

  @override
  String get groupName => 'Nombre del grupo';

  @override
  String get descriptionOptional => 'Descripción (opcional)';

  @override
  String get groupPublicSubtitle =>
      'Cualquiera puede solicitar unirse (tú apruebas).';

  @override
  String get groupPrivateSubtitle =>
      'Solo se unen con un código de invitación.';

  @override
  String get paywallReasonGroups =>
      'Crear clubes y eventos es una función de Navis Pro.';

  @override
  String get joinByCode => 'Unirse por código';

  @override
  String joinedGroup(String name) {
    return 'Te has unido a $name';
  }

  @override
  String get joinByCodeDescription =>
      'Introduce el código de invitación que te compartieron para unirte.';

  @override
  String get joinClubTitle => 'Unirse a un club';

  @override
  String get joinEmptyCta => '¿Te han invitado? Únete con un código';

  @override
  String get requestSent => 'Solicitud enviada';

  @override
  String get couldNotRequest => 'No se pudo solicitar';

  @override
  String get requestAction => 'Solicitar';

  @override
  String get notInAnyGroup => 'Todavía no estás en ningún club.';

  @override
  String get noPublicGroups => 'No hay clubes públicos que descubrir.';

  @override
  String get cancelTrip => 'Descartar viaje';

  @override
  String get cancelTripRegattaWarning =>
      'La regata volverá a \"programada\" y se descartará la grabación.';

  @override
  String get cancelTripWarning => 'Se descartará este viaje sin guardarlo.';

  @override
  String get exitWithoutSaving => 'Salir sin guardar';

  @override
  String get exitRegattaWarning =>
      'Se descartará la grabación y la regata volverá a \"programada\".';

  @override
  String get exitTripWarning =>
      'Saldrás del mapa y se descartará la grabación sin guardar el viaje.';

  @override
  String get keepGoing => 'Seguir';

  @override
  String get noMaintenanceRecords => 'Sin registros de mantenimiento';

  @override
  String get invoiceLabel => 'Factura';

  @override
  String get costOptional => 'Coste € (opc.)';

  @override
  String get providerOptional => 'Proveedor (opc.)';

  @override
  String dateWithValue(String date) {
    return 'Fecha: $date';
  }

  @override
  String get totalSpent => 'Total gastado';

  @override
  String get noExpensesRecorded => 'Sin gastos registrados';

  @override
  String get expensesPeriodMonth => 'Mes';

  @override
  String get expensesPeriodYear => 'Año';

  @override
  String get expensesFilterAll => 'Todos';

  @override
  String get expensesPeriodTotal => 'Total del periodo';

  @override
  String get expensesPrevPeriod => 'Anterior';

  @override
  String get expensesNextPeriod => 'Siguiente';

  @override
  String get expensesNoneInPeriod => 'Sin gastos en este periodo';

  @override
  String get expensesSelectPeriod => 'Seleccionar periodo';

  @override
  String get expensesPeriodWholeYear => 'Todo el año';

  @override
  String get categoryLabel => 'Categoría';

  @override
  String get customCategory => 'Categoría personalizada';

  @override
  String get customCategoryHint => 'O escribe la tuya';

  @override
  String get amountEur => 'Importe €';

  @override
  String get couldNotUploadInvoice => 'No se pudo subir la factura';

  @override
  String get attachInvoice => 'Adjuntar factura';

  @override
  String get couldNotUploadPhoto => 'No se pudo subir la foto';

  @override
  String get photosLabel => 'Fotos';

  @override
  String get photoLabel => 'Foto';

  @override
  String get galleryTitle => 'Galería';

  @override
  String get gallerySubtitle => 'Fotos adicionales a la portada';

  @override
  String get paywallReasonLogPhotos =>
      'Añade más fotos de servicio con Navis Pro';

  @override
  String get paywallReasonGallery =>
      'Añade una galería de fotos a tu barco con Navis Pro';

  @override
  String get expenseCategoryFuel => 'Combustible';

  @override
  String get expenseCategoryMooring => 'Amarre';

  @override
  String get expenseCategoryInsurance => 'Seguro';

  @override
  String get expenseCategoryRepair => 'Reparación';

  @override
  String get expenseCategoryCleaning => 'Limpieza';

  @override
  String get expenseCategoryOther => 'Otros';

  @override
  String get safetyChecklist => 'Checklist de seguridad';

  @override
  String get addItem => 'Añadir ítem';

  @override
  String get descriptionLabel => 'Descripción';

  @override
  String get couldNotAdd => 'No se pudo añadir';

  @override
  String get couldNotUpdate => 'No se pudo actualizar';

  @override
  String get couldNotStart => 'No se pudo iniciar';

  @override
  String checklistProgress(String checked, String total) {
    return '$checked de $total listos';
  }

  @override
  String get checklistSkipHint =>
      'Recomendamos marcar todos los ítems de seguridad, pero puedes zarpar igualmente bajo tu responsabilidad.';

  @override
  String get checklistLifejackets =>
      'Chalecos salvavidas para toda la tripulación';

  @override
  String get checklistFlares => 'Bengalas y señales pirotécnicas en vigor';

  @override
  String get checklistVhf => 'Radio VHF operativa';

  @override
  String get checklistFuel => 'Nivel de combustible suficiente';

  @override
  String get checklistBilgePump => 'Bomba de achique funcionando';

  @override
  String get checklistFirstAid => 'Botiquín de primeros auxilios';

  @override
  String get checklistAnchor => 'Ancla y cabos en buen estado';

  @override
  String get checklistNavLights => 'Luces de navegación operativas';

  @override
  String get checklistWeather => 'Previsión meteorológica revisada';

  @override
  String get checklistFloatPlan => 'Plan de navegación compartido en tierra';

  @override
  String get areYouGoing => '¿Vas a ir?';

  @override
  String get prepareChecklistAndSail => 'Preparar checklist y zarpar';

  @override
  String get cancelRegatta => 'Cancelar regata';

  @override
  String get regattaInProgress => 'La regata está en curso (grabando).';

  @override
  String get deleteRegatta => 'Eliminar regata';

  @override
  String get deleteRegattaConfirm =>
      'Se eliminará esta regata de forma permanente.';

  @override
  String get regattaDeleted => 'Regata eliminada';

  @override
  String get regattaCancelled => 'Regata cancelada';

  @override
  String get couldNotCancel => 'No se pudo cancelar';

  @override
  String get couldNotRespond => 'No se pudo responder';

  @override
  String get rsvpGoing => 'Voy';

  @override
  String get rsvpMaybe => 'Quizá';

  @override
  String get rsvpNotGoing => 'No voy';

  @override
  String get rsvpGoingCount => 'Van';

  @override
  String get rsvpNotGoingCount => 'No van';

  @override
  String get selectABoat => 'Selecciona un barco';

  @override
  String get selectDeparturePortFirst => 'Selecciona el puerto de salida';

  @override
  String get regattaScheduled => 'Regata programada';

  @override
  String get couldNotSchedule => 'No se pudo programar';

  @override
  String get scheduleRegatta => 'Programar regata';

  @override
  String get regattaTitleHint => 'Título (p. ej. Regata de primavera)';

  @override
  String get selectBoatFirst => 'Selecciona un barco primero.';

  @override
  String get addBoatFirst => 'Primero añade un barco.';

  @override
  String get addCrewMemberHint => 'Añadir tripulante…';

  @override
  String get checkEmailTitle => 'Revisa tu correo';

  @override
  String checkEmailBody(String email) {
    return 'Te hemos enviado un enlace de confirmación a $email. Ábrelo para activar tu cuenta y después inicia sesión.';
  }

  @override
  String get resendEmail => 'Reenviar correo';

  @override
  String get emailResent => 'Correo enviado';

  @override
  String get couldNotResend => 'No se pudo reenviar el correo';

  @override
  String get backToLogin => 'Volver a iniciar sesión';

  @override
  String get orDivider => 'o';

  @override
  String get completeAndSail => 'Completar y zarpar';

  @override
  String get sailAnyway => 'Zarpar igualmente';

  @override
  String get statusScheduled => 'Programada';

  @override
  String get statusInProgress => 'En curso';

  @override
  String get statusCompleted => 'Completada';

  @override
  String get statusCancelled => 'Cancelada';

  @override
  String get regattaLabel => 'Regata';

  @override
  String get memberLabel => 'Miembro';

  @override
  String get joinAsGroup => 'Unirse como grupo';

  @override
  String get selectAGroup => 'Selecciona un grupo';

  @override
  String get joinedWithGroup => 'Te has unido con tu grupo';

  @override
  String get couldNotJoin => 'No se pudo unir';

  @override
  String get groupLabel => 'Grupo';

  @override
  String get createGroupFirst =>
      'Crea un grupo primero para unirte con tu equipo.';

  @override
  String get joinWithMyGroup => 'Unirse con mi grupo';

  @override
  String get sharedWithMe => 'Compartidos conmigo';

  @override
  String get sharedBoatInfo =>
      'Barco compartido contigo. Tienes los permisos que te haya dado el propietario.';

  @override
  String permissionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count permisos',
      one: '1 permiso',
    );
    return '$_temp0';
  }

  @override
  String get permRecordTrips => 'Grabar viajes';

  @override
  String get permManageExpenses => 'Gestionar gastos';

  @override
  String get permManageMaintenance => 'Gestionar mantenimiento';

  @override
  String get permViewDocuments => 'Ver documentos';

  @override
  String get permManageDocuments => 'Gestionar documentos';

  @override
  String get permBlockedTitle => 'Acción no disponible';

  @override
  String get permBlockedAskOwner =>
      'Pídele el permiso al propietario del barco.';

  @override
  String get permBlockedRecordTrips => 'No puedes grabar viajes en este barco.';

  @override
  String get permBlockedViewDocuments =>
      'No puedes ver los documentos de este barco.';

  @override
  String get permBlockedManageDocuments =>
      'No puedes añadir ni editar los documentos de este barco.';

  @override
  String get permBlockedManageMaintenance =>
      'No puedes gestionar el mantenimiento de este barco.';

  @override
  String get permBlockedManageExpenses =>
      'No puedes gestionar los gastos de este barco.';

  @override
  String get permCheckFailed =>
      'No se han podido comprobar tus permisos en este barco.';

  @override
  String get myPermissionsTitle => 'Lo que puedes hacer';

  @override
  String get boatCrewTitle => 'Tripulación y permisos';

  @override
  String get boatCrewSubtitle => 'Quién tiene acceso y qué puede hacer';

  @override
  String get boatCrewExplainer =>
      'Todos los que se han unido con tu código. Dale a cada uno solo lo que necesite.';

  @override
  String get maintenanceTab => 'Mantenimiento';

  @override
  String get expensesTab => 'Gastos';

  @override
  String get newMaintenance => 'Nuevo mantenimiento';

  @override
  String get newExpense => 'Nuevo gasto';

  @override
  String get editExpense => 'Editar gasto';

  @override
  String get invoiceAttached => 'Factura adjunta';

  @override
  String get regattasAndOutings => 'Regatas y salidas';

  @override
  String requestsCount(int count) {
    return 'Solicitudes ($count)';
  }

  @override
  String get requestAdmitted => 'Solicitud admitida';

  @override
  String get requestRejected => 'Solicitud rechazada';

  @override
  String get roleOwner => 'Armador';

  @override
  String get visibilityLabel => 'Visibilidad';

  @override
  String get myGroupsTab => 'Mis clubes';

  @override
  String get discoverTab => 'Descubrir clubes';

  @override
  String get pendingLabel => 'Pendiente';

  @override
  String membersCountShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count miembros',
      one: '1 miembro',
    );
    return '$_temp0';
  }

  @override
  String pendingCountShort(int count) {
    return '$count pend.';
  }

  @override
  String get followLive => 'Seguir en directo';

  @override
  String get couldNotOpenLive => 'No se pudo abrir el directo';

  @override
  String get backgroundLocationAdvice =>
      'Para seguir grabando con la pantalla apagada, permite el acceso a ubicación «Siempre» para Navis en Ajustes.';

  @override
  String get resumeRecordingTitle => 'Grabación en curso';

  @override
  String get resumeRecordingBody =>
      'Se interrumpió la grabación de un viaje. ¿Quieres reanudarla?';

  @override
  String get resumeAction => 'Reanudar';

  @override
  String get discardRecording => 'Descartar';

  @override
  String get noBoatsValueProp =>
      'Añade tu barco para controlar la caducidad de documentos, recibir avisos antes de las multas y llevar el mantenimiento en un solo sitio.';

  @override
  String get home => 'Inicio';

  @override
  String get community => 'Comunidad';

  @override
  String get communityRegattas => 'Regatas';

  @override
  String get communityClubs => 'Clubes';

  @override
  String get sailConditionsGood => 'Buenas condiciones para navegar';

  @override
  String get sailConditionsModerate => 'Condiciones moderadas';

  @override
  String get sailConditionsAdverse => 'Condiciones adversas';

  @override
  String windWavesSummary(String wind, String wave) {
    return 'Viento $wind kt · Olas $wave m';
  }

  @override
  String get tides => 'Mareas';

  @override
  String tideRange(String range) {
    return 'Carrera $range m';
  }

  @override
  String get tideHigh => 'Pleamar';

  @override
  String get tideLow => 'Bajamar';

  @override
  String get manageBoat => 'Gestionar barco';

  @override
  String get openSettings => 'Abrir ajustes';

  @override
  String get locationUnavailable => 'Ubicación no disponible';

  @override
  String get portsZoomInHint => 'Acerca el mapa para ver puertos';

  @override
  String get searchPortByName => 'Buscar puerto por nombre…';

  @override
  String get portSearchTypeMore => 'Escribe al menos 2 letras';

  @override
  String get noPortsFound => 'Sin puertos';

  @override
  String get portSearchError => 'No se pudieron buscar puertos';

  @override
  String get docTypeCustom => 'Otro (personalizado)';

  @override
  String get customDocumentName => 'Nombre del documento';

  @override
  String get customDocumentNameRequired => 'Introduce el nombre del documento';

  @override
  String get selectAtLeastOneAlertDay => 'Selecciona al menos una alerta';

  @override
  String alertChipDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days días',
      one: '$days día',
    );
    return '$_temp0';
  }

  @override
  String get customAlertDay => 'Personalizado';

  @override
  String get customAlertDayHint => 'Días antes del vencimiento, p. ej. 45';

  @override
  String get exportMyData => 'Exportar mis datos';

  @override
  String get exportMyDataSubtitle => 'Descarga todo en un archivo JSON';

  @override
  String get exportDataReady => 'Exportación lista para compartir';

  @override
  String get exportDataFailed =>
      'No se pudieron exportar tus datos. Inténtalo de nuevo.';

  @override
  String get anchorAlarmTitle => 'Alarma de fondeo';

  @override
  String get anchorWatchSubtitle => 'Alarma de deriva mientras fondeas';

  @override
  String get anchorDropHere => 'Fondear aquí';

  @override
  String get anchorDisarm => 'Detener vigilancia';

  @override
  String get anchorRadius => 'Radio';

  @override
  String get anchorDistance => 'Distancia';

  @override
  String get anchorMaxDistance => 'Máx. borneo';

  @override
  String get anchorGpsAccuracy => 'GPS';

  @override
  String get anchorDragTitle => '¡Garreando!';

  @override
  String get anchorDragBody => 'Tu barco ha salido del círculo de fondeo.';

  @override
  String get anchorSilence => 'Silenciar';

  @override
  String get anchorSilenced => 'Silenciada';

  @override
  String get anchorRecenter => 'Recentrar';

  @override
  String get anchorKeepPluggedIn =>
      '¿Fondeado toda la noche? Mantén el móvil enchufado: el GPS continuo consume mucha batería.';

  @override
  String get anchorDisclaimer =>
      'La alarma de fondeo es una ayuda de mejor esfuerzo, no un sistema de seguridad certificado. Mantén siempre una guardia adecuada.';

  @override
  String get anchorPermissionDenied =>
      'Se necesita permiso de ubicación para la alarma de fondeo.';

  @override
  String get anchorNoFix =>
      'Esperando señal GPS: inténtalo de nuevo en un momento.';

  @override
  String get anchorResumed => 'Vigilancia de fondeo reanudada';

  @override
  String get anchorTripActiveBlock =>
      'Detén la grabación de la travesía antes de iniciar la alarma de fondeo.';

  @override
  String get paywallReasonAnchor =>
      'Desbloquea la alarma de fondeo con Navis Plus';

  @override
  String get proBenefitAnchor =>
      'Alarma de fondeo: una alarma sonora si tu barco garrea';

  @override
  String get expenseLitersLabel => 'Litros (opcional)';

  @override
  String pricePerLiterValue(String value) {
    return '$value €/L';
  }

  @override
  String expenseLitersSummary(String liters, String price) {
    return '$liters L · $price €/L';
  }

  @override
  String get costAvgPricePerLiter => 'Precio medio';

  @override
  String get moderationReport => 'Reportar';

  @override
  String get moderationBlock => 'Bloquear usuario';

  @override
  String get moderationReportTitle => '¿Por qué lo reportas?';

  @override
  String get moderationReasonSpam => 'Spam o engañoso';

  @override
  String get moderationReasonOffensive => 'Contenido ofensivo';

  @override
  String get moderationReasonHarassment => 'Acoso';

  @override
  String get moderationReasonOther => 'Otro';

  @override
  String get moderationReportDone => 'Gracias, lo revisaremos.';

  @override
  String get moderationBlockTitle => '¿Bloquear a este usuario?';

  @override
  String get moderationBlockMessage =>
      'No verás su contenido y desaparecerá de Descubrir.';

  @override
  String get moderationBlockDone => 'Usuario bloqueado.';

  @override
  String get moderationFailed => 'No se pudo completar. Inténtalo de nuevo.';

  @override
  String get searchCommunity => 'Buscar regatas y clubes';

  @override
  String get clubsLabel => 'Clubes';

  @override
  String get searchGroups => 'Buscar clubes por nombre…';

  @override
  String get clearSearch => 'Borrar búsqueda';

  @override
  String get groupSearchTypeMore => 'Escribe al menos 2 letras';

  @override
  String get noGroupsFound => 'Ningún club coincide con ese nombre.';

  @override
  String get groupSearchError => 'No se pudieron buscar clubes';

  @override
  String get checklistPromptQuestion =>
      '¿Quieres repasar el checklist de seguridad antes de zarpar?';

  @override
  String get rememberMyChoice => 'Recordar mi elección';

  @override
  String get reviewChecklist => 'Revisar checklist';

  @override
  String get skipChecklist => 'Saltar';

  @override
  String get preTripChecklistSetting => 'Checklist antes de zarpar';

  @override
  String get preTripChecklistAsks => 'Se te preguntará al iniciar un viaje';

  @override
  String get preTripChecklistAlways => 'Se abre siempre antes de grabar';

  @override
  String get preTripChecklistSkipped =>
      'Se salta; actívalo para que vuelva a preguntar';

  @override
  String get shareFailedCopied =>
      'No se pudo abrir el menú de compartir. El texto está en el portapapeles.';

  @override
  String get shareTripLink => 'Compartir enlace';

  @override
  String get shareTripLinkSubtitle => 'Página web con el mapa del viaje';

  @override
  String get shareTripSummary => 'Compartir resumen';

  @override
  String get shareTripSummarySubtitle => 'Texto con los datos del viaje';

  @override
  String get shareLinkFailed => 'No se pudo crear el enlace';

  @override
  String get madeWithNavis => 'Hecho con Navis';

  @override
  String get tripReadOnly =>
      'Viaje de solo lectura: solo quien lo registró o el propietario del barco puede modificarlo.';

  @override
  String get tripDeleteForbidden =>
      'No tienes permiso para borrar este viaje. Pídelo al propietario del barco.';

  @override
  String get tripAlreadyDeleted => 'Este viaje ya no existe';

  @override
  String get alertChipLongPressToDelete => 'Mantén pulsado para eliminar';

  @override
  String get alertChipDeleteHint =>
      'Mantén pulsada una alerta que hayas añadido para eliminarla.';

  @override
  String get alertChipDeleteTitle => 'Eliminar alerta';

  @override
  String alertChipDeleteConfirm(int days) {
    return '¿Quitar la alerta de $days días de este documento?';
  }

  @override
  String get alertChipPresetNotRemovable =>
      'Las alertas por defecto no se pueden eliminar; toca para desactivarla.';

  @override
  String joinBoatInviteConfirm(String code) {
    return 'Te han invitado a un barco con el código $code. ¿Te unes?';
  }

  @override
  String get locationServicesOff =>
      'La ubicación está desactivada en el dispositivo.\nActívala para ver la previsión donde estás.';

  @override
  String get locationNoFixYet =>
      'No hemos podido obtener tu posición.\nAl aire libre suele tardar unos segundos.';

  @override
  String get wholeYear => 'Todo el año';

  @override
  String statsHoursAndTrips(String hours, int trips) {
    String _temp0 = intl.Intl.pluralLogic(
      trips,
      locale: localeName,
      other: '$trips viajes',
      one: '$trips viaje',
    );
    return '$hours h en el mar · $_temp0';
  }

  @override
  String get statsAvgTrip => 'Viaje medio';

  @override
  String get statsLongestTrip => 'Viaje más largo';

  @override
  String get statsLitresPerNm => 'Combustible por milla';

  @override
  String statsMorePorts(int count) {
    return '+$count más';
  }

  @override
  String get markAllRead => 'Marcar todo como leído';

  @override
  String get noNotifications => 'Sin notificaciones';

  @override
  String get noNotificationsDescription =>
      'Aquí verás los recordatorios, la actividad de tu barco y las novedades de tus clubes.';

  @override
  String unreadNotifications(int count) {
    return '$count sin leer';
  }

  @override
  String get timeJustNow => 'Ahora mismo';

  @override
  String timeMinutesAgo(int count) {
    return 'Hace $count min';
  }

  @override
  String timeHoursAgo(int count) {
    return 'Hace $count h';
  }

  @override
  String timeDaysAgo(int count) {
    return 'Hace $count d';
  }

  @override
  String get notifCategoryReminders => 'Recordatorios';

  @override
  String get notifCategoryRemindersSubtitle =>
      'Documentos que caducan y mantenimiento pendiente';

  @override
  String get notifCategoryRegattas => 'Regatas';

  @override
  String get notifCategoryRegattasSubtitle =>
      'Regatas programadas, confirmaciones y cambios';

  @override
  String get notifCategoryGroups => 'Clubes y grupos';

  @override
  String get notifCategoryGroupsSubtitle =>
      'Solicitudes de acceso y cambios de miembros';

  @override
  String get notifCategoryBoatActivity => 'Actividad del barco';

  @override
  String get notifCategoryBoatActivitySubtitle =>
      'Reservas, gastos compartidos y travesías de la tripulación';

  @override
  String get notifCategoryEvents => 'Eventos en directo';

  @override
  String get notifCategoryEventsSubtitle =>
      'Cuando empieza un evento náutico que te interesa';

  @override
  String get offlineCharts => 'Cartas offline';

  @override
  String get offlineChartsIntro =>
      'Guarda la zona donde navegas. La carta se dibuja desde el dispositivo, sin necesidad de cobertura.';

  @override
  String get offlineChartsBanner => 'Sin conexión: mostrando cartas guardadas';

  @override
  String get offlineChartsBannerEmpty =>
      'Sin conexión: no hay cartas guardadas de esta zona';

  @override
  String get downloadThisArea => 'Descargar esta zona';

  @override
  String get chartDetailStandard => 'Estándar';

  @override
  String get chartDetailFine => 'Detallado';

  @override
  String chartAreaEstimate(int tiles, String size) {
    return '$tiles teselas, unos $size';
  }

  @override
  String get chartAreaTooLarge =>
      'Esta zona es demasiado grande. Acércate o elige detalle estándar.';

  @override
  String get downloadingCharts => 'Guardando cartas';

  @override
  String get chartsDownloadDone => 'Cartas guardadas para uso sin conexión';

  @override
  String get chartsDownloadFailed =>
      'La descarga no pudo terminar. Revisa la conexión e inténtalo de nuevo.';

  @override
  String get chartsDownloadCancelled =>
      'Descarga detenida. Lo guardado sigue disponible.';

  @override
  String get noSavedAreas => 'Todavía no has guardado cartas';

  @override
  String get noSavedAreasDescription =>
      'Abre la carta, encuadra la zona donde navegas y pulsa el botón de descarga.';

  @override
  String get manageSavedAreas => 'Gestionar zonas guardadas';

  @override
  String chartStorageUsed(String size) {
    return '$size en este dispositivo';
  }

  @override
  String chartRegionDetail(int minZoom, int maxZoom, String size) {
    return 'Zoom $minZoom-$maxZoom, $size';
  }

  @override
  String get chartRegionIncomplete => 'Incompleta';

  @override
  String get deleteArea => 'Eliminar zona';

  @override
  String deleteAreaConfirm(String name) {
    return 'Se borrarán del dispositivo las cartas guardadas de \"$name\".';
  }

  @override
  String get areaDeleted => 'Zona eliminada';

  @override
  String get bgRecordingTitle => 'Navis está grabando tu viaje';

  @override
  String get bgRecordingBody => 'Seguimiento GPS activo - toca para abrir';

  @override
  String get bgAnchorWatchTitle => 'Guardia de fondeo activa';

  @override
  String get bgAnchorWatchBody => 'Vigilando tu posición - toca para abrir';

  @override
  String get authLinkOpening => 'Abriendo Navis...';

  @override
  String get authLinkExpiredTitle => 'El enlace ya no vale';

  @override
  String get authLinkExpiredBody =>
      'Los enlaces caducan al cabo de una hora y solo se pueden usar una vez. Pide uno nuevo desde «Olvidaste tu contraseña».';

  @override
  String get changeBoat => 'Cambiar barco';

  @override
  String get nextUp => 'Próximo';

  @override
  String get seeAll => 'Ver todo';

  @override
  String get todayNothingDue => 'No hay nada pendiente';

  @override
  String get anchorActionShort => 'Fondeo';

  @override
  String alertsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count avisos',
      one: '1 aviso',
    );
    return '$_temp0';
  }

  @override
  String get otherBoatsNeedAttention => 'otro barco requiere atención';

  @override
  String get boatData => 'Datos del barco';

  @override
  String get exploreClubs => 'Explorar clubes';

  @override
  String get noEventsDescription =>
      'Las regatas las programa un club. Únete a uno, o crea el tuyo.';

  @override
  String get seeAllExpenses => 'Ver todo el histórico';

  @override
  String get expensesEmptyPeriodDescription =>
      'Puede haber apuntes en otro periodo.';
}
