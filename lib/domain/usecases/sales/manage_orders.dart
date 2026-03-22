import '../usecase.dart';

/// Create and manage orders
class CreateOrderUseCase extends UseCase<Order, CreateOrderParams> {
  @override
  Future<Order> call(CreateOrderParams params) async {
    if (params.businessId.trim().isEmpty) {
      throw ArgumentError('businessId is required');
    }
    if (params.customerId.trim().isEmpty) {
      throw ArgumentError('customerId is required');
    }
    if (params.items.isEmpty) {
      throw ArgumentError('items cannot be empty');
    }

    final subtotal = params.items.fold<double>(
      0,
      (sum, item) => sum + (item.unitPrice * item.quantity),
    );
    final taxes = subtotal * 0.075;
    final total = subtotal + taxes;
    final createdAt = DateTime.now();
    final fulfillment = await CalculateFulfillmentTimeUseCase().call(
      CalculateFulfillmentParams(
        businessId: params.businessId,
        orderType: params.orderType,
        itemCount: params.items.fold<int>(0, (sum, item) => sum + item.quantity),
      ),
    );

    return Order(
      id: 'ord_${createdAt.microsecondsSinceEpoch}',
      businessId: params.businessId,
      customerId: params.customerId,
      items: params.items,
      subtotal: subtotal,
      taxes: taxes,
      total: total,
      status: 'pending',
      orderType: params.orderType,
      createdAt: createdAt,
      expectedCompletionTime: fulfillment.estimatedCompletionTime,
      deliveryAddress: params.deliveryAddress,
      paymentStatus: 'unpaid',
    );
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
    const allowedStatuses = {
      'pending',
      'confirmed',
      'preparing',
      'ready',
      'completed',
      'cancelled',
    };
    if (params.businessId.trim().isEmpty || params.orderId.trim().isEmpty) {
      throw ArgumentError('businessId and orderId are required');
    }
    if (!allowedStatuses.contains(params.newStatus.toLowerCase())) {
      throw ArgumentError('Unsupported order status: ${params.newStatus}');
    }
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
    if (params.businessId.trim().isEmpty) return const [];
    return const [];
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
    if (params.businessId.trim().isEmpty) {
      throw ArgumentError('businessId is required');
    }
    final baseMinutes = switch (params.orderType.toLowerCase()) {
      'delivery' => 45,
      'pickup' => 20,
      'dine-in' => 15,
      _ => 25,
    };
    final estimatedMinutes = baseMinutes + (params.itemCount * 4);
    final estimatedCompletionTime =
        (params.preferredTime ?? DateTime.now()).add(Duration(minutes: estimatedMinutes));
    final priority = params.itemCount >= 8
        ? 'high'
        : params.itemCount >= 4
            ? 'normal'
            : 'low';

    return FulfillmentEstimate(
      estimatedCompletionTime: estimatedCompletionTime,
      estimatedMinutes: estimatedMinutes,
      priority: priority,
      isPossible: true,
      reason: null,
    );
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
    if (params.businessId.trim().isEmpty) {
      throw ArgumentError('businessId is required');
    }
    final stops = <DeliveryStop>[];
    for (var i = 0; i < params.orderIds.length; i++) {
      stops.add(
        DeliveryStop(
          orderId: params.orderIds[i],
          address: 'Delivery stop ${i + 1}',
          latitude: 0,
          longitude: 0,
          sequenceNumber: i + 1,
        ),
      );
    }
    return DeliveryRoute(
      stops: stops,
      totalDistance: params.orderIds.length * 2.5,
      estimatedTime: params.orderIds.length * 15,
      estimatedCost: params.orderIds.length * 750,
    );
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

