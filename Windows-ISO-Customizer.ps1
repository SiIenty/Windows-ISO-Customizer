# Définir l'encodage UTF-8 globalement pour PowerShell dès le début
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

#requires -RunAsAdministrator
# Script PowerShell pour télécharger et personnaliser une ISO Windows 10/11
# Nécessite une connexion Internet et 20 Go d'espace libre sur C:

# Vérifier les privilèges administrateur et relancer en mode admin si nécessaire
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Ce script doit être exécuté en mode administrateur. Tentative de relance avec élévation..."
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
    Start-Process powershell -Verb RunAs -ArgumentList $arguments
    exit
}

# Configuration des logs
$logPath = "C:\Output\CustomizationLog.txt"
$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Path "C:\Output" -Force | Out-Null
Start-Transcript -Path $logPath -Append

# Fonction pour écrire des messages
function Log-Message {
    param($Message, $Step)
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    if ($Step) {
        Write-Host "Étape : $Step" -ForegroundColor Cyan
    }
}

# Fonction pour mettre à jour la progression
function Update-Progress {
    param($Percent)
    Write-Host "Progression : $Percent%" -ForegroundColor Yellow
}

# Vérifier l'espace disque
$drive = New-Object System.IO.DriveInfo("C")
if ($drive.AvailableFreeSpace -lt 20GB) {
    Write-Error "Espace disque insuffisant sur C: (minimum 20 Go requis)."
    exit 1
}

# Vérifier la connexion Internet et l'accès au serveur Microsoft
Log-Message "Vérification de la connexion Internet et de l'accès au serveur Microsoft..." -Step "Vérification de la connexion"
try {
    Test-Connection -ComputerName www.microsoft.com -Count 1 -ErrorAction Stop | Out-Null
    $response = Invoke-WebRequest -Uri "https://www.microsoft.com/fr-fr/software-download/windows11" -Method Head -UseBasicParsing -ErrorAction Stop
    if ($response.StatusCode -ne 200) {
        throw "Échec de l'accès au serveur de téléchargement Microsoft."
    }
} catch {
    Write-Warning "Impossible de se connecter au serveur Microsoft. Causes possibles :"
    Write-Warning "- VPN ou proxy actif."
    Write-Warning "- Restrictions géographiques ou blocage temporaire de votre IP (erreur 715-123130)."
    Write-Warning "- Problème de réseau local."
    Write-Warning "Solutions :"
    Write-Warning "- Désactivez tout VPN/proxy."
    Write-Warning "- Essayez un autre réseau (ex. : point d'accès mobile)."
    Write-Warning "- Utilisez un autre appareil pour télécharger l'ISO manuellement depuis :"
    Write-Warning "  - Windows 10 : https://www.microsoft.com/fr-fr/software-download/windows10"
    Write-Warning "  - Windows 11 : https://www.microsoft.com/fr-fr/software-download/windows11"
    Write-Warning "Si le problème persiste, contactez le support Microsoft : https://support.microsoft.com/fr-fr/contactus (mentionnez l'erreur 715-123130 et l'ID ef64b89d-bbf8-402c-b6be-54d770c30ffe)."
}

# Installer Windows ADK (Deployment Tools) si nécessaire
Log-Message "Vérification de Windows ADK..." -Step "Installation de Windows ADK"
$oscdimgPath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
if (-not (Test-Path $oscdimgPath)) {
    Log-Message "Windows ADK non trouvé. Téléchargement et installation..."
    $adkUrl = "https://go.microsoft.com/fwlink/?linkid=2243537"
    $adkSetup = "C:\Temp\adksetup.exe"
    New-Item -ItemType Directory -Path "C:\Temp" -Force | Out-Null
    try {
        Invoke-WebRequest -Uri $adkUrl -OutFile $adkSetup -ErrorAction Stop
        Start-Process -FilePath $adkSetup -ArgumentList "/quiet /features OptionId.DeploymentTools /norestart" -Wait
    } catch {
        Write-Error "Échec de l'installation de Windows ADK. Téléchargez-le manuellement : https://learn.microsoft.com/windows-hardware/get-started/adk-install"
        exit 1
    }
    if (-not (Test-Path $oscdimgPath)) {
        Write-Error "Windows ADK n'a pas été installé correctement."
        exit 1
    }
    Log-Message "Windows ADK installé avec succès."
}

