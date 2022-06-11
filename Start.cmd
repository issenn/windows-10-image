@echo off
:: title �ٷ� ISO �򲹶���
title Patching Official ISO...

:: Proxy configuration
:: If you need to configure a proxy to be able to connect to the internet,
:: then you can do this by configuring the all_proxy environment variable.
:: By default this variable is empty, configuring aria2c to not use any proxy.
::
:: Usage: set "all_proxy=proxy_address"
:: For example: set "all_proxy=127.0.0.1:8888"
::
:: More information how to use this can be found at:
:: https://aria2.github.io/manual/en/html/aria2c.html#cmdoption-all-proxy
:: https://aria2.github.io/manual/en/html/aria2c.html#environment

set "all_proxy=127.0.0.1:3129"

:: End of proxy configuration

cd /d "%~dp0"
if NOT "%cd%"=="%cd: =%" (
    :: echo ��ǰ·��Ŀ¼�����ո�
    :: echo ���Ƴ���������Ŀ¼�������ո�
    echo Current directory contains spaces in its path.
    echo Please move or rename the directory to one not containing spaces.
    echo.
    pause
    goto :EOF
)

:::::::::::::::::::::::::::::::::::::::::
:: Automatically check & get admin rights
:::::::::::::::::::::::::::::::::::::::::
@REM  --> Check for permissions
if "[%1]" == "[49127c4b-02dc-482e-ac4f-ec4d659b7547]" goto :START_PROCESS
REG QUERY HKU\S-1-5-19\Environment >NUL 2>&1 && goto :START_PROCESS

set command="""%~f0""" 49127c4b-02dc-482e-ac4f-ec4d659b7547
SETLOCAL ENABLEDELAYEDEXPANSION
set "command=!command:'=''!"

powershell -NoProfile Start-Process -FilePath '%COMSPEC%' ^
-ArgumentList '/c """!command!"""' -Verb RunAs 2>NUL

@REM --> If error flag set, we do not have admin.
IF %ERRORLEVEL% GTR 0 (
    echo =====================================================
    :: echo �˽ű���Ҫʹ�ù���ԱȨ��ִ�С�
    echo This script needs to be executed as an administrator.
    echo =====================================================
    echo.
    pause
)

SETLOCAL DISABLEDELAYEDEXPANSION
goto :EOF

:START_PROCESS
set "aria2=bin\aria2c.exe"
set "a7z=bin\7z.exe"
set _dism="C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe"
set "patchDir=patch"
set "ISODir=ISO"
set "build="
set "arch="

if NOT EXIST %aria2% goto :NO_ARIA2_ERROR
if NOT EXIST %a7z% goto :NO_FILE_ERROR
if NOT EXIST %_dism% (
  set "_dism=dism.exe"
  @REM if NOT EXIST !_dism! goto :NO_FILE_ERROR
)

:: dir /b /a:-d Win10*.iso 1>nul 2>nul && (for /f "delims=" %%# in ('dir /b /a:-d *.iso') do set "isofile=%%#")
:: if EXIST "Win10*.iso" goto :NO_ISO_PATCHED_ERROR
if NOT EXIST "base\*.iso" goto :NO_ISO_ERROR
dir /b /a:-d "base\*.iso" 1>nul 2>nul && (for /f "delims=" %%# in ('dir /b /a:-d "base\*.iso"') do set "isofile=base\%%#")
if EXIST "%~dp0%ISODir%" rmdir /s /q "%~dp0%ISODir%"
%a7z% x "%~dp0%isofile%" -o"%~dp0%ISODir%" -r

if EXIST "%~dp0%ISODir%\sources\install.esd" (
  %_dism% /English /Export-Image /SourceImageFile:%~dp0%ISODir%\sources\install.esd /All /DestinationImageFile:%~dp0%ISODir%\sources\install.wim /Compress:max
  del /f /q "%~dp0%ISODir%\sources\install.esd"
)

if NOT EXIST "%~dp0%ISODir%\sources\install.wim" (goto :NOT_SUPPORT)

%_dism% /English /get-wiminfo /wimfile:"%~dp0%ISODir%\sources\install.wim" /index:1 | find /i "Version : 10.0" 1>nul || (set "MESSAGE=���� wim �汾���� Windows 10 �� 11 / Detected wim version is not Windows 10 or 11"&goto :EOF)
for /f "tokens=4 delims=:. " %%# in ('dism.exe /English /get-wiminfo /wimfile:"%~dp0%ISODir%\sources\install.wim" /index:1 ^| find /i "Version :"') do set build=%%#
for /f "tokens=2 delims=: " %%# in ('dism.exe /English /get-wiminfo /wimfile:"%~dp0%ISODir%\sources\install.wim" /index:1 ^| find /i "Architecture"') do set arch=%%#

if %build%==19041 (set /a build=19044)
if %build%==19042 (set /a build=19044)
if %build%==19043 (set /a build=19044)
if %build%==14393 if %arch%==x86 (goto :NOT_SUPPORT)

if NOT EXIST "source\script_%build%_%arch%.txt" goto :NOT_SUPPORT

:: echo �������ز�����
:: echo Patch Downloading...
echo Attempting to download files...
"%aria2%" --no-conf --log-level=info --log="logs\aria2_download.log" --check-certificate=false -x16 -s16 -j5 -c -R -d"%patchDir%" -i"source\script_%build%_%arch%.txt"
if %ERRORLEVEL% GTR 0 call :DOWNLOAD_ERROR & exit /b 1

if EXIST W10UI.cmd goto :START_WORKWORK
pause
goto :EOF

:START_WORKWORK
pause
call W10UI.cmd
goto :EOF

:NO_ARIA2_ERROR
:: echo ��ǰĿ¼δ�ҵ� %aria2%��
echo We couldn't find %aria2% in current directory.
echo.
:: echo ���ԴӴ����� aria2:
echo You can download aria2 from:
echo https://aria2.github.io/
echo.
pause
goto :EOF

:NO_FILE_ERROR
echo δ���ֽű������ļ���
echo We couldn't find one of needed files for this script.
pause
goto :EOF

:NO_ISO_ERROR
:: echo ��ѹٷ� ISO �ļ��ŵ��ű�ͬĿ¼�¡�
echo Please put official ISO file next to the script.
pause
goto :EOF

:NO_ISO_PATCHED_ERROR
:: echo ���ֿ����Ѵ򲹶��� ISO �ļ������Ƴ����顣
echo Discovering a potentially patched ISO, Please remove or check.
echo (%isofile%)
pause
goto :EOF

:DOWNLOAD_ERROR
echo.
:: echo �����ļ����������³��ԡ�
echo We have encountered an error while downloading files.
pause
goto :EOF

:NOT_SUPPORT
echo.
rmdir /s /q "%~dp0%ISODir%"
:: echo ��֧�ִ� ISO �汾���� ISO �ļ��쳣��
echo Not support this version ISO. or the ISO file error.
echo Version: %build%, Architecture: %arch%
pause
goto :EOF

:: echo ���� 7 �˳���
echo Press 7 to exit.
choice /c 7 /n
if errorlevel 1 (goto :eof) else (rem.)

:EOF
