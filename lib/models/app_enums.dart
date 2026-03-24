enum UserRole { generator, collector, recycler }

enum RequestStatus { pending, accepted, pickedUp, completed, cancelled }

enum JobStatus { open, accepted, arrived, picked, delivered }

enum NotificationType { pickupAssigned, collectorArriving, deliveryCompleted }

enum PaymentStatus { unpaid, pending, paid }

enum KycStatus { notSubmitted, pending, verified, rejected }

enum TransactionType { credit, debit }
