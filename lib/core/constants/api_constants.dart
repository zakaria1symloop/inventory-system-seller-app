class ApiConstants {
  // Local development
  // static const String baseUrl = 'http://192.168.100.36:8080/api';
  // Production:
  static const String baseUrl = 'https://rafik-biskra.symloop.com/api';
  static const Duration timeout = Duration(seconds: 30);

  // Auth
  static const String login = '/login';
  static const String logout = '/logout';
  static const String user = '/user';

  // Sync
  static const String masterData = '/sync/master-data';
  static const String pushChanges = '/sync/push';

  // Trips
  static const String trips = '/trips';
  static const String myActiveTrip = '/my-active-trip';
  static const String myTrips = '/my-trips';

  // Orders
  static const String orders = '/orders';
  static const String myOrders = '/my-orders';

  // Products
  static const String products = '/products';

  // Clients
  static const String clients = '/clients';
}
