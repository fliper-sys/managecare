import '../usecase.dart';

/// Create and manage orders
class CreateOrderUseCase extends UseCase<Order, CreateOrderParams> {
  @override
  Future<Order> call(CreateOrderParams params) async {
    // Implementation handled by repository
    throw UnimplementedError();
  }
}

class CreateOrderParams {
  final String businessId;
  final String customerId;
  final List<OrderItem> items;
  final String orderType; // delivery, pickup, dine-in
  final String? deliveryAddress;
  final String? specialInstructions;

  CreateOrderParams({
    required this.businessId,
    required this.customerId,
    required this.items,
    required this.orderType,
    this.deliveryAddress,
    this.specialInstructions,
  });
}

class OrderItem {
  final String itemId;
  final int quantity;
  final double unitPrice;
  final List<String>? customizations;

  OrderItem({
    required this.itemId,
    required this.quantity,
    required this.unitPrice,
    this.customizations,
  });
}

class Order {
  final String id;
  final String businessId;
  final String customerId;
  final List<OrderItem> items;
  final double subtotal;
  final double taxes;
  final double total;
  final String
      status; // pending, confirmed, preparing, ready, completed, cancelled
  final String orderType;
  final DateTime createdAt;
  final DateTime? expectedCompletionTime;
  final String? deliveryAddress;
  final String paymentStatus;

  Order({
    required this.id,
    required this.businessId,
    required this.customerId,
    required this.items,
    required this.subtotal,
    required this.taxes,
    required this.total,
    required this.status,
    required this.orderType,
    required this.createdAt,
    this.expectedCompletionTime,
    this.deliveryAddress,
    required this.paymentStatus,
  });
}

/// Update order status
class UpdateOrderStatusUseCase extends UseCase<void, UpdateOrderStatusParams> {
  @override
  Future<void> call(UpdateOrderStatusParams params) async {
    // Implementation handled by repository
    throw UnimplementedError();
  }
}

class UpdateOrderStatusParams {
  final String businessId;
  final String orderId;
  final String newStatus;
  final String? notes;

  UpdateOrderStatusParams({
    required this.businessId,
    required this.orderId,
    required this.newStatus,
    this.notes,
  });
}

/// Get order history
class GetOrderHistoryUseCase
    extends UseCase<List<OrderSummary>, GetOrderHistoryParams> {
  @override
  Future<List<OrderSummary>> call(GetOrderHistoryParams params) async {
    // Implementation handled by repository
    throw UnimplementedError();
  }
}

class GetOrderHistoryParams {
  final String businessId;
  final String? customerId;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? status;
  final int limit;

  GetOrderHistoryParams({
    required this.businessId,
    this.customerId,
    this.startDate,
    this.endDate,
    this.status,
    this.limit = 50,
  });
}

class OrderSummary {
  final String id;
  final String customerId;
  final double total;
  final String status;
  final DateTime createdAt;
  final int itemCount;

  OrderSummary({
    required this.id,
    required this.customerId,
    required this.total,
    required this.status,
    required this.createdAt,
    required this.itemCount,
  });
}

/// Calculate fulfillment time
class CalculateFulfillmentTimeUseCase
    extends UseCase<FulfillmentEstimate, CalculateFulfillmentParams> {
  @override
  Future<FulfillmentEstimate> call(CalculateFulfillmentParams params) async {
    // Implementation handled by repository
    throw UnimplementedError();
  }
}

class CalculateFulfillmentParams {
  final String businessId;
  final String orderType;
  final int itemCount;
  final DateTime? preferredTime;

  CalculateFulfillmentParams({
    required this.businessId,
    required this.orderType,
    required this.itemCount,
    this.preferredTime,
  });
}

class FulfillmentEstimate {
  final DateTime estimatedCompletionTime;
  final int estimatedMinutes;
  final String priority; // low, normal, high
  final bool isPossible;
  final String? reason;

  FulfillmentEstimate({
    required this.estimatedCompletionTime,
    required this.estimatedMinutes,
    required this.priority,
    required this.isPossible,
    this.reason,
  });
}

/// Manage delivery routes (for food delivery, retail)
class OptimizeDeliveryRouteUseCase
    extends UseCase<DeliveryRoute, OptimizeRouteParams> {
  @override
  Future<DeliveryRoute> call(OptimizeRouteParams params) async {
    // Implementation handled by repository
    throw UnimplementedError();
  }
}

class OptimizeRouteParams {
  final String businessId;
  final List<String> orderIds;
  final String currentLocation;

  OptimizeRouteParams({
    required this.businessId,
    required this.orderIds,
    required this.currentLocation,
  });
}

class DeliveryRoute {
  final List<DeliveryStop> stops;
  final double totalDistance;
  final int estimatedTime;
  final double estimatedCost;

  DeliveryRoute({
    required this.stops,
    required this.totalDistance,
    required this.estimatedTime,
    required this.estimatedCost,
  });
}

class DeliveryStop {
  final String orderId;
  final String address;
  final double latitude;
  final double longitude;
  final int sequenceNumber;

  DeliveryStop({
    required this.orderId,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.sequenceNumber,
  });
}

