; Mico Launcher - Instalador Windows (Oficial)
; Versao com suporte a atualizacao controlada da instalacao existente.
; IMPORTANTE: validar em instalacao de teste antes de distribuicao publica.

Unicode true
!include "MUI2.nsh"
!include "WordFunc.nsh"
!insertmacro VersionCompare

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

Name "Mico"
OutFile "${OUTFILE}"
RequestExecutionLevel user
InstallDir "$LOCALAPPDATA\Programs\Mico"
SetCompressor /SOLID lzma
BrandingText "Mico ${VERSION}"

VIProductVersion "${VERSION}.0"
VIAddVersionKey "ProductName" "Mico"
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
!insertmacro MUI_UNPAGE_FINISH

!insertmacro MUI_LANGUAGE "PortugueseBR"

!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\Mico"

Var MicoStage
Var MicoBackup
Var MicoMode
Var MicoOldVersion

Section "Mico"
  ; O destino e fixo. Evita instalacao em outra pasta via /D=.
  StrCmp "$INSTDIR" "$LOCALAPPDATA\Programs\Mico" caminho_ok
  MessageBox MB_ICONSTOP "Caminho de instalacao inesperado. Instalacao cancelada."
  Abort

caminho_ok:
  StrCpy $MicoStage "$LOCALAPPDATA\Programs\Mico-Update-Staging"
  StrCpy $MicoBackup "$LOCALAPPDATA\Programs\Mico-Update-Backup"

  ; Nunca sobrescrever temporarios deixados por falha anterior.
  IfFileExists "$MicoStage" temporarios_pendentes
  IfFileExists "$MicoBackup" temporarios_pendentes

  ; Primeira instalacao, ou atualizacao de uma instalacao conhecida.
  IfFileExists "$INSTDIR\*.*" instalacao_existente primeira_instalacao

instalacao_existente:
  IfFileExists "$INSTDIR\.mico-release-owned" 0 nao_reconhecida
  IfFileExists "$INSTDIR\Mico.exe" 0 instalacao_incompleta
  IfFileExists "$INSTDIR\resources\app\mico-process-check.ps1" 0 instalacao_incompleta

  ReadRegStr $MicoOldVersion HKCU "${UNINSTALL_KEY}" "DisplayVersion"
  StrCmp "$MicoOldVersion" "" instalacao_incompleta

  ; Impede regressao de versao (reinstalacao da mesma versao e permitida).
  ${VersionCompare} "$MicoOldVersion" "${VERSION}" $R0
  StrCmp "$R0" "1" versao_mais_nova

  ; O Mico Oficial precisa estar fechado para a atualizacao.
  nsExec::Exec /TIMEOUT=15000 'powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$INSTDIR\resources\app\mico-process-check.ps1" -ExecutablePath "$INSTDIR\Mico.exe"'
  Pop $R0
  StrCmp "$R0" "0" pode_atualizar
  StrCmp "$R0" "2" mico_aberto_instalacao
  Goto falha_verificacao_instalacao

pode_atualizar:
  StrCpy $MicoMode "update"
  Goto preparar

primeira_instalacao:
  StrCpy $MicoMode "new"

preparar:
  ; Extrair a nova versao fora do diretorio em uso.
  ClearErrors
  SetOutPath "$MicoStage"
  IfErrors falha_preparacao
  File /r "${SOURCE}\*.*"

  ; O desinstalador detecta seu diretorio ao ser executado no futuro.
  WriteUninstaller "$MicoStage\Uninstall Mico.exe"
  IfErrors falha_preparacao

  FileOpen $R0 "$MicoStage\.mico-release-owned" w
  IfErrors falha_preparacao
  FileWrite $R0 "Mico"
  FileClose $R0

  IfFileExists "$MicoStage\Mico.exe" 0 falha_preparacao
  IfFileExists "$MicoStage\resources\app\build.json" 0 falha_preparacao
  IfFileExists "$MicoStage\resources\app\mico-process-check.ps1" 0 falha_preparacao

  ; Windows nao permite renomear o diretorio atual de trabalho.
  SetOutPath "$LOCALAPPDATA\Programs"
  StrCmp "$MicoMode" "update" trocar_atualizacao trocar_instalacao_nova

trocar_atualizacao:
  ClearErrors
  Rename "$INSTDIR" "$MicoBackup"
  IfErrors falha_backup

  ClearErrors
  Rename "$MicoStage" "$INSTDIR"
  IfErrors tentar_restaurar
  Goto concluir

