
; Mico Launcher - Instalador Windows (Preview)
; Instalacao independente do Burrow

Unicode true
!include "MUI2.nsh"

!ifndef VERSION
  !define VERSION "1.4.0"
!endif

!ifndef SOURCE
  !error "SOURCE nao definido"
!endif

!ifndef OUTFILE
  !error "OUTFILE nao definido"
!endif

!ifndef ICON
  !error "ICON nao definido"
!endif

Name "Mico Preview"
OutFile "${OUTFILE}"

RequestExecutionLevel user

InstallDir "$LOCALAPPDATA\Programs\Mico-Preview"

SetCompressor /SOLID lzma

BrandingText "Mico Preview ${VERSION}"

VIProductVersion "${VERSION}.0"
VIAddVersionKey "ProductName" "Mico Preview"
VIAddVersionKey "FileDescription" "Mico Launcher Setup"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "ProductVersion" "${VERSION}"

!define MUI_ICON "${ICON}"
!define MUI_UNICON "${ICON}"

!define MUI_ABORTWARNING

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\Mico-Preview"

Section "Mico Preview"

  ; Nao sobrescrever uma pasta que ja contenha arquivos
  IfFileExists "$INSTDIR\*.*" 0 instalar
    MessageBox MB_ICONSTOP "A pasta Mico Preview ja possui arquivos. Instalacao cancelada."
    Abort

  instalar:
  SetOutPath "$INSTDIR"


  File /r "${SOURCE}\*.*"

  WriteUninstaller "$INSTDIR\Uninstall Mico Preview.exe"

  ; Identifica uma instalacao criada pelo Mico Preview
  FileOpen $0 "$INSTDIR\.mico-preview-owned" w
  IfErrors 0 marcador_ok
    MessageBox MB_ICONSTOP "Nao foi possivel identificar a instalacao."
    Abort

  marcador_ok:
  FileWrite $0 "Mico Preview"
  FileClose $0


  CreateShortcut "$SMPROGRAMS\Mico Preview.lnk" "$INSTDIR\Mico.exe"
  CreateShortcut "$DESKTOP\Mico Preview.lnk" "$INSTDIR\Mico.exe"

  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "Mico Preview"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\Mico.exe"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\Uninstall Mico Preview.exe"'

  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1

SectionEnd


Section "Uninstall"

    ; Verificar se estamos na pasta correta
    StrCmp $INSTDIR "$LOCALAPPDATA\Programs\Mico-Preview" verificar_marcador
    MessageBox MB_ICONSTOP "Caminho de instalacao inesperado. Desinstalacao cancelada."
    Abort

verificar_marcador:
    ; Confirmar que esta pasta pertence ao Mico Preview
    IfFileExists "$INSTDIR\.mico-preview-owned" verificar_processos
    MessageBox MB_ICONSTOP "Instalacao do Mico Preview nao reconhecida."
    Abort

verificar_processos:
    ; Verificar se existe algum Mico.exe em execucao
    nsExec::Exec /TIMEOUT=15000 'powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$INSTDIR\resources\app\mico-process-check.ps1" -ExecutablePath "$INSTDIR\Mico.exe"'
    Pop $0

    StrCmp $0 "0" remover_mico
    StrCmp $0 "2" mico_aberto

    MessageBox MB_ICONSTOP "Nao foi possivel verificar os processos do Mico. Desinstalacao cancelada. Codigo: $0"
    Abort

mico_aberto:
    MessageBox MB_ICONEXCLAMATION "O Mico ainda esta aberto! Feche o aplicativo antes de desinstalar."
    Abort

remover_mico:
    ; Remover atalhos e registros
    Delete "$SMPROGRAMS\Mico Preview.lnk"
    Delete "$DESKTOP\Mico Preview.lnk"
    DeleteRegKey HKCU "${UNINSTALL_KEY}"

    ; Remover somente a instalacao identificada
    RMDir /r "$INSTDIR"

SectionEnd