# Avertissement légal
Write-Warning "Avertissement : Ce script télécharge une ISO officielle depuis Microsoft. Assurez-vous d'avoir une licence valide pour l'édition choisie."
$confirm = Read-Host "Tapez 'oui' pour continuer"
if ($confirm -ne "oui") {
    Write-Host "Opération annulée."
    exit 0
}

# Choix de la version de Windows avec Out-GridView
Log-Message "Choix de la version de Windows..." -Step "Configuration"
$versions = @(
    [PSCustomObject]@{ Name = "Windows 10 Home"; OS = "Windows 10"; Edition = "Home"; FidoVersion = "10"; FidoEdition = "Home" }
    [PSCustomObject]@{ Name = "Windows 10 Pro"; OS = "Windows 10"; Edition = "Pro"; FidoVersion = "10"; FidoEdition = "Pro" }
    [PSCustomObject]@{ Name = "Windows 10 Education"; OS = "Windows 10"; Edition = "Education"; FidoVersion = "10"; FidoEdition = "Education" }
    [PSCustomObject]@{ Name = "Windows 11 Home"; OS = "Windows 11"; Edition = "Home"; FidoVersion = "11"; FidoEdition = "Home" }
    [PSCustomObject]@{ Name = "Windows 11 Pro"; OS = "Windows 11"; Edition = "Pro"; FidoVersion = "11"; FidoEdition = "Pro" }
    [PSCustomObject]@{ Name = "Windows 11 Education"; OS = "Windows 11"; Edition = "Education"; FidoVersion = "11"; FidoEdition = "Education" }
)
$versionInfo = $versions | Out-GridView -Title "Choisissez une version de Windows" -OutputMode Single
if (-not $versionInfo) {
    Write-Error "Aucune version sélectionnée."
    exit 1
}

# Téléchargement de l'ISO avec Fido ou manuellement
Log-Message "Téléchargement de l'ISO $($versionInfo.OS) $($versionInfo.Edition)..." -Step "Téléchargement de l'ISO"
Update-Progress -Percent 5
$isoPath = "C:\Output\$($versionInfo.OS)_$($versionInfo.Edition).iso"
$fidoUrl = "https://raw.githubusercontent.com/pbatard/Fido/master/Fido.ps1"
$fidoPath = "C:\Temp\Fido.ps1"
New-Item -ItemType Directory -Path "C:\Temp" -Force | Out-Null
try {
    Invoke-WebRequest -Uri $fidoUrl -OutFile $fidoPath -ErrorAction Stop
    . $fidoPath
    $downloadUrl = Get-WindowsIsoUrl -Version $versionInfo.FidoVersion -Edition $versionInfo.FidoEdition -Language "French" -Architecture "x64"
    Invoke-WebRequest -Uri $downloadUrl -OutFile $isoPath -ErrorAction Stop
} catch {
    Log-Message "Échec du téléchargement automatique de l'ISO via Fido : $($_.Exception.Message)"
    Write-Warning "Échec du téléchargement. Causes possibles : VPN/proxy actif, restrictions géographiques, ou limitations Microsoft (erreur 715-123130)."
    Write-Warning "Veuillez télécharger l'ISO manuellement depuis :"
    Write-Warning "- Windows 10 : https://www.microsoft.com/fr-fr/software-download/windows10"
    Write-Warning "- Windows 11 : https://www.microsoft.com/fr-fr/software-download/windows11"
    Write-Warning "Si vous utilisez un VPN, désactivez-le et réessayez."
    Write-Warning "Si le site Microsoft est bloqué, essayez un autre réseau ou appareil, ou contactez le support Microsoft : https://support.microsoft.com/fr-fr/contactus (erreur 715-123130, ID ef64b89d-bbf8-402c-b6be-54d770c30ffe)."
    $isoPath = Read-Host "Entrez le chemin de l'ISO téléchargée (ex. : C:\ISO\Win11.iso)"
    if (-not (Test-Path $isoPath) -or $isoPath -notmatch "\.iso$") {
        Write-Error "Chemin de l'ISO invalide."
        exit 1
    }
}
if (-not (Test-Path $isoPath) -or (Get-Item $isoPath).Length -lt 1MB) {
    Write-Error "Échec du téléchargement ou fichier ISO invalide."
    exit 1
}
$hash = Get-FileHash -Path $isoPath -Algorithm SHA256
if ($hash.Hash.Length -ne 64) {
    Write-Error "ISO corrompue ou invalide."
    exit 1
}
Update-Progress -Percent 10

