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
  String get logbook => 'Cuaderno de Bitacora';

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
}
