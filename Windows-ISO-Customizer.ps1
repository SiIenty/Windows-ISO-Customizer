# CustomWindowsISO_Updated.ps1
# Script PowerShell pour personnaliser une ISO Windows avec message de conseil dans WinPE
# Corrections : mode hors ligne par défaut, encodage UTF-8, plus de langues, police compatible

# Forcer l'encodage UTF-8 globalement
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null # Forcer UTF-8 dans la console

#requires -RunAsAdministrator

# Fonction pour vérifier si l'exécution est en mode administrateur
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Vérification des privilèges administratifs
if (-not (Test-Admin)) {
    Write-Host "Ce script doit être exécuté en tant qu'administrateur." -ForegroundColor Red
    exit
}

# Fonction pour journaliser les messages
function Log-Message {
    param (
        [string]$Message,
        [string]$Step
    )
    chcp 65001 | Out-Null # Assurer l'encodage UTF-8 pour chaque log
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Step : $Message"
    Write-Host $logEntry
    $logEntry | Out-File -FilePath "C:\Output\CustomizationLog.txt" -Append -Encoding utf8
}

# Fonction pour mettre à jour la barre de progression
function Update-Progress {
    param (
        [int]$Percent
    )
    $progressBar.Value = $Percent
    $form.Refresh()
}

# Fonction pour télécharger avec gestion des erreurs
function Invoke-WebRequestWithRetry {
    param (
        [string]$Uri,
        [string]$OutFile,
        [int]$Retries = 3,
        [int]$Delay = 5
    )
    for ($i = 1; $i -le $Retries; $i++) {
        try {
            $response = Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
            return $response
        }
        catch {
            Log-Message "Tentative $i/$Retries échouée : $_" -Step "Téléchargement"
            if ($i -lt $Retries) { Start-Sleep -Seconds $Delay }
            else { throw $_ }
        }
    }
}

# Création du dossier de sortie
$null = New-Item -ItemType Directory -Path "C:\Output" -Force

# Configurations disponibles
$configs = @(
    [PSCustomObject]@{ Name = "Ultra-léger (8-10 Go, minimaliste, services réduits)"; Size = 25 }
    [PSCustomObject]@{ Name = "Léger (12-14 Go, bloatwares supprimés)"; Size = 29 }
    [PSCustomObject]@{ Name = "Optimisé pour le gaming (15-18 Go, performances maximales)"; Size = 33 }
    [PSCustomObject]@{ Name = "Proche de Windows de base (18-22 Go, sans bloatwares ni restrictions)"; Size = 37 }
)

# Création de l'interface graphique
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "Personnalisation ISO Windows"
$form.Size = New-Object System.Drawing.Size(800, 600)
$form.StartPosition = "CenterScreen"
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10) # Police compatible UTF-8

# Éléments de l'interface
$versionLabel = New-Object System.Windows.Forms.Label
$versionLabel.Location = New-Object System.Drawing.Point(10, 20)
$versionLabel.Size = New-Object System.Drawing.Size(150, 20)
$versionLabel.Text = "Version de Windows :"
$versionLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($versionLabel)

$versionComboBox = New-Object System.Windows.Forms.ComboBox
$versionComboBox.Location = New-Object System.Drawing.Point(160, 20)
$versionComboBox.Size = New-Object System.Drawing.Size(200, 20)
$versionComboBox.Items.AddRange(@("Windows 10", "Windows 11"))
$versionComboBox.SelectedIndex = 0
$versionComboBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($versionComboBox)

$architectureLabel = New-Object System.Windows.Forms.Label
$architectureLabel.Location = New-Object System.Drawing.Point(10, 50)
$architectureLabel.Size = New-Object System.Drawing.Size(150, 20)
$architectureLabel.Text = "Architecture :"
$architectureLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($architectureLabel)

$architectureComboBox = New-Object System.Windows.Forms.ComboBox
$architectureComboBox.Location = New-Object System.Drawing.Point(160, 50)
$architectureComboBox.Size = New-Object System.Drawing.Size(200, 20)
$architectureComboBox.Items.AddRange(@("x64", "ARM64"))
$architectureComboBox.SelectedIndex = 0
$architectureComboBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($architectureComboBox)

$releaseLabel = New-Object System.Windows.Forms.Label
$releaseLabel.Location = New-Object System.Drawing.Point(10, 80)
$releaseLabel.Size = New-Object System.Drawing.Size(150, 20)
$releaseLabel.Text = "Release :"
$releaseLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($releaseLabel)