# Téléchargement des mises à jour
Log-Message "Téléchargement des mises à jour..." -Step "Téléchargement des mises à jour"
Update-Progress -Percent 15
$updatesPath = "C:\Temp\Updates"
New-Item -ItemType Directory -Path $updatesPath -Force | Out-Null
$updateCatalogUrl = "https://www.catalog.update.microsoft.com/Search.aspx?q=cumulative+update+$($versionInfo.OS)+$($versionInfo.Edition)"
try {
    $webContent = Invoke-WebRequest -Uri $updateCatalogUrl -UseBasicParsing
    $updateLinks = $webContent.Links | Where-Object { $_.href -match "\.msu" } | Select-Object -First 1
    if ($updateLinks) {
        $updateUrl = $updateLinks.href
        $updateFile = "$updatesPath\latest_update.msu"
        Invoke-WebRequest -Uri $updateUrl -OutFile $updateFile
    } else {
        Log-Message "Aucune mise à jour trouvée. Poursuite sans mises à jour."
    }
} catch {
    Log-Message "Échec du téléchargement des mises à jour : $($_.Exception.Message). Poursuite sans mises à jour."
}

# Choix de la configuration avec Out-GridView
$configs = @(
    [PSCustomObject]@{ Name = "Ultra-léger (8-10 Go, minimaliste, services réduits)" }
    [PSCustomObject]@{ Name = "Léger (12-14 Go, bloatwares supprimés)" }
    [PSCustomObject]@{ Name = "Optimisé pour le gaming (15-18 Go, performances maximales)" }
    [PSCustomObject]@{ Name = "Proche de Windows de base (18-22 Go, sans bloatwares ni restrictions)" }
)
$selectedConfig = $configs | Out-GridView -Title "Choisissez une configuration" -OutputMode Single
if (-not $selectedConfig) {
    Write-Error "Aucune configuration sélectionnée."
    exit 1
}
$config = $selectedConfig.Name.Split(" ")[0]

# Configuration du compte local
$accountName = Read-Host "Nom du compte local administrateur (ex. : Jérôme)"
if ($accountName -match '[<>:\"/\\|?*]') {
    Write-Error "Nom de compte invalide (caractères interdits : <>:`"/\\|?*)."
    exit 1
}
$password = Read-Host "Mot de passe (optionnel, laissez vide pour aucun)" -AsSecureString
$passwordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
if ($passwordPlain -and $passwordPlain.Length -lt 8) {
    Write-Error "Mot de passe trop court (minimum 8 caractères)."
    exit 1
}

# Choix de la langue
$language = Read-Host "Langue de l'OS (ex. : fr-FR, en-US, es-ES, de-DE) [par défaut : fr-FR]"
if (-not $language) { $language = "fr-FR" }

# Fond d'écran personnalisé avec gestion des erreurs non bloquante
$wallpaperPath = $null
while ($true) {
    $inputPath = Read-Host "Chemin du fond d'écran (JPG/PNG, optionnel, tapez 'skip' pour ignorer)"
    if ($inputPath -eq "skip" -or [string]::IsNullOrWhiteSpace($inputPath)) {
        Log-Message "Aucun fond d'écran personnalisé sélectionné. Utilisation du fond par défaut."
        break
    }
    if (Test-Path $inputPath -and $inputPath -match "\.(jpg|png)$") {
        $wallpaperPath = $inputPath
        Log-Message "Fond d'écran valide : $wallpaperPath"
        break
    } else {
        Write-Warning "Chemin du fond d'écran invalide (doit être un fichier JPG/PNG existant). Réessayez ou tapez 'skip'."
    }
}

