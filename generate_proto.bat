@echo off
chcp 65001 >nul
REM Protobuf Code Generation

echo ========================================
echo   Protobuf 代码生成
echo ========================================
echo.

REM 检查本地 protoc 是否存在
if not exist "tools\protoc\bin\protoc.exe" (
    echo 错误: 本地 protoc 未找到
    echo 请运行以下命令下载:
    echo   dart run generate_proto.dart
    exit /b 1
)

REM 检查 protoc-gen-dart 是否安装正确版本
dart pub global list | findstr "protoc_plugin 21.1.2" >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo 正在安装 protoc-gen-dart 21.1.2 ^(兼容 protobuf 4.x^)...
    call dart pub global activate protoc_plugin 21.1.2
    if %ERRORLEVEL% NEQ 0 (
        echo 错误: protoc-gen-dart 安装失败
        exit /b 1
    )
    echo.
)

REM 生成代码
echo 正在生成 Dart Protobuf 代码...
echo 输入文件: proto/lobby.proto
echo 输出目录: lib/core/models
echo.

tools\protoc\bin\protoc.exe --plugin=protoc-gen-dart="%LOCALAPPDATA%\Pub\Cache\bin\protoc-gen-dart.bat" --dart_out=lib/core/models proto/lobby.proto

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo   生成成功！
    echo ========================================
    echo.
) else (
    echo.
    echo ========================================
    echo   生成失败！
    echo ========================================
    exit /b 1
)