$releaseComboBox = New-Object System.Windows.Forms.ComboBox
$releaseComboBox.Location = New-Object System.Drawing.Point(160, 80)
$releaseComboBox.Size = New-Object System.Drawing.Size(200, 20)
$releaseComboBox.Items.AddRange(@("Latest", "21H2", "22H2"))
$releaseComboBox.SelectedIndex = 0
$releaseComboBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($releaseComboBox)

$languageLabel = New-Object System.Windows.Forms.Label
$languageLabel.Location = New-Object System.Drawing.Point(10, 110)
$languageLabel.Size = New-Object System.Drawing.Size(150, 20)
$languageLabel.Text = "Langue :"
$languageLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($languageLabel)

$languageComboBox = New-Object System.Windows.Forms.ComboBox
$languageComboBox.Location = New-Object System.Drawing.Point(160, 110)
$languageComboBox.Size = New-Object System.Drawing.Size(200, 20)
$languageComboBox.Items.AddRange(@(
    "Français (fr-FR)", "Anglais (en-US)", "Espagnol (es-ES)", 
    "Allemand (de-DE)", "Italien (it-IT)", "Japonais (ja-JP)", 
    "Chinois simplifié (zh-CN)", "Russe (ru-RU)"
))
$languageComboBox.SelectedIndex = 0
$languageComboBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($languageComboBox)

$configLabel = New-Object System.Windows.Forms.Label
$configLabel.Location = New-Object System.Drawing.Point(10, 140)
$configLabel.Size = New-Object System.Drawing.Size(150, 20)
$configLabel.Text = "Configuration :"
$configLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($configLabel)

$configComboBox = New-Object System.Windows.Forms.ComboBox
$configComboBox.Location = New-Object System.Drawing.Point(160, 140)
$configComboBox.Size = New-Object System.Drawing.Size(200, 20)
$configComboBox.Items.AddRange($configs.Name)
$configComboBox.SelectedIndex = 0
$configComboBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($configComboBox)

$accountLabel = New-Object System.Windows.Forms.Label
$accountLabel.Location = New-Object System.Drawing.Point(10, 170)
$accountLabel.Size = New-Object System.Drawing.Size(150, 20)
$accountLabel.Text = "Compte local :"
$accountLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($accountLabel)

$accountTextBox = New-Object System.Windows.Forms.TextBox
$accountTextBox.Location = New-Object System.Drawing.Point(160, 170)
$accountTextBox.Size = New-Object System.Drawing.Size(200, 20)
$accountTextBox.Text = "Utilisateur"
$accountTextBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($accountTextBox)

$wallpaperLabel = New-Object System.Windows.Forms.Label
$wallpaperLabel.Location = New-Object System.Drawing.Point(10, 200)
$wallpaperLabel.Size = New-Object System.Drawing.Size(150, 20)
$wallpaperLabel.Text = "Fond d'écran :"
$wallpaperLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($wallpaperLabel)

$wallpaperTextBox = New-Object System.Windows.Forms.TextBox
$wallpaperTextBox.Location = New-Object System.Drawing.Point(160, 200)
$wallpaperTextBox.Size = New-Object System.Drawing.Size(150, 20)
$wallpaperTextBox.ReadOnly = $true
$wallpaperTextBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($wallpaperTextBox)

$wallpaperButton = New-Object System.Windows.Forms.Button
$wallpaperButton.Location = New-Object System.Drawing.Point(320, 200)
$wallpaperButton.Size = New-Object System.Drawing.Size(40, 20)
$wallpaperButton.Text = "..."
$wallpaperButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$wallpaperButton.Add_Click({
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Filter = "Images (*.jpg;*.png)|*.jpg;*.png"
    if ($openFileDialog.ShowDialog() -eq "OK") {
        $wallpaperTextBox.Text = $openFileDialog.FileName
    }
})
$form.Controls.Add($wallpaperButton)

$appsLabel = New-Object System.Windows.Forms.Label
$appsLabel.Location = New-Object System.Drawing.Point(10, 230)
$appsLabel.Size = New-Object System.Drawing.Size(150, 20)
$appsLabel.Text = "Applications :"
$appsLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($appsLabel)

$appsTextBox = New-Object System.Windows.Forms.TextBox
$appsTextBox.Location = New-Object System.Drawing.Point(160, 230)
$appsTextBox.Size = New-Object System.Drawing.Size(150, 20)
$appsTextBox.ReadOnly = $true
$appsTextBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($appsTextBox)

$appsButton = New-Object System.Windows.Forms.Button
$appsButton.Location = New-Object System.Drawing.Point(320, 230)
$appsButton.Size = New-Object System.Drawing.Size(40, 20)
$appsButton.Text = "..."
$appsButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$appsButton.Add_Click({
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Filter = "Installateurs (*.exe;*.msi)|*.exe;*.msi"
    $openFileDialog.Multiselect = $true
    if ($openFileDialog.ShowDialog() -eq "OK") {
        $appsTextBox.Text = ($openFileDialog.FileNames -join ";")
    }
})
$form.Controls.Add($appsButton)