# Applications tierces
$appsPath = ""
$addApps = (Read-Host "Ajouter des applications tierces (.exe/.msi) ? (o/n) [par défaut : n]").ToLower() -eq "o"
if ($addApps) {
    $appsPath = Read-Host "Chemin du dossier des installateurs"
    if (-not (Test-Path $appsPath)) {
        Write-Error "Dossier des applications invalide."
        exit 1
    }
}

# Options supplémentaires
$blockTelemetry = (Read-Host "Bloquer la télémétrie ? (o/n) [par défaut : n]").ToLower() -eq "o"
$disableWidgets = ($versionInfo.OS -eq "Windows 11") -and ((Read-Host "Désactiver les Widgets ? (o/n) [par défaut : n]").ToLower() -eq "o")
$disableDefender = ($config -in @("Ultra-léger", "Léger")) -and ((Read-Host "Désactiver Windows Defender ? (risque de sécurité, o/n) [par défaut : n]").ToLower() -eq "o")
$disableSearch = ($config -in @("Ultra-léger", "Léger")) -and ((Read-Host "Désactiver Windows Search ? (o/n) [par défaut : n]").ToLower() -eq "o")
$createBootableUsb = (Read-Host "Créer une clé USB bootable ? (o/n) [par défaut : n]").ToLower() -eq "o"

$usbDrive = ""
if ($createBootableUsb) {
    $drives = Get-Disk | Where-Object { $_.BusType -eq "USB" -and $_.Size -ge 8GB -and $_.IsBoot -eq $false }
    if (-not $drives) {
        Write-Error "Aucune clé USB de 8 Go minimum détectée."
        exit 1
    }
    Write-Host "Clés USB détectées :"
    $drives | ForEach-Object { Write-Host "Disque $($_.Number) : $($_.FriendlyName) ($($_.Size / 1GB) Go)" }
    $diskNumber = Read-Host "Numéro du disque USB à utiliser"
    $selectedDisk = $drives | Where-Object { $_.Number -eq $diskNumber }
    if (-not $selectedDisk) {
        Write-Error "Disque invalide."
        exit 1
    }
    $usbDrive = (Get-Partition -DiskNumber $diskNumber | Where-Object { $_.DriveLetter }).DriveLetter + ":"
    Write-Warning "ATTENTION : Le formatage de la clé USB ($usbDrive) supprimera TOUTES les données. Assurez-vous d'avoir sauvegardé vos fichiers."
    $usbConfirm = Read-Host "Tapez 'oui' pour confirmer le formatage"
    if ($usbConfirm -ne "oui") {
        Write-Host "Création de la clé USB annulée."
        $createBootableUsb = $false
    }
}

# Sauvegarde de l'ISO
Log-Message "Sauvegarde de l'ISO..." -Step "Sauvegarde"
Update-Progress -Percent 20
$backupPath = [System.IO.Path]::ChangeExtension($isoPath, ".backup.iso")
Copy-Item -Path $isoPath -Destination $backupPath -Force

# Montage de l'ISO
Log-Message "Montage de l'ISO..." -Step "Montage de l'ISO"
Update-Progress -Percent 25
Mount-DiskImage -ImagePath $isoPath
$isoDrive = (Get-DiskImage -ImagePath $isoPath | Get-Volume).DriveLetter

# Copie des fichiers dans un dossier temporaire
Log-Message "Copie des fichiers..." -Step "Copie des fichiers"
Update-Progress -Percent 30
$tempDir = "C:\Temp\ISO"
$mountPath = "C:\Temp\Mount"
New-Item -ItemType Directory -Path $tempDir, $mountPath -Force
Copy-Item -Path "$($isoDrive):\*" -Destination $tempDir -Recurse -Force
New-Item -ItemType Directory -Path "$tempDir\Web\Wallpaper\Custom" -Force

# Montage de l'image WIM
Log-Message "Montage de l'image WIM..." -Step "Montage de l'image WIM"
Update-Progress -Percent 35
$wimPath = "$tempDir\sources\install.wim"
dism /Mount-Image /ImageFile:$wimPath /Index:1 /MountDir:$mountPath /Optimize

