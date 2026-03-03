import '../usecase.dart';

/// Manage staff schedules and shifts
class ManageStaffScheduleUseCase extends UseCase<void, ManageScheduleParams> {
  @override
  Future<void> call(ManageScheduleParams params) async {
    // Implementation handled by repository
    throw UnimplementedError();
  }
}

class ManageScheduleParams {
  final String businessId;
  final String workerId;
  final String operation; // create, update, delete, approve
  final ShiftData? shiftData;

  ManageScheduleParams({
    required this.businessId,
    required this.workerId,
    required this.operation,
    this.shiftData,
  });
}

class ShiftData {
  final DateTime startTime;
  final DateTime endTime;
  final String position;
  final String? notes;
  final bool isRecurring;
  final List<String>? recurringDays;

  ShiftData({
    required this.startTime,
    required this.endTime,
    required this.position,
    this.notes,
    this.isRecurring = false,
    this.recurringDays,
  });
}

/// Get staff availability
class GetStaffAvailabilityUseCase
    extends UseCase<List<StaffMember>, GetAvailabilityParams> {
  @override
  Future<List<StaffMember>> call(GetAvailabilityParams params) async {
    // Implementation handled by repository
    throw UnimplementedError();
  }
}

class GetAvailabilityParams {
  final String businessId;
  final DateTime date;
  final String? position;

  GetAvailabilityParams({
    required this.businessId,
    required this.date,
    this.position,
  });
}

class StaffMember {
  final String id;
  final String name;
  final String position;
  final bool isAvailable;
  final List<Shift> assignedShifts;
  final double rating;
  final List<String> skills;

  StaffMember({
    required this.id,
    required this.name,
    required this.position,
    required this.isAvailable,
    required this.assignedShifts,
    required this.rating,
    required this.skills,
  });
}

class Shift {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final String status; // scheduled, active, completed, cancelled
  final String? notes;

  Shift({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.notes,
  });
}

/// Calculate staff performance
class CalculatePerformanceUseCase
    extends UseCase<PerformanceMetrics, PerformanceParams> {
  @override
  Future<PerformanceMetrics> call(PerformanceParams params) async {
    // Implementation handled by repository
    throw UnimplementedError();
  }
}

class PerformanceParams {
  final String businessId;
  final String workerId;
  final DateTime startDate;
  final DateTime endDate;

  PerformanceParams({
    required this.businessId,
    required this.workerId,
    required this.startDate,
    required this.endDate,
  });
}

class PerformanceMetrics {
  final String workerId;
  final double averageRating;
  final int completedTasks;
  final int missedShifts;
  final double productivityScore;
  final List<String> strengths;
  final List<String> areasForImprovement;

  PerformanceMetrics({
    required this.workerId,
    required this.averageRating,
    required this.completedTasks,
    required this.missedShifts,
    required this.productivityScore,
    required this.strengths,
    required this.areasForImprovement,
  });
}

/// Manage payroll
class ManagePayrollUseCase extends UseCase<PayrollReport, PayrollParams> {
  @override
  Future<PayrollReport> call(PayrollParams params) async {
    // Implementation handled by repository
    throw UnimplementedError();
  }
}

class PayrollParams {
  final String businessId;
  final DateTime payPeriodStart;
  final DateTime payPeriodEnd;
  final String? workerId;

  PayrollParams({
    required this.businessId,
    required this.payPeriodStart,
    required this.payPeriodEnd,
    this.workerId,
  });
}

class PayrollReport {
  final DateTime payPeriod;
  final List<EmployeePayslip> payslips;
  final double totalPayroll;
  final double totalDeductions;
  final double totalNetPay;

  PayrollReport({
    required this.payPeriod,
    required this.payslips,
    required this.totalPayroll,
    required this.totalDeductions,
    required this.totalNetPay,
  });
}

class EmployeePayslip {
  final String employeeId;
  final String employeeName;
  final double grossSalary;
  final double deductions;
  final double netSalary;
  final int hoursWorked;
  final List<Deduction> deductionDetails;

  EmployeePayslip({
    required this.employeeId,
    required this.employeeName,
    required this.grossSalary,
    required this.deductions,
    required this.netSalary,
    required this.hoursWorked,
    required this.deductionDetails,
  });
}

class Deduction {
  final String type; // tax, insurance, pension
  final double amount;

  Deduction({required this.type, required this.amount});
}

