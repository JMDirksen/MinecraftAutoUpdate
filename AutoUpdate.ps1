# Include config
. "$PSScriptRoot\AutoUpdate.config.ps1"

# Mojang urls
$versionsJsonUrl = "https://launchermeta.mojang.com/mc/game/version_manifest.json"
$versionsJson = Invoke-RestMethod $versionsJsonUrl

function Main {
	try {
		# Resolve latest version
		$version = $versionsJson.latest.$versionType
		# Compose filename
		$fileName = "minecraft_server.$version.jar"
		
		# Script finished if file already exists
		If (Test-Path $fileName) {
			Write-Log "No newer version available $version"
			exit
		}
		Else {
			Write-Log "New version available $version"
		}

		# Get download URL
		$versionsJsonVersion = $versionsJson.versions | Where-Object { $_.id -eq $version }
		$versionJsonUrl = $versionsJsonVersion.url
		$versionJson = Invoke-RestMethod $versionJsonUrl
		$downloadUrl = $versionJson.downloads.server.url

		# Download
		Write-Log "Downloading $fileName"
		Invoke-WebRequest $downloadUrl -OutFile $fileName

		# Stop server
		Write-Log "Stopping server"
		Stop-ScheduledTask -TaskName $taskName

		# Backup
		Write-Log "Creating ShadowCopy"
		$drive = (Get-Item -Path $minecraftServerDir).PSDrive.Root
		(Get-WmiObject -List Win32_ShadowCopy).Create($drive, "ClientAccessible")

		# Update
		Write-Log "Updating server.jar"
		Copy-Item $fileName "$minecraftServerDir\server.jar"
		
		# Start server
		Write-Log "Starting server"
		Start-ScheduledTask -TaskName $taskName
		
		# Send e-mail
		Write-Log "Sending E-mail"
		$Subject = "$taskName updated to $versionType version $version"
		$Body = "$taskName has been updated to minecraft $versionType version $version"
		$SMTPClient = New-Object Net.Mail.SmtpClient($SmtpServer, 587)
		$SMTPClient.EnableSsl = $true
		$SMTPClient.Credentials = New-Object System.Net.NetworkCredential($SMTPUser, $SMTPPass)
		$SMTPClient.Send($EmailFrom, $EmailTo, $Subject, $Body)
	}
	catch {
		$msg = $_.Exception.Message
		Write-Log "Error: $msg"
		exit
	}
}

function Write-Log {
	$date = (Get-Date).ToShortDateString()
	$time = (Get-Date).ToShortTimeString()
	Add-Content $logFile "$date $time $($args[0])"
}

Main
