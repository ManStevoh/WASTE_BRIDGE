/// Paths relative to [AppConstants.apiBaseUrl] (include `/api/v1` in the base URL).
class ApiEndpoints {
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const authRefresh = '/auth/refresh';
  static const me = '/auth/me';
  static const logout = '/auth/logout';
  static const logoutAll = '/auth/logout-all';

  static const otpRequest = '/auth/otp/request';
  static const otpVerify = '/auth/otp/verify';

  static const kycSubmissions = '/kyc/submissions';
  static String kycSubmission(String publicId) => '/kyc/submissions/$publicId';

  static String adminKycSubmission(String publicId) =>
      '/admin/kyc/submissions/$publicId';

  static const notifications = '/notifications';

  static const wallet = '/wallet';
  static const userWallet = '/user/wallet';
  static const walletTransactions = '/wallet/transactions';
  static const walletWithdraw = '/wallet/withdraw';

  static const marketplace = '/marketplace';
  static const marketplacePurchase = '/marketplace/purchase';
  static String marketplaceBid(String listingPublicId) =>
      '/marketplace/listings/$listingPublicId/bid';

  static const orders = '/orders';
  static String order(String orderPublicId) => '/orders/$orderPublicId';
  static String orderCancel(String orderPublicId) =>
      '/orders/$orderPublicId/cancel';

  static String userRatings(String userPublicId) =>
      '/users/$userPublicId/ratings';
  static const wasteCreate = '/waste/create';
  static const pickupRequest = '/pickup/request';
  static const pickupAccept = '/pickup/accept';
  static const paymentInitiate = '/payment/initiate';

  static String receipt(String receiptId) => '/receipts/$receiptId';

  static String receiptPdf(String receiptId) => '/receipts/$receiptId/pdf';

  static const requests = '/requests';
  static const jobs = '/jobs';

  static String jobAccept(String jobPublicId) => '/jobs/$jobPublicId/accept';

  static String jobUpdate(String jobPublicId) => '/jobs/$jobPublicId';

  static String requestProof(String requestPublicId) =>
      '/requests/$requestPublicId/proof';

  static String requestRatings(String requestPublicId) =>
      '/requests/$requestPublicId/ratings';

  static String requestDispute(String requestPublicId) =>
      '/requests/$requestPublicId/dispute';

  static String requestDisputeResolve(String requestPublicId) =>
      '/requests/$requestPublicId/dispute/resolve';
}
