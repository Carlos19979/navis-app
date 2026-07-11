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
  String get login => 'Iniciar Sesion';

  @override
  String get register => 'Registrarse';

  @override
  String get email => 'Correo electronico';

  @override
  String get password => 'Contrasena';

  @override
  String get confirmPassword => 'Confirmar Contrasena';

  @override
  String get forgotPassword => 'Olvidaste tu contrasena?';

  @override
  String get noAccount => 'No tienes una cuenta?';

  @override
  String get hasAccount => 'Ya tienes una cuenta?';

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
  String get noBoats => 'Aun no tienes barcos. Agrega tu primer barco!';

  @override
  String get noDocuments =>
      'Aun no tienes documentos. Agrega tu primer documento!';

  @override
  String get noTrips =>
      'Aun no has registrado viajes. Comienza tu primer viaje!';

  @override
  String get noEvents => 'No hay eventos proximos.';

  @override
  String get expired => 'Vencido';

  @override
  String get warning => 'Advertencia';

  @override
  String get critical => 'Critico';

  @override
  String get ok => 'OK';

  @override
  String get valid => 'Vigente';

  @override
  String daysRemaining(int count) {
    return '$count dias restantes';
  }

  @override
  String daysOverdue(int count) {
    return '$count dias vencido';
  }

  @override
  String get nauticalMiles => 'MN';

  @override
  String get knots => 'nudos';

  @override
  String get kilometers => 'km';

  @override
  String get meters => 'm';

  @override
  String get boatName => 'Nombre del Barco';

  @override
  String get registration => 'Numero de Registro';

  @override
  String get boatType => 'Tipo de Barco';

  @override
  String get length => 'Eslora (m)';

  @override
  String get homePort => 'Puerto Base';

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
  String get alertDays => 'Dias de Alerta Antes del Vencimiento';

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
  String get distance => 'Distancia';

  @override
  String get duration => 'Duracion';

  @override
  String get maxSpeed => 'Velocidad Maxima';

  @override
  String get avgSpeed => 'Velocidad Promedio';

  @override
  String get startTrip => 'Iniciar Viaje';

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
  String get tripStatistics => 'Estadísticas de Viajes';

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
  String get allTime => 'Total Histórico';

  @override
  String get totalDistance => 'Distancia Total';

  @override
  String get totalHours => 'Horas Totales';

  @override
  String get temperature => 'Temperatura';

  @override
  String get windSpeed => 'Velocidad del Viento';

  @override
  String get windDirection => 'Direccion del Viento';

  @override
  String get waveHeight => 'Altura de Olas';

  @override
  String get forecast => 'Pronostico';

  @override
  String get today => 'Hoy';

  @override
  String get tomorrow => 'Manana';

  @override
  String get eventDate => 'Fecha del Evento';

  @override
  String get eventLocation => 'Ubicacion';

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
  String get logout => 'Cerrar Sesion';

  @override
  String get logoutConfirm => 'Estas seguro de que deseas cerrar sesion?';

  @override
  String get deleteConfirm => 'Estas seguro de que deseas eliminar esto?';

  @override
  String get requiredField => 'Este campo es obligatorio';

  @override
  String get invalidEmail => 'Por favor ingresa un correo valido';

  @override
  String get passwordTooShort =>
      'La contrasena debe tener al menos 6 caracteres';

  @override
  String get passwordsDoNotMatch => 'Las contrasenas no coinciden';

  @override
  String get engineHours => 'Horas de Motor';

  @override
  String get fuelUsed => 'Combustible Usado';

  @override
  String get crew => 'Tripulacion';

  @override
  String get logbook => 'Bitácora';

  @override
  String get tripDetails => 'Detalles del Viaje';

  @override
  String get editBoat => 'Editar Barco';

  @override
  String get myBoats => 'Mis Barcos';

  @override
  String get addBoat => 'Agregar Barco';

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
  String get lastRenewal => 'Ultima Renovacion';

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
      'Estas seguro de que deseas eliminar este documento?';

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
  String get alertDaysBeforeExpiry => 'Dias de Alerta Antes del Vencimiento';

  @override
  String get validNumber => 'Por favor ingresa un numero valido';

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
  String get documentExpiryAlerts => 'Alertas de vencimiento';

  @override
  String get expiryAlertsSubtitle =>
      'Recibe alertas antes de que venzan los documentos';

  @override
  String get eventReminders => 'Recordatorios de eventos';

  @override
  String get eventRemindersSubtitle =>
      'Recibe recordatorios de eventos próximos';

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
  String get tripHistory => 'Historial de viajes y estadísticas';

  @override
  String get modifyBoatDetails => 'Modificar detalles del barco';

  @override
  String get removePermanently => 'Eliminar este barco permanentemente';

  @override
  String get details => 'Detalles';

  @override
  String get type => 'Tipo';

  @override
  String get statistics => 'Estadísticas';

  @override
  String get recordTrip => 'Registrar viaje';

  @override
  String get boat => 'Barco';

  @override
  String get boatPhoto => 'Foto del barco';

  @override
  String get goBack => 'Volver';

  @override
  String get addNewBoat => 'Agregar nuevo barco';

  @override
  String get homePortOptional => 'Puerto Base (opcional)';

  @override
  String get wind => 'Viento';

  @override
  String get waves => 'Olas';

  @override
  String get humidity => 'Humedad';

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
      'Email de restablecimiento enviado. Revisa tu bandeja.';

  @override
  String get failedToSendResetEmail =>
      'Error al enviar email de restablecimiento';

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
  String get pleaseEnterLength => 'Ingresa la eslora';

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
  String get proBenefitReminders =>
      'Recordatorios ilimitados de caducidad de documentos';

  @override
  String get proBenefitMaintenance =>
      'Recordatorios de mantenimiento programado';

  @override
  String get proBenefitBoats => 'Hasta 3 barcos';

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
      'Comparte este código. Quien lo introduzca verá el barco. Activa \"puede grabar viajes\" abajo para darle permiso de editor.';

  @override
  String shareBoatMessage(String name, String code) {
    return 'Únete a mi barco \"$name\" en Navis con el código: $code';
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
  String get createGroup => 'Crear grupo';

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
  String get requestSent => 'Solicitud enviada';

  @override
  String get couldNotRequest => 'No se pudo solicitar';

  @override
  String get requestAction => 'Solicitar';

  @override
  String get notInAnyGroup => 'Aún no estás en ningún grupo.';

  @override
  String get noPublicGroups => 'No hay grupos públicos para descubrir.';

  @override
  String get cancelTrip => 'Cancelar viaje';

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
  String get maintenanceTypeHint => 'Tipo (ej. cambio de aceite)';

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
  String get categoryLabel => 'Categoría';

  @override
  String get amountEur => 'Importe €';

  @override
  String get couldNotUploadInvoice => 'No se pudo subir la factura';

  @override
  String get attachInvoice => 'Adjuntar factura';

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
  String get myGroupsTab => 'Mis grupos';

  @override
  String get discoverTab => 'Descubrir';

  @override
  String get pendingLabel => 'Pendiente';

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
}