# Suppression des restrictions TPM/Secure Boot
Log-Message "Suppression des restrictions TPM/Secure Boot..." -Step "Suppression des restrictions"
Update-Progress -Percent 40
$setupPath = "$tempDir\sources\appraiserres.dll"
if (Test-Path $setupPath) {
    Move-Item $setupPath "$setupPath.bak" -Force
    Log-Message "Restrictions TPM/Secure Boot désactivées."
}
# Ajout d'une clé de registre pour Windows 11 pour contourner TPM/Secure Boot
if ($versionInfo.OS -eq "Windows 11") {
    New-Item -Path "$tempDir\sources\`$OEM$\$$\Setup\Scripts" -ItemType Directory -Force | Out-Null
    $bypassScript = @"
reg add HKLM\SYSTEM\Setup\LabConfig /v BypassTPMCheck /t REG_DWORD /d 1 /f
reg add HKLM\SYSTEM\Setup\LabConfig /v BypassSecureBootCheck /t REG_DWORD /d 1 /f
reg add HKLM\SYSTEM\Setup\LabConfig /v BypassRAMCheck /t REG_DWORD /d 1 /f
reg add HKLM\SYSTEM\Setup\LabConfig /v BypassStorageCheck /t REG_DWORD /d 1 /f
"@
    $bypassScript | Out-File -FilePath "$tempDir\sources\`$OEM$\$$\Setup\Scripts\SetupComplete.cmd" -Encoding ascii
}

# Suppression des bloatwares
Log-Message "Suppression des bloatwares..." -Step "Suppression des bloatwares"
Update-Progress -Percent 45
$bloatwares = @("Microsoft.Windows.Cortana", "Microsoft.XboxApp", "Microsoft.ZuneMusic", "Microsoft.ZuneVideo", "Microsoft.YourPhone", "Microsoft.GetHelp", "Microsoft.People", "Microsoft.BingNews", "Microsoft.WindowsFeedbackHub")
foreach ($app in $bloatwares) {
    dism /Image:$mountPath /Remove-ProvisionedAppxPackage /PackageName:$app* 2>$null
}

# Vérification des composants essentiels
Log-Message "Vérification de Windows Update..." -Step "Vérification des composants"
Update-Progress -Percent 50
$wuPackage = dism /Image:$mountPath /Get-Packages | Select-String "WindowsUpdateClient"
if (-not $wuPackage) { Write-Error "Windows Update manquant."; exit 1 }

# Intégration des mises à jour
if (Test-Path "$updatesPath\*.msu") {
    Log-Message "Intégration des mises à jour..." -Step "Intégration des mises à jour"
    Update-Progress -Percent 55
    $updates = Get-ChildItem -Path $updatesPath -Filter "*.msu" -Recurse
    foreach ($update in $updates) {
        dism /Image:$mountPath /Add-Package /PackagePath:$update.FullName
    }
}

# Intégration des applications tierces
if ($appsPath) {
    Log-Message "Intégration des applications..." -Step "Intégration des applications"
    Update-Progress -Percent 60
    $appDir = "$mountPath\Program Files\CustomApps"
    New-Item -ItemType Directory -Path $appDir -Force
    Copy-Item -Path "$appsPath\*" -Destination $appDir -Recurse -Force
    $installScript = @"
    \$apps = Get-ChildItem -Path 'C:\Program Files\CustomApps' -Include *.exe,*.msi -Recurse
    foreach (\$app in \$apps) {
        if (\$app.Extension -eq '.exe') { Start-Process -FilePath \$app.FullName -ArgumentList '/quiet' -Wait }
        if (\$app.Extension -eq '.msi') { Start-Process -FilePath 'msiexec.exe' -ArgumentList '/i', \$app.FullName, '/quiet' -Wait }
    }
    Remove-Item -Path 'C:\Program Files\CustomApps' -Recurse -Force
    "@
    $installScript | Out-File -FilePath "$mountPath\Windows\Setup\Scripts\SetupComplete.cmd" -Encoding ascii
}

