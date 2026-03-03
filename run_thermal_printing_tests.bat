@echo off
REM Thermal Printing Feature Test Runner for Windows
REM Run this script to execute all thermal printing tests

echo ========================================
echo THERMAL PRINTING FEATURE TEST SUITE
echo ========================================
echo.

setlocal enabledelayedexpansion

REM Initialize results
set manager_result=0
set generator_result=0
set service_result=0

echo Running Thermal Printer Manager Tests...
flutter test test/services/thermal_printer_manager_test.dart
set manager_result=!errorlevel!

echo.
echo Running ESC/POS Receipt Generator Tests...
flutter test test/services/esc_pos_receipt_generator_test.dart
set generator_result=!errorlevel!

echo.
echo Running Thermal Printing Service Integration Tests...
flutter test test/services/thermal_printing_service_integration_test.dart
set service_result=!errorlevel!

echo.
echo ========================================
echo TEST RESULTS SUMMARY
echo ========================================

if %manager_result% equ 0 (
    echo [OK] Thermal Printer Manager Tests: PASSED
) else (
    echo [FAIL] Thermal Printer Manager Tests: FAILED
)

if %generator_result% equ 0 (
    echo [OK] ESC/POS Receipt Generator Tests: PASSED
) else (
    echo [FAIL] ESC/POS Receipt Generator Tests: FAILED
)

if %service_result% equ 0 (
    echo [OK] Thermal Printing Service Integration Tests: PASSED
) else (
    echo [FAIL] Thermal Printing Service Integration Tests: FAILED
)

echo.
if %manager_result% equ 0 if %generator_result% equ 0 if %service_result% equ 0 (
    echo ========================================
    echo ALL TESTS PASSED SUCCESSFULLY!
    echo ========================================
    exit /b 0
) else (
    echo ========================================
    echo SOME TESTS FAILED
    echo ========================================
    exit /b 1
)
