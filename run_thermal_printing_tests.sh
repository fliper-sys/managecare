#!/bin/bash
# Thermal Printing Feature Test Runner
# Run this script to execute all thermal printing tests

echo "========================================"
echo "THERMAL PRINTING FEATURE TEST SUITE"
echo "========================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Run tests
echo "Running Thermal Printer Manager Tests..."
flutter test test/services/thermal_printer_manager_test.dart
manager_result=$?

echo ""
echo "Running ESC/POS Receipt Generator Tests..."
flutter test test/services/esc_pos_receipt_generator_test.dart
generator_result=$?

echo ""
echo "Running Thermal Printing Service Integration Tests..."
flutter test test/services/thermal_printing_service_integration_test.dart
service_result=$?

echo ""
echo "========================================"
echo "TEST RESULTS SUMMARY"
echo "========================================"

if [ $manager_result -eq 0 ]; then
    echo -e "${GREEN}✓ Thermal Printer Manager Tests: PASSED${NC}"
else
    echo -e "${RED}✗ Thermal Printer Manager Tests: FAILED${NC}"
fi

if [ $generator_result -eq 0 ]; then
    echo -e "${GREEN}✓ ESC/POS Receipt Generator Tests: PASSED${NC}"
else
    echo -e "${RED}✗ ESC/POS Receipt Generator Tests: FAILED${NC}"
fi

if [ $service_result -eq 0 ]; then
    echo -e "${GREEN}✓ Thermal Printing Service Integration Tests: PASSED${NC}"
else
    echo -e "${RED}✗ Thermal Printing Service Integration Tests: FAILED${NC}"
fi

echo ""
if [ $manager_result -eq 0 ] && [ $generator_result -eq 0 ] && [ $service_result -eq 0 ]; then
    echo -e "${GREEN}========================================"
    echo "ALL TESTS PASSED SUCCESSFULLY!"
    echo "========================================${NC}"
    exit 0
else
    echo -e "${RED}========================================"
    echo "SOME TESTS FAILED"
    echo "========================================${NC}"
    exit 1
fi