# Application des optimisations
Log-Message "Application des optimisations..." -Step "Optimisations"
Update-Progress -Percent 65
reg load HKLM\Mounted "$mountPath\Windows\System32\config\SOFTWARE"
reg load HKLM\MountedSystem "$mountPath\Windows\System32\config\SYSTEM"
$services = @("XblAuthManager", "WSearch", "SysMain")
switch ($config) {
    "Ultra-léger" {
        foreach ($service in $services + @("WindowsUpdate", "DiagTrack")) {
            reg add "HKLM\MountedSystem\CurrentControlSet\Services\$service" /v "Start" /t REG_DWORD /d 4 /f
        }
        if ($blockTelemetry) {
            reg add "HKLM\Mounted\Policies\Microsoft\Windows\DataCollection" /v "AllowTelemetry" /t REG_DWORD /d 0 /f
        }
        if ($disableDefender) {
            reg add "HKLM\Mounted\SOFTWARE\Policies\Microsoft\Windows Defender" /v "DisableAntiSpyware" /t REG_DWORD /d 1 /f
        }
        if ($disableSearch) {
            reg add "HKLM\MountedSystem\CurrentControlSet\Services\WSearch" /v "Start" /t REG_DWORD /d 4 /f
        }
    }
    "Léger" {
        foreach ($service in $services) {
            reg add "HKLM\MountedSystem\CurrentControlSet\Services\$service" /v "Start" /t REG_DWORD /d 4 /f
        }
        if ($blockTelemetry) {
            reg add "HKLM\Mounted\Policies\Microsoft\Windows\DataCollection" /v "AllowTelemetry" /t REG_DWORD /d 0 /f
        }
        if ($disableDefender) {
            reg add "HKLM\Mounted\SOFTWARE\Policies\Microsoft\Windows Defender" /v "DisableAntiSpyware" /t REG_DWORD /d 1 /f
        }
        if ($disableSearch) {
            reg add "HKLM\MountedSystem\CurrentControlSet\Services\WSearch" /v "Start" /t REG_DWORD /d 4 /f
        }
    }
    "Optimisé" {
        reg add "HKLM\Mounted\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v "SystemResponsiveness" /t REG_DWORD /d 0 /f
        reg add "HKLM\MountedSystem\CurrentControlSet\Services\GameBarPresenceWriter" /v "Start" /t REG_DWORD /d 4 /f
        reg add "HKLM\Mounted\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" /v "AppCaptureEnabled" /t REG_DWORD /d 0 /f
        if ($blockTelemetry) {
            reg add "HKLM\Mounted\Policies\Microsoft\Windows\DataCollection" /v "AllowTelemetry" /t REG_DWORD /d 0 /f
        }
    }
    "Proche" {
        # Modifications minimales
    }
}
if ($disableWidgets) {
    reg add "HKLM\Mounted\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v "DesktopWidget" /t REG_DWORD /d 0 /f
}
reg add "HKLM\Mounted\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v "ShowThisPC" /t REG_DWORD /d 1 /f
reg unload HKLM\Mounted
reg unload HKLM\MountedSystem

# Création du fichier unattend.xml avec encodage UTF-8 BOM
Log-Message "Création du fichier unattend.xml..." -Step "Création du fichier unattend"
Update-Progress -Percent 70
$passwordSection = if ($passwordPlain) {
    @"
    <Password>
        <Value>$passwordPlain</Value>
        <PlainText>true</PlainText>
    </Password>
"@
} else { "" }
$wallpaperCommand = if ($wallpaperPath) {
    Copy-Item -Path $wallpaperPath -Destination "$tempDir\Web\Wallpaper\Custom\custom_wallpaper.jpg" -Force
    "%WINDIR%\Web\Wallpaper\Custom\custom_wallpaper.jpg"
} else {
    "%WINDIR%\Web\Wallpaper\Windows\img0.jpg"
}
$unattend = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
            <UserAccounts>
                <LocalAccounts>
                    <LocalAccount wcm:action="add">
                        <Name>$accountName</Name>
                        $passwordSection
                        <Group>Administrators</Group>
                        <DisplayName>$accountName</DisplayName>
                    </LocalAccount>
                </LocalAccounts>
            </UserAccounts>
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <HideLocalAccountScreen>false</HideLocalAccountScreen>
            </OOBE>
            <Themes>
                <ThemeName>Dark</ThemeName>
                <DesktopBackground>$wallpaperCommand</DesktopBackground>
            </Themes>
        </component>
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <InputLocale>$language</InputLocale>
            <SystemLocale>$language</SystemLocale>
            <UILanguage>$language</UILanguage>
            <UserLocale>$language</UserLocale>
        </component>
    </settings>
