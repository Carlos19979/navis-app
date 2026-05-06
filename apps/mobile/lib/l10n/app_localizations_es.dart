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
  String get charts => 'Cartas';

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
}