tentar_restaurar:
  ClearErrors
  Rename "$MicoBackup" "$INSTDIR"
  IfErrors restauracao_falhou
  MessageBox MB_ICONSTOP "Nao foi possivel ativar a nova versao. A instalacao anterior foi restaurada. A pasta Mico-Update-Staging foi preservada para analise."
  Abort

restauracao_falhou:
  MessageBox MB_ICONSTOP "Falha critica na troca de versao. Nao apague a pasta Mico-Update-Backup; ela contem sua instalacao anterior. Solicite suporte antes de tentar novamente."
  Abort

trocar_instalacao_nova:
  ; Se a pasta de destino existe, ela deve estar vazia.
  RMDir "$INSTDIR"
  ClearErrors
  Rename "$MicoStage" "$INSTDIR"
  IfErrors falha_instalacao_nova

concluir:
  CreateShortcut "$SMPROGRAMS\Mico.lnk" "$INSTDIR\Mico.exe"
  CreateShortcut "$DESKTOP\Mico.lnk" "$INSTDIR\Mico.exe"

  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "Mico"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\Mico.exe"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\Uninstall Mico.exe"'
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1

  StrCmp "$MicoMode" "update" 0 fim_instalacao
  SetOutPath "$LOCALAPPDATA\Programs"
  ClearErrors
  RMDir /r "$MicoBackup"
  IfErrors backup_nao_removido
  Goto fim_instalacao

backup_nao_removido:
  MessageBox MB_ICONEXCLAMATION "O Mico foi atualizado, mas a pasta Mico-Update-Backup nao foi removida totalmente. Confira o programa antes de limpar manualmente o backup."
  Goto fim_instalacao

temporarios_pendentes:
  MessageBox MB_ICONSTOP "Existem pastas de uma atualizacao anterior. Instalacao cancelada para preservar possiveis arquivos de recuperacao. Solicite suporte antes de remove-las."
  Abort

nao_reconhecida:
  MessageBox MB_ICONSTOP "A pasta Mico ja contem arquivos, mas nao e uma instalacao reconhecida. Nenhum arquivo foi alterado."
  Abort

instalacao_incompleta:
  MessageBox MB_ICONSTOP "A instalacao atual esta incompleta ou nao possui os dados de atualizacao. Nao foi alterada."
  Abort

versao_mais_nova:
  MessageBox MB_ICONSTOP "Ja existe uma versao mais recente do Mico instalada ($MicoOldVersion). Esta instalacao foi cancelada."
  Abort

mico_aberto_instalacao:
  MessageBox MB_ICONEXCLAMATION "O Mico Oficial esta aberto. Feche o aplicativo para atualizar."
  Abort

falha_verificacao_instalacao:
  MessageBox MB_ICONSTOP "Nao foi possivel verificar os processos do Mico. Codigo: $R0. Atualizacao cancelada."
  Abort

falha_preparacao:
  MessageBox MB_ICONSTOP "Falha ao preparar a nova versao. A instalacao atual nao foi modificada. A pasta temporaria foi preservada para analise."
  Abort

falha_backup:
  MessageBox MB_ICONSTOP "Nao foi possivel preservar a instalacao anterior. Nada foi substituido. A pasta temporaria foi preservada para analise."
  Abort

falha_instalacao_nova:
  MessageBox MB_ICONSTOP "Nao foi possivel concluir a instalacao. A pasta temporaria foi preservada para analise."
  Abort

fim_instalacao:
SectionEnd

Section "Uninstall"
  ; Mesma protecao que passou nos testes da versao 1.4.0.
  StrCmp "$INSTDIR" "$LOCALAPPDATA\Programs\Mico" verificar_marcador
  MessageBox MB_ICONSTOP "Caminho de instalacao inesperado. Desinstalacao cancelada."
  Abort

verificar_marcador:
  IfFileExists "$INSTDIR\.mico-release-owned" verificar_processos
  MessageBox MB_ICONSTOP "Instalacao do Mico nao reconhecida."
  Abort

verificar_processos:
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
  Delete "$SMPROGRAMS\Mico.lnk"
  Delete "$DESKTOP\Mico.lnk"
  DeleteRegKey HKCU "${UNINSTALL_KEY}"
  RMDir /r "$INSTDIR"
SectionEnd
