abstract final class ApiEndPoints {
  // Point to your Connector host (change this for different environments)

  // For local development with Laragon (default Apache port 80):
  //static String baseUrl = 'http://localhost';

  // Alternative configurations:
  // static String baseUrl = 'http://127.0.0.1';  // Alternative localhost
  // static String baseUrl = 'http://localhost:8080';  // If using custom port
  // static String baseUrl = 'http://ix.test';  // If using Laravel Valet
  static String baseUrl = 'http://ix.com'; // For production/staging

  static String apiUrl = '/connector/api';

  //#region used by http

  ///auth
  static String loginUrl = '$baseUrl/oauth/token';
  static String getUser = '$baseUrl$apiUrl/user/loggedin';

  ///attendance
  static String checkIn = '$baseUrl$apiUrl/clock-in';
  static String checkOut = '$baseUrl$apiUrl/clock-out';
  static String getAttendance = '$baseUrl$apiUrl/get-attendance/';

  ///contact
  static String contact = '$baseUrl$apiUrl/contactapi';
  static String getContact = '$contact?type=customer&per_page=500';
  static String addContact = '$contact?type=customer';
  //contact payment
  static String customerDue = '$contact/';
  static String addContactPayment = '$contact-payment';

  //#endregion

  //#region used by Dio

  ///Notifications
  static String allNotifications = '$apiUrl/notifications';

  ///brands
  static String allBrands = '$apiUrl/brand';

  ///Purchases
  static String purchases = '$apiUrl/purchase';
  //#endregion
}