$driversLabel = New-Object System.Windows.Forms.Label
$driversLabel.Location = New-Object System.Drawing.Point(10, 260)
$driversLabel.Size = New-Object System.Drawing.Size(150, 20)
$driversLabel.Text = "Pilotes :"
$driversLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($driversLabel)

$driversTextBox = New-Object System.Windows.Forms.TextBox
$driversTextBox.Location = New-Object System.Drawing.Point(160, 260)
$driversTextBox.Size = New-Object System.Drawing.Size(150, 20)
$driversTextBox.ReadOnly = $true
$driversTextBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($driversTextBox)

$driversButton = New-Object System.Windows.Forms.Button
$driversButton.Location = New-Object System.Drawing.Point(320, 260)
$driversButton.Size = New-Object System.Drawing.Size(40, 20)
$driversButton.Text = "..."
$driversButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$driversButton.Add_Click({
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Filter = "Pilotes (*.inf)|*.inf"
    $openFileDialog.Multiselect = $true
    if ($openFileDialog.ShowDialog() -eq "OK") {
        $driversTextBox.Text = ($openFileDialog.FileNames -join ";")
    }
})
$form.Controls.Add($driversButton)

$offlineCheckBox = New-Object System.Windows.Forms.CheckBox
$offlineCheckBox.Location = New-Object System.Drawing.Point(10, 290)
$offlineCheckBox.Size = New-Object System.Drawing.Size(150, 20)
$offlineCheckBox.Text = "Mode hors ligne"
$offlineCheckBox.Checked = $true # Mode hors ligne par défaut
$offlineCheckBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$offlineCheckBox.Add_CheckedChanged({
    if ($offlineCheckBox.Checked) {
        $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openFileDialog.Filter = "Fichiers ISO (*.iso)|*.iso"
        if ($openFileDialog.ShowDialog() -eq "OK") {
            $script:isoPath = $openFileDialog.FileName
        }
        else {
            $offlineCheckBox.Checked = $false
        }
    }
})
$form.Controls.Add($offlineCheckBox)

$usbCheckBox = New-Object System.Windows.Forms.CheckBox
$usbCheckBox.Location = New-Object System.Drawing.Point(160, 290)
$usbCheckBox.Size = New-Object System.Drawing.Size(150, 20)
$usbCheckBox.Text = "Créer clé USB"
$usbCheckBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($usbCheckBox)

$advancedLabel = New-Object System.Windows.Forms.Label
$advancedLabel.Location = New-Object System.Drawing.Point(10, 320)
$advancedLabel.Size = New-Object System.Drawing.Size(150, 20)
$advancedLabel.Text = "Options avancées :"
$advancedLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($advancedLabel)

$telemetryCheckBox = New-Object System.Windows.Forms.CheckBox
$telemetryCheckBox.Location = New-Object System.Drawing.Point(160, 320)
$telemetryCheckBox.Size = New-Object System.Drawing.Size(200, 20)
$telemetryCheckBox.Text = "Bloquer la télémétrie"
$telemetryCheckBox.Checked = $true
$telemetryCheckBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($telemetryCheckBox)

$defenderCheckBox = New-Object System.Windows.Forms.CheckBox
$defenderCheckBox.Location = New-Object System.Drawing.Point(160, 350)
$defenderCheckBox.Size = New-Object System.Drawing.Size(200, 20)
$defenderCheckBox.Text = "Désactiver Defender"
$defenderCheckBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($defenderCheckBox)

$edgeCheckBox = New-Object System.Windows.Forms.CheckBox
$edgeCheckBox.Location = New-Object System.Drawing.Point(160, 380)
$edgeCheckBox.Size = New-Object System.Drawing.Size(200, 20)
$edgeCheckBox.Text = "Supprimer Edge"
$edgeCheckBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($edgeCheckBox)

$onedriveCheckBox = New-Object System.Windows.Forms.CheckBox
$onedriveCheckBox.Location = New-Object System.Drawing.Point(160, 410)
$onedriveCheckBox.Size = New-Object System.Drawing.Size(200, 20)
$onedriveCheckBox.Text = "Supprimer OneDrive"
$onedriveCheckBox.Checked = $true
$onedriveCheckBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($onedriveCheckBox)

$profileLabel = New-Object System.Windows.Forms.Label
$profileLabel.Location = New-Object System.Drawing.Point(10, 440)
$profileLabel.Size = New-Object System.Drawing.Size(150, 20)
$profileLabel.Text = "Profil :"
$profileLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($profileLabel)

