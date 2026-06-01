; SGI LAB MANAGER - Inno Setup Script
; Requiere Inno Setup 6.x: https://jrsoftware.org/isinfo.php

#define AppName "SGI LAB MANAGER"
#define AppVersion "1.0.0"
#define AppPublisher "PCJIC Rionegro"
#define AppURL "https://apisgi.foxyyts.qzz.io"
#define AppExeName "SGI_LAB_MANAGER.exe"
#define BuildDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{A3F2C1D4-8B5E-4F9A-B2C7-3E6D1A0F4B8C}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
DefaultDirName={autopf}\SGI LAB MANAGER
DefaultGroupName={#AppName}
AllowNoIcons=yes
; Icono del instalador (usa el mismo icono de la app)
SetupIconFile=..\windows\runner\resources\app_icon.ico
; Compresion LZMA maxima
Compression=lzma2/ultra64
SolidCompression=yes
; Requiere Windows 10 o superior
MinVersion=10.0
; Solo arquitectura x64
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Directorio de salida del instalador
OutputDir=.
OutputBaseFilename=SGI-LAB-MANAGER-Setup-v{#AppVersion}
; Pide privilegios de administrador para instalar en Program Files
PrivilegesRequired=admin
; Mostrar licencia (opcional, comentar si no hay)
; LicenseFile=license.txt
WizardStyle=modern
; Desinstalar desde Panel de control
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Ejecutable principal
Source: "{#BuildDir}\{#AppExeName}";         DestDir: "{app}"; Flags: ignoreversion

; DLLs de Flutter y plugins
Source: "{#BuildDir}\flutter_windows.dll";                    DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\sqlite3.dll";                            DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\dartjni.dll";                            DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\connectivity_plus_plugin.dll";           DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\flutter_secure_storage_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\url_launcher_windows_plugin.dll";        DestDir: "{app}"; Flags: ignoreversion

; Carpeta de datos (assets, fuentes, shaders, etc.)
Source: "{#BuildDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Acceso directo en el Menu Inicio
Name: "{group}\{#AppName}";        Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\{#AppExeName}"
Name: "{group}\Desinstalar {#AppName}"; Filename: "{uninstallexe}"

; Acceso directo en el Escritorio (solo si el usuario lo pidio)
Name: "{autodesktop}\{#AppName}";  Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
; Ofrece ejecutar la app al terminar la instalacion
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Elimina la base de datos local al desinstalar (opcional — comentar para preservar datos)
; Type: filesandordirs; Name: "{localappdata}\SGI LAB MANAGER"
