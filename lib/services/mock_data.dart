import 'package:waste_bridge/models/app_enums.dart';
import 'package:waste_bridge/models/app_notification.dart';
import 'package:waste_bridge/models/app_transaction.dart';
import 'package:waste_bridge/models/app_user.dart';
import 'package:waste_bridge/models/job.dart';
import 'package:waste_bridge/models/waste_request.dart';

class MockData {
  static final users = <AppUser>[
    const AppUser(
      id: 'u1',
      name: 'Amina Yusuf',
      email: 'amina@generator.com',
      role: UserRole.generator,
      kycStatus: KycStatus.verified,
      isVerified: true,
      subscriptionPlan: 'Business Pro',
      referralCode: 'AMINA-REF-01',
    ),
    const AppUser(
      id: 'u2',
      name: 'Kola Rider',
      email: 'kola@collector.com',
      role: UserRole.collector,
      kycStatus: KycStatus.verified,
      isVerified: true,
      subscriptionPlan: 'Collector Basic',
      referralCode: 'KOLA-REF-02',
    ),
    const AppUser(
      id: 'u3',
      name: 'GreenCycle Ltd',
      email: 'ops@recycler.com',
      role: UserRole.recycler,
      kycStatus: KycStatus.pending,
      isVerified: false,
      subscriptionPlan: 'Recycler Plus',
      referralCode: 'GREEN-REF-03',
    ),
  ];

  static final requests = <WasteRequest>[
    WasteRequest(
      id: 'wr1',
      wasteType: 'Plastic',
      quantityKg: 12,
      location: 'Yaba, Lagos',
      status: RequestStatus.accepted,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      acceptedAt: DateTime.now().subtract(
        const Duration(hours: 4, minutes: 20),
      ),
      suggestedCollectorName: 'Kola Rider',
      estimatedEtaMinutes: 18,
      scheduledAt: DateTime.now().subtract(
        const Duration(hours: 3, minutes: 30),
      ),
      distanceKm: 4.2,
      unitPricePerKg: 420,
      totalAmount: 5040,
      paymentStatus: PaymentStatus.pending,
      receiptId: 'RCPT-WR1',
      receiptIssuedAt: DateTime.now().subtract(const Duration(hours: 1)),
      co2SavedKg: 21.6,
    ),
    WasteRequest(
      id: 'wr2',
      wasteType: 'Organic',
      quantityKg: 6,
      location: 'Lekki Phase 1',
      status: RequestStatus.pending,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      suggestedCollectorName: 'EcoMove Dispatch',
      estimatedEtaMinutes: 32,
      scheduledAt: DateTime.now().add(const Duration(hours: 6)),
      rescheduledAt: DateTime.now().add(const Duration(hours: 8)),
      distanceKm: 9.1,
      unitPricePerKg: 180,
      totalAmount: 1080,
      paymentStatus: PaymentStatus.unpaid,
      isDisputed: true,
      disputeReason: 'Collector delayed initial pickup slot',
      co2SavedKg: 4.2,
    ),
  ];

  static final jobs = <Job>[
    const Job(
      id: 'j1',
      requestId: 'wr1',
      pickupLocation: 'Yaba, Lagos',
      wasteType: 'Plastic',
      quantityKg: 12,
      earning: 2500,
      status: JobStatus.open,
    ),
    const Job(
      id: 'j2',
      requestId: 'wr3',
      pickupLocation: 'Surulere',
      wasteType: 'Metal',
      quantityKg: 10,
      earning: 3200,
      status: JobStatus.accepted,
    ),
  ];

  static final transactions = <AppTransaction>[
    AppTransaction(
      id: 't1',
      material: 'Plastic',
      quantityKg: 50,
      amount: 35000,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      type: TransactionType.credit,
      description: 'Pickup payout settlement',
      balanceAfter: 35000,
    ),
    AppTransaction(
      id: 't2',
      material: 'Paper',
      quantityKg: 25,
      amount: 12000,
      createdAt: DateTime.now().subtract(const Duration(days: 6)),
      type: TransactionType.debit,
      description: 'Marketplace service fee',
      balanceAfter: 23000,
    ),
  ];

  static final notifications = <AppNotification>[
    AppNotification(
      id: 'n1',
      title: 'Pickup Assigned',
      message: 'A collector has been assigned to your request.',
      type: NotificationType.pickupAssigned,
      createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
    ),
    AppNotification(
      id: 'n2',
      title: 'Collector Arriving',
      message: 'Your collector is 10 minutes away.',
      type: NotificationType.collectorArriving,
      createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
    ),
  ];
}