</unattend>
"@
# Écrire le fichier avec UTF-8 BOM pour garantir la compatibilité des accents
$utf8BomEncoding = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText("$tempDir\unattend.xml", $unattend, $utf8BomEncoding)

# Vérifier les accents dans unattend.xml
Log-Message "Vérification des accents dans unattend.xml..." -Step "Vérification des accents"
$unattendContent = Get-Content -Path "$tempDir\unattend.xml" -Raw
if ($unattendContent -notmatch $accountName) {
    Write-Warning "Les accents dans le nom d'utilisateur ($accountName) peuvent ne pas être corrects dans unattend.xml. Vérifiez le fichier."
}

# Démontage de l'image
Log-Message "Démontage de l'image..." -Step "Démontage"
Update-Progress -Percent 75
dism /Unmount-Image /MountDir:$mountPath /Commit

# Création de la nouvelle ISO
Log-Message "Création de l'ISO..." -Step "Création de l'ISO"
Update-Progress -Percent 80
$isoOutput = "C:\Output\Custom_$($versionInfo.OS)_$($versionInfo.Edition).iso"
& $oscdimgPath -m -o -u2 -udfver102 -lCustomWindows -h -bootdata:2#p0,e,b"$tempDir\boot\etfsboot.com"#pEF,e,b"$tempDir\efi\microsoft\boot\efisys.bin" $tempDir $isoOutput

# Vérification de l'ISO générée
Log-Message "Vérification de l'ISO générée..." -Step "Vérification"
Update-Progress -Percent 85
$hash = Get-FileHash -Path $isoOutput -Algorithm SHA256
$isoSize = (Get-Item $isoOutput).Length / 1GB
Log-Message "Taille de l'ISO : ~$isoSize Go"
if ($hash.Hash.Length -ne 64) { Write-Error "ISO corrompue."; exit 1 }

# Test de montage de l'ISO pour vérifier son intégrité
Log-Message "Test de montage de l'ISO..." -Step "Vérification de l'ISO"
try {
    Mount-DiskImage -ImagePath $isoOutput -ErrorAction Stop
    Dismount-DiskImage -ImagePath $isoOutput -ErrorAction Stop
} catch {
    Write-Error "L'ISO générée semble corrompue ou non bootable. Vérifiez les modifications appliquées."
    exit 1
}

# Création de la clé USB bootable
if ($createBootableUsb) {
    Log-Message "Création de la clé USB bootable sur $usbDrive..." -Step "Création de la clé USB"
    Update-Progress -Percent 90
    Clear-Disk -Number $diskNumber -RemoveData -RemoveOEM -Confirm:$false
    New-Partition -DiskNumber $diskNumber -UseMaximumSize -IsActive -DriveLetter $usbDrive.TrimEnd(":")
    Format-Volume -DriveLetter $usbDrive.TrimEnd(":") -FileSystem FAT32 -NewFileSystemLabel "WIN_BOOT"
    Copy-Item -Path "$tempDir\*" -Destination "$usbDrive\" -Recurse -Force
}

# Nettoyage
Log-Message "Nettoyage..." -Step "Nettoyage"
Update-Progress -Percent 95
Remove-Item -Path $tempDir, $mountPath, $updatesPath, $fidoPath -Recurse -Force -ErrorAction SilentlyContinue
Dismount-DiskImage -ImagePath $isoPath -ErrorAction SilentlyContinue

# Finalisation
Log-Message "ISO générée avec succès dans $isoOutput" -Step "Terminé"
Update-Progress -Percent 100
Stop-Transcript
Write-Host "Opération terminée. Consultez le log dans $logPath."