$profileComboBox = New-Object System.Windows.Forms.ComboBox
$profileComboBox.Location = New-Object System.Drawing.Point(160, 440)
$profileComboBox.Size = New-Object System.Drawing.Size(200, 20)
$profileComboBox.Items.AddRange(@("Nouveau", "Charger existant"))
$profileComboBox.SelectedIndex = 0
$profileComboBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($profileComboBox)

$profileButton = New-Object System.Windows.Forms.Button
$profileButton.Location = New-Object System.Drawing.Point(370, 440)
$profileButton.Size = New-Object System.Drawing.Size(100, 20)
$profileButton.Text = "Enregistrer"
$profileButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$profileButton.Add_Click({
    $profile = @{
        Version = $versionComboBox.SelectedItem
        Architecture = $architectureComboBox.SelectedItem
        Release = $releaseComboBox.SelectedItem
        Language = $languageComboBox.SelectedItem
        Configuration = $configComboBox.SelectedItem
        Account = $accountTextBox.Text
        Wallpaper = $wallpaperTextBox.Text
        Apps = $appsTextBox.Text
        Drivers = $driversTextBox.Text
        Offline = $offlineCheckBox.Checked
        USB = $usbCheckBox.Checked
        Telemetry = $telemetryCheckBox.Checked
        Defender = $defenderCheckBox.Checked
        Edge = $edgeCheckBox.Checked
        OneDrive = $onedriveCheckBox.Checked
    }
    $profile | ConvertTo-Json | Out-File -FilePath "C:\Output\Profile.json" -Encoding utf8
    [System.Windows.Forms.MessageBox]::Show("Profil enregistré avec succès !", "Succès", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})
$form.Controls.Add($profileButton)

$okButton = New-Object System.Windows.Forms.Button
$okButton.Location = New-Object System.Drawing.Point(10, 470)
$okButton.Size = New-Object System.Drawing.Size(75, 23)
$okButton.Text = "OK"
$okButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$okButton.Add_Click({
    $script:version = $versionComboBox.SelectedItem
    $script:architecture = $architectureComboBox.SelectedItem
    $script:release = $releaseComboBox.SelectedItem
    $script:language = $languageComboBox.SelectedItem
    $script:config = $configComboBox.SelectedItem
    $script:account = $accountTextBox.Text
    $script:wallpaper = $wallpaperTextBox.Text
    $script:apps = $appsTextBox.Text
    $script:drivers = $driversTextBox.Text
    $script:offline = $offlineCheckBox.Checked
    $script:usb = $usbCheckBox.Checked
    $script:telemetry = $telemetryCheckBox.Checked
    $script:defender = $defenderCheckBox.Checked
    $script:edge = $edgeCheckBox.Checked
    $script:onedrive = $onedriveCheckBox.Checked
    $form.Close()
})
$form.Controls.Add($okButton)

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Location = New-Object System.Drawing.Point(90, 470)
$cancelButton.Size = New-Object System.Drawing.Size(75, 23)
$cancelButton.Text = "Annuler"
$cancelButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$cancelButton.Add_Click({ 
    Log-Message "Script annulé par l'utilisateur." -Step "Annulation"
    $form.Close(); exit 
})
$form.Controls.Add($cancelButton)

$helpButton = New-Object System.Windows.Forms.Button
$helpButton.Location = New-Object System.Drawing.Point(170, 470)
$helpButton.Size = New-Object System.Drawing.Size(75, 23)
$helpButton.Text = "Aide"
$helpButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$helpButton.Add_Click({
    $helpFile = "C:\Output\Help.html"
    $helpContent = @"
    <html>
    <head><title>Aide - Personnalisation ISO Windows</title></head>
    <body>
    <h1>Guide de personnalisation de l'ISO Windows</h1>
    <p>Ce script permet de créer une ISO Windows 10/11 personnalisée.</p>
    <h2>Prérequis</h2>
    <ul>
        <li>20 Go d'espace libre sur C:</li>
        <li>Connexion Internet (sauf mode hors ligne)</li>
        <li>Windows ADK avec WinPE Add-ons (installé automatiquement)</li>
        <li>8 Go de RAM recommandé pour montage en mémoire (nécessite ImDisk : https://sourceforge.net/projects/imdisk-toolkit/)</li>
        <li>Une ISO Windows 10/11 pour le mode hors ligne</li>
    </ul>
    <h2>Options</h2>
    <ul>
        <li><b>Mode hors ligne</b> : Sélectionnez une ISO existante (recommandé).</li>
        <li><b>Version/Release</b> : Choisissez Windows 10/11 et la version (ex. : 22H2).</li>
        <li><b>Langue</b> : Sélectionnez la langue de l'OS (ex. : Français, Anglais, Allemand).</li>
        <li><b>Configuration</b> : Choisissez entre Ultra-léger, Léger, Gaming, ou Standard.</li>
        <li><b>Compte local</b> : Définissez un compte administrateur.</li>
        <li><b>Fond d'écran</b> : Ajoutez une image personnalisée (JPG/PNG).</li>
        <li><b>Applications/Pilotes</b> : Intégrez des logiciels ou pilotes.</li>
        <li><b>Options avancées</b> : Bloquez la télémétrie, désactivez Defender, etc.</li>
        <li><b>Clé USB</b> : Créez une clé bootable.</li>
        <li><b>Profils</b> : Enregistrez/chargez des configurations.</li>
        <li><b>Message de conseil</b> : Un message s'affichera au début de l'installation, avant l'écran de partitionnement, pour recommander l'utilisation de deux disques (un pour l'OS, un pour les données) ou de partitionner un seul disque.</li>
    </ul>
    <p>Pour plus d'aide, consultez le journal dans C:\Output\CustomizationLog.txt.</p>
    </body>
    </html>
"@
    $helpContent | Out-File -FilePath $helpFile -Encoding utf8
    Start-Process $helpFile
})
$form.Controls.Add($helpButton)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10, 500)
$progressBar.Size = New-Object System.Drawing.Size(760, 23)
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$form.Controls.Add($progressBar)

# Affichage de la fenêtre
$form.ShowDialog()

# Variables globales
$tempDir = if ($ramDisk) { "Z:\Temp" } else { "C:\Temp" }
$mountPath = if ($ramDisk) { "Z:\Mount" } else { "C:\Mount" }
$isoPath = if ($offline) { $isoPath } else { "C:\Temp\WinISO.iso" }
$keepTempFiles = $false
$languageName = switch ($language) {
    "Français (fr-FR)" { "French" }
    "Anglais (en-US)" { "English" }
    "Espagnol (es-ES)" { "Spanish" }
    "Allemand (de-DE)" { "German" }
    "Italien (it-IT)" { "Italian" }
    "Japonais (ja-JP)" { "Japanese" }
    "Chinois simplifié (zh-CN)" { "Chinese" }
    "Russe (ru-RU)" { "Russian" }
    default { "English" }
}
$languageCode = $language -replace ".*\((.*)\)", '$1'
$edition = if ($version -eq "Windows 10") { "Professional" } else { "Pro" }
$oscdimgPath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
$configSize = ($configs | Where-Object { $_.Name -eq $config }).Size

# Vérification de l'espace disque
$freeSpace = (Get-PSDrive -Name C).Free / 1GB
if ($freeSpace -lt 20) {
    [System.Windows.Forms.MessageBox]::Show("Espace disque insuffisant sur C:. 20 Go requis.", "Erreur", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit
}

# Installation de Windows ADK si nécessaire
if (-not (Test-Path $oscdimgPath)) {
    Log-Message "Installation de Windows ADK..." -Step "Installation ADK"
    $adkUrl = "https://go.microsoft.com/fwlink/?linkid=2026036"
    $adkInstaller = "C:\Temp\adksetup.exe"
    Invoke-WebRequestWithRetry -Uri $adkUrl -OutFile $adkInstaller
    Start-Process -FilePath $adkInstaller -ArgumentList "/quiet /features OptionId.DeploymentTools OptionId.WindowsPreinstallationEnvironment /norestart" -Wait
    Log-Message "Windows ADK installé." -Step "Installation ADK"
}

# Installation de ImDisk si nécessaire
if ($ramDisk -and -not (Get-Command imdisk -ErrorAction SilentlyContinue)) {
    Log-Message "Installation de ImDisk..." -Step "Installation ImDisk"
    $imdiskUrl = "https://sourceforge.net/projects/imdisk-toolkit/files/latest/download"
    $imdiskInstaller = "C:\Temp\imdisk.exe"
    Invoke-WebRequestWithRetry -Uri $imdiskUrl -OutFile $imdiskInstaller
    Start-Process -FilePath $imdiskInstaller -ArgumentList "/silent" -Wait
    Log-Message "ImDisk installé." -Step "Installation ImDisk"
}

# Téléchargement de l'ISO si non hors ligne
if (-not $offline) {
    Log-Message "Téléchargement de l'ISO non disponible. Veuillez utiliser le mode hors ligne et sélectionner une ISO." -Step "Téléchargement ISO"
    [System.Windows.Forms.MessageBox]::Show("Le téléchargement automatique de l'ISO n'est pas disponible. Veuillez cocher 'Mode hors ligne' et sélectionner une ISO Windows 10/11 téléchargée manuellement.", "Erreur", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit
}

# Montage de l'ISO
Log-Message "Montage de l'ISO..." -Step "Montage de l'ISO"
Update-Progress -Percent 30
Mount-DiskImage -ImagePath $isoPath
$isoDrive = (Get-DiskImage -ImagePath $isoPath | Get-Volume).DriveLetter

# Copie des fichiers dans un dossier temporaire
Log-Message "Copie des fichiers..." -Step "Copie des fichiers"
Update-Progress -Percent 35
New-Item -ItemType Directory -Path $tempDir, $mountPath -Force
Copy-Item -Path "$($isoDrive):\*" -Destination $tempDir -Recurse -Force
New-Item -ItemType Directory -Path "$tempDir\Web\Wallpaper\Custom" -Force

# Personnalisation de boot.wim pour WinPE
Log-Message "Montage de boot.wim pour ajouter le script de conseil..." -Step "Personnalisation de WinPE"
$bootWimPath = "$tempDir\sources\boot.wim"
$bootMountPath = if ($ramDisk) { "Z:\Temp\BootMount" } else { "C:\Temp\BootMount" }
New-Item -ItemType Directory -Path $bootMountPath -Force
dism /Mount-Image /ImageFile:$bootWimPath /Index:2 /MountDir:$bootMountPath /Optimize

# Ajout des composants PowerShell à WinPE
Log-Message "Ajout de PowerShell à WinPE..." -Step "Personnalisation de WinPE"
$winpePath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs"
dism /Image:$bootMountPath /Add-Package /PackagePath:"$winpePath\WinPE-WMI.cab"
dism /Image:$bootMountPath /Add-Package /PackagePath:"$winpePath\en-us\WinPE-WMI_en-us.cab"
dism /Image:$bootMountPath /Add-Package /PackagePath:"$winpePath\WinPE-NetFX.cab"
dism /Image:$bootMountPath /Add-Package /PackagePath:"$winpePath\en-us\WinPE-NetFX_en-us.cab"
dism /Image:$bootMountPath /Add-Package /PackagePath:"$winpePath\WinPE-PowerShell.cab"
dism /Image:$bootMountPath /Add-Package /PackagePath:"$winpePath\en-us\WinPE-PowerShell_en-us.cab"
dism /Image:$bootMountPath /Add-Package /PackagePath:"$winpePath\WinPE-DismCmdlets.cab"
dism /Image:$bootMountPath /Add-Package /PackagePath:"$winpePath\en-us\WinPE-DismCmdlets_en-us.cab"

# Ajout de System.Windows.Forms pour les boîtes de dialogue
Log-Message "Ajout de System.Windows.Forms à WinPE..." -Step "Personnalisation de WinPE"
$netFxDir = "$bootMountPath\Windows\System32"
Copy-Item -Path "$env:windir\System32\WindowsPowerShell\v1.0\Modules\Microsoft.PowerShell.Utility\System.Windows.Forms.dll" -Destination $netFxDir -Force

# Création du script de conseil pour WinPE
Log-Message "Création du script de conseil pour WinPE..." -Step "Conseil disque"
$diskAdviceScript = @"
Add-Type -AssemblyName System.Windows.Forms
# Lire la configuration et la taille depuis config.txt
\$configFile = 'X:\Windows\System32\config.txt'
if (Test-Path \$configFile) {
    \$configData = Get-Content \$configFile
    \$config = \$configData | Where-Object { \$_ -match 'Config=' } | ForEach-Object { \$_ -replace 'Config=', '' }
    \$configSize = \$configData | Where-Object { \$_ -match 'ConfigSize=' } | ForEach-Object { \$_ -replace 'ConfigSize=', '' }
} else {
    \$config = 'Inconnue'
    \$configSize = '30' # Valeur par défaut
}
[System.Windows.Forms.MessageBox]::Show(
    "Conseil pour la gestion des disques :\n\n" +
    "Pour une performance optimale, il est conseillé d'utiliser deux disques :\n" +
    "- Un disque dédié pour le système d'exploitation (OS).\n" +
    "- Un disque séparé pour vos données (documents, jeux, etc.).\n\n" +
    "Si vous n'avez qu'un seul disque, il est recommandé de le partitionner en deux :\n" +
    "- Une partition pour l'OS d'une taille d'au moins \$configSize Go (taille recommandée pour la configuration '\$config' + 15 Go de marge).\n" +
    "- Une partition pour les données avec le reste de l'espace disponible.\n\n" +
    "Vous pouvez créer ou modifier les partitions dans l'écran suivant.",
    "Conseil - Gestion des disques",
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Information
)
"@
$diskAdviceScript | Out-File -FilePath "$bootMountPath\Windows\System32\DiskAdvice.ps1" -Encoding utf8

# Création du fichier config.txt avec $config et $configSize
$configText = @"
Config=$config
ConfigSize=$configSize
"@
$configText | Out-File -FilePath "$bootMountPath\Windows\System32\config.txt" -Encoding ascii

# Modification de startnet.cmd pour exécuter le script de conseil
Log-Message "Modification de startnet.cmd..." -Step "Personnalisation de WinPE"
$startnetPath = "$bootMountPath\Windows\System32\startnet.cmd"
$startnetContent = @"
@echo off
powershell -ExecutionPolicy Bypass -File X:\Windows\System32\DiskAdvice.ps1
wpeinit
"@
$startnetContent | Out-File -FilePath $startnetPath -Encoding ascii

# Démontage de boot.wim
Log-Message "Démontage de boot.wim..." -Step "Personnalisation de WinPE"
dism /Unmount-Image /MountDir:$bootMountPath /Commit
Remove-Item -Path $bootMountPath -Recurse -Force -ErrorAction SilentlyContinue

# Montage de l'image Windows
Log-Message "Montage de l'image Windows..." -Step "Montage de l'image"
Update-Progress -Percent 40
$imagePath = "$tempDir\sources\install.wim"
dism /Mount-Image /ImageFile:$imagePath /Index:1 /MountDir:$mountPath /Optimize

# Application des optimisations
Log-Message "Application des optimisations..." -Step "Optimisations"
Update-Progress -Percent 50

if ($telemetry) {
    Log-Message "Blocage de la télémétrie..." -Step "Optimisations"
    # Exemple : désactivation des services de télémétrie
    dism /Image:$mountPath /Disable-Feature /FeatureName:Windows-Telemetry /Remove
}

if ($defender) {
    Log-Message "Désactivation de Defender..." -Step "Optimisations"
    dism /Image:$mountPath /Disable-Feature /FeatureName:Windows-Defender-Default-Definitions /Remove
}

if ($edge) {
    Log-Message "Suppression de Edge..." -Step "Optimisations"
    dism /Image:$mountPath /Remove-Package /PackageName:Microsoft-Windows-Internet-Browser-Package
}

if ($onedrive) {
    Log-Message "Suppression de OneDrive..." -Step "Optimisations"
    dism /Image:$mountPath /Remove-Package /PackageName:Microsoft-Windows-OneDrive-Package
}

# Configuration du compte local
Log-Message "Configuration du compte local..." -Step "Compte local"
$autologon = @"
[AutoLogon]
Enabled = true
Username = $account
Password = ""
"@
$autologon | Out-File -FilePath "$mountPath\Windows\System32\oobe\info\autologon.inf" -Encoding ascii

# Ajout du fond d'écran
if ($wallpaper) {
    Log-Message "Ajout du fond d'écran..." -Step "Fond d'écran"
    Copy-Item -Path $wallpaper -Destination "$tempDir\Web\Wallpaper\Custom\wallpaper.jpg" -Force
    $wallpaperScript = @"
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP" /v LockScreenImagePath /t REG_SZ /d "C:\Windows\Web\Wallpaper\Custom\wallpaper.jpg" /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP" /v DesktopImagePath /t REG_SZ /d "C:\Windows\Web\Wallpaper\Custom\wallpaper.jpg" /f
"@
    $wallpaperScript | Out-File -FilePath "$mountPath\Windows\Setup\Scripts\SetWallpaper.cmd" -Encoding ascii
}

# Intégration des applications
if ($apps) {
    Log-Message "Intégration des applications..." -Step "Applications"
    $appDir = "$mountPath\Program Files\CustomApps"
    New-Item -ItemType Directory -Path $appDir -Force
    $appFiles = $apps -split ";"
    foreach ($app in $appFiles) {
        if (Test-Path $app) {
            Copy-Item -Path $app -Destination $appDir -Force
        }
    }
}

# Intégration des pilotes
if ($drivers) {
    Log-Message "Intégration des pilotes..." -Step "Pilotes"
    $driverFiles = $drivers -split ";"
    foreach ($driver in $driverFiles) {
        if (Test-Path $driver) {
            dism /Image:$mountPath /Add-Driver /Driver:$driver
        }
    }
}

# Création de SetupComplete.cmd
Log-Message "Création de SetupComplete.cmd..." -Step "Configuration"
New-Item -Path "$tempDir\sources\`$OEM$\$$\Setup\Scripts" -ItemType Directory -Force | Out-Null
$setupComplete = @"
@echo off
if exist "%WINDIR%\Setup\Scripts\BypassTPM.cmd" (
    call "%WINDIR%\Setup\Scripts\BypassTPM.cmd"
)
if exist "%WINDIR%\Program Files\CustomApps" (
    powershell -ExecutionPolicy Bypass -Command "\$apps = Get-ChildItem -Path 'C:\Program Files\CustomApps' -Include *.exe,*.msi -Recurse; foreach (\$app in \$apps) { if (\$app.Extension -eq '.exe') { Start-Process -FilePath \$app.FullName -ArgumentList '/quiet' -Wait }; if (\$app.Extension -eq '.msi') { Start-Process -FilePath 'msiexec.exe' -ArgumentList '/i', \$app.FullName, '/quiet' -Wait } }; Remove-Item -Path 'C:\Program Files\CustomApps' -Recurse -Force"
)
rd /s /q "%WINDIR%\Setup\Scripts"
"@
$setupComplete | Out-File -FilePath "$tempDir\sources\`$OEM$\$$\Setup\Scripts\SetupComplete.cmd" -Encoding ascii

# Création du fichier unattend.xml
Log-Message "Création de unattend.xml..." -Step "Configuration"
$unattend = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-International-Core" processorArchitecture="$($architecture -replace 'x64','amd64')" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>$languageCode</InputLocale>
            <SystemLocale>$languageCode</SystemLocale>
            <UILanguage>$languageCode</UILanguage>
            <UserLocale>$languageCode</UserLocale>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="$($architecture -replace 'x64','amd64')" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <ProtectYourPC>3</ProtectYourPC>
            </OOBE>
            <UserAccounts>
                <LocalAccounts>
                    <LocalAccount wcm:action="add">
                        <Name>$account</Name>
                        <Group>Administrators</Group>
                        <Password>
                            <Value></Value>
                            <PlainText>true</PlainText>
                        </Password>
                    </LocalAccount>
                </LocalAccounts>
            </UserAccounts>
        </component>
    </settings>
</unattend>
"@
$unattend | Out-File -FilePath "$tempDir\sources\`$OEM$\$$\unattend.xml" -Encoding utf8

# Démontage de l'image
Log-Message "Démontage de l'image..." -Step "Démontage"
Update-Progress -Percent 70
dism /Unmount-Image /MountDir:$mountPath /Commit

# Création de l'ISO
Log-Message "Création de l'ISO..." -Step "Création ISO"
Update-Progress -Percent 80
$isoOutput = "C:\Output\Custom_Windows_$($version -replace 'Windows ', '')_$edition.iso"
$oscdimgArgs = "-m -o -u2 -udfver102 -bootdata:2#p0,e,b$tempDir\boot\etfsboot.com#pEF,e,b$tempDir\efi\microsoft\boot\efisys.bin -lCUSTOM_WIN $tempDir $isoOutput"
Start-Process -FilePath $oscdimgPath -ArgumentList $oscdimgArgs -Wait -NoNewWindow
Log-Message "ISO générée avec succès dans $isoOutput" -Step "Création ISO"

# Création de la clé USB si sélectionnée
if ($usb) {
    Log-Message "Création de la clé USB..." -Step "Clé USB"
    Update-Progress -Percent 90
    $usbDrive = (Get-Disk | Where-Object { $_.BusType -eq "USB" } | Get-Partition | Get-Volume).DriveLetter
    if ($usbDrive) {
        Format-Volume -DriveLetter $usbDrive -FileSystem FAT32 -Force -Confirm:$false
        Mount-DiskImage -ImagePath $isoOutput
        $isoDrive = (Get-DiskImage -ImagePath $isoOutput | Get-Volume).DriveLetter
        Copy-Item -Path "$($isoDrive):\*" -Destination "$($usbDrive):\" -Recurse -Force
        Dismount-DiskImage -ImagePath $isoOutput
        Log-Message "Clé USB créée avec succès." -Step "Clé USB"
    }
    else {
        Log-Message "Aucune clé USB détectée." -Step "Clé USB"
    }
}

# Nettoyage
Log-Message "Nettoyage..." -Step "Nettoyage"
Update-Progress -Percent 95
Dismount-DiskImage -ImagePath $isoPath
if (-not $keepTempFiles) {
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $mountPath -Recurse -Force -ErrorAction SilentlyContinue
}

Log-Message "Personnalisation terminée avec succès !" -Step "Finalisation"
Update-Progress -Percent 100
[System.Windows.Forms.MessageBox]::Show("Personnalisation terminée ! ISO disponible dans $isoOutput", "Succès", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
