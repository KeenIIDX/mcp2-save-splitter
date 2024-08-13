
param(
	[Parameter(Position=0)]
	[string]$command="split",
    [Parameter()]
    [string]$basecard="blank.bin",
	[Parameter()]
    [string]$psu,
	[Parameter()]
    [string]$folder,
	[Parameter()]
    [string]$file
 )


$myMcFolder = ".\mymc"
$psvConverterCmd = ".\psv-converter\psv-converter-win.exe"
$importFolder = ".\import"
$exportFolder = ".\export"
$existingCardsFolder = ".\existing_cards"
$tempFolder = ".\temp"
$cmd = "$($myMcFolder)\mymc.exe"
$psuNameMaxLength = 32

Function Confirm-MyMcPresent {
	$fileExists = Test-Path $cmd
	if (!$fileExists) {
		Write-Output "ERROR: mymc.exe not dedected - please check the readme"
		exit
	}
}

Function Confirm-PsvConverterPresent {
	return Test-Path $psvConverterCmd
}

Function Confirm-MyMcVersion {
	$version = (& $cmd "--version" | Select-String -Pattern '2.6.g2').Matches.Value
	if($version -ne '2.6.g2')  {
		Write-Output "ERROR: Incorrect version of MyMc detected - please check the readme"
		exit
	}
}

Function Confirm-CommandIsValid {
	if(!($command -in @('split','add','import','remove'))) {
		Write-Output('ERROR: Please use one of the following commands:')
		Write-Output('split')
		Write-Output('add')
		Write-Output('import')
		Write-Output('remove')
		exit
	}

	if($command -eq "remove" -and $file -and $folder) {
		Write-Output('ERROR: Please use only one of -file or -folder parameter with remove command. To remove a file from a folder, use -file folder/file.ext')
		exit
	}
}

Function Confirm-BaseCardExists {
	$fileExists = Test-Path (Join-Path ".\" $basecard)
	if (!$fileExists) {
		Write-Output "ERROR: Designated base card $basecard not detected"
		exit
	}
}

Function Confirm-PsuFileExists {
	if(!$psu) {
		Write-Output "ERROR: Please specify a save to import using -psu"
		exit
	}
	if(!($psu -Like "*.psu")) {
		Write-Output "ERROR: PSU file extension incorrect - ensure the file is a .psu file"
		exit
	}

	$fileExists = Test-Path (Join-Path ".\" $psu)
	if (!$fileExists) {
		Write-Output "ERROR: PSU file to import $psu not detected"
		exit
	}

}

Function Confirm-FileToAddExists {
	if(!$file) {
		Write-Output "ERROR: Please specify a file to add using -file"
		exit
	}

	$fileExists = Test-Path (Join-Path ".\" $file)
	if (!$fileExists) {
		Write-Output "ERROR: File to add $file not detected"
		exit
	}
}

Function Confirm-FolderToDelete {
	if(!$folder) {
		Write-Output "ERROR: Please specify a folder to delete using -folder"
		exit
	}
}

Function Confirm-FileToRemove {
	if(!$file) {
		Write-Output "ERROR: Please specify a file to remove using -file"
		exit
	}
}

Function Confirm-FilesToImport {
	$saveFileCount = (Get-ChildItem -Path "$($importFolder)\*" -Include ('*.psu','*.xps','*.max','*.cbs','*.sps','*.psv','*.mc2','*.ps2','*.bin') |  Measure-Object).Count
	if ($saveFileCount -eq 0) {
		Write-Output "No save files detected in import folder"
		exit
	}
}

Function Confirm-FilesInExistingCards {
	$vmcFileCount = (Get-ChildItem -Path "$($existingCardsFolder)\*" -Include ('*.mc2') -Recurse |  Measure-Object).Count
	if ($vmcFileCount -eq 0) {
		Write-Output "No VMC files detected in existing_cards folder"
		exit
	}
}

Function Move-Mc2sToTemp {
	$mcFiles = Get-ChildItem -Path "$($importFolder)\*" -Include *.mc2
	foreach($mcFile in $mcFiles) {
		Copy-Item  -Force -Path "$($importFolder)\$($mcFile.Name)" -Destination "$($tempFolder)\$($mcFile.BaseName).bin"
	}
}

Function Rename-ExistingCardsMc2sToBin {
	$mcFiles = Get-ChildItem -Path "$($existingCardsFolder)\*" -Include *.mc2 -Recurse
	foreach($mcFile in $mcFiles) {
		Rename-Item -Force -Path "$($mcFile.Directory)\$($mcFile.Name)" -NewName "$($mcFile.BaseName).bin"
	}
}

Function Rename-ExistingCardsBinsToMc2 {
	$mcFiles = Get-ChildItem -Path "$($existingCardsFolder)\*" -Include *.bin -Recurse
	foreach($mcFile in $mcFiles) {
		Rename-Item -Force -Path "$($mcFile.Directory)\$($mcFile.Name)" -NewName "$($mcFile.BaseName).mc2"
	}
}

Function Import-PsuToExistingCards {
	$mcFiles = Get-ChildItem -Path "$($existingCardsFolder)\*" -Include *.bin -Recurse
	foreach($mcFile in $mcFiles) {
		Write-Output("Importing PSU to $($mcFile.Name.Replace(".bin",".mc2"))...")
		$fullMcFilePath = "$($mcFile.Directory)\$($mcFile.Name)"
		$result = & $cmd $fullMcFilePath import $psu 2>&1
		$result = [string] $result
		if($result.indexOf("directory exists") -gt -1) {
			Write-Output("ERROR: $($mcFile.Name.Replace(".bin",".mc2")) already contains a folder with this name")
		}
		if($result.indexOf("out of space") -gt -1) {
			Write-Output("ERROR: $($mcFile.Name.Replace(".bin",".mc2")) - not enough space for file")
		}
	}
}

Function Add-FileToExistingCards {
	$mcFiles = Get-ChildItem -Path "$($existingCardsFolder)\*" -Include *.bin -Recurse
	foreach($mcFile in $mcFiles) {
		$fullMcFilePath = "$($mcFile.Directory)\$($mcFile.Name)"
		if($folder) {
			Write-Output("Adding file $folder/$file to $($mcFile.Name.Replace(".bin",".mc2"))...")
			$result = & $cmd $fullMcFilePath mkdir $folder 2>&1
			$result = & $cmd $fullMcFilePath add -d $folder $file 2>&1
			$result = [string] $result
		} else {
			Write-Output("Adding file $file to root of $($mcFile.Name.Replace(".bin",".mc2"))...")
			$result = & $cmd $fullMcFilePath add $file 2>&1
			$result = [string] $result
		}
	}
}

Function Remove-FolderFromExistingCards {
	$mcFiles = Get-ChildItem -Path "$($existingCardsFolder)\*" -Include *.bin -Recurse
	foreach($mcFile in $mcFiles) {
		Write-Output("Removing $folder folder from $($mcFile.Name.Replace(".bin",".mc2"))...")
		$fullMcFilePath = "$($mcFile.Directory)\$($mcFile.Name)"
		$result = & $cmd $fullMcFilePath delete $folder 2>&1
		$result = [string] $result
		if($result -and $result.indexOf("directory not found") -gt -1) {
			Write-Output("WARNING: $($mcFile.Name.Replace(".bin",".mc2")) does not have $folder folder")
		}
	}
}

Function Remove-FileFromExistingCards {
	$mcFiles = Get-ChildItem -Path "$($existingCardsFolder)\*" -Include *.bin -Recurse
	foreach($mcFile in $mcFiles) {
		Write-Output("Removing $file from $($mcFile.Name.Replace(".bin",".mc2"))...")
		$fullMcFilePath = "$($mcFile.Directory)\$($mcFile.Name)"
		$result = & $cmd $fullMcFilePath remove $file 2>&1
		$result = [string] $result
		if($result -and $result.indexOf("file not found") -gt -1) {
			Write-Output("WARNING: $($mcFile.Name.Replace(".bin",".mc2")) does not contain $file")
		}
	}
}

Function Move-Ps2sToTemp {
	$mcFiles = Get-ChildItem -Path "$($importFolder)\*" -Include *.ps2
	foreach($mcFile in $mcFiles) {
		
		Copy-Item  -Force -Path (Join-Path $importFolder $mcFile.Name) -Destination  (Join-Path $tempFolder $mcFile.Name)
	}
}

Function Move-BinsToTemp {
	$binFiles = Get-ChildItem -Path "$($importFolder)\*" -Include *.bin
	foreach($binFile in $binFiles) {
		if (Test-Path -Path "$($tempFolder)\$($binFile.BaseName).bin") {
			$filesWithMatchingName = Get-ChildItem -Path "$($tempFolder)\$($binFile.BaseName)*" -Include *.bin
			$newName = "$($binFile.BaseName)-$($filesWithMatchingName.Count).bin"
			Copy-Item  -Force -Path "$($importFolder)\$($binFile.Name)" -Destination "$($tempFolder)\$($newName).bin"
		} else {
			Copy-Item  -Force -Path "$($importFolder)\$($binFile.Name)" -Destination "$($tempFolder)\$($binFile.BaseName).bin"
		}
	}
}

Function Move-SaveFilesToTemp {
	$saveFiles = Get-ChildItem -Path "$($importFolder)\*" -Include ('*.psu','*.xps','*.max','*.cbs','*.sps')
	foreach($saveFile in $saveFiles) {
		Copy-Item  -Force -Path (Join-Path $importFolder $saveFile.Name) -Destination (Join-Path $tempFolder $saveFile.Name)
	}
}


Function Move-PsvsToTemp {
	$psvFiles = Get-ChildItem -Path (Join-Path $importFolder "\*") -Include *.psv
	foreach($psvFile in $psvFiles) {
		Copy-Item  -Force -Path (Join-Path $importFolder $psvFile.Name) -Destination (Join-Path $tempFolder $psvFile.Name)
	}
}


Function Convert-PsvsToPsus {
	$psvFiles = Get-ChildItem -Path (Join-Path $tempFolder "\*") -Include *.psv
	foreach($psvFile in $psvFiles) {
		& $psvConverterCmd (Join-Path $psvFile.Directory $psvFile.Name)
	}
}


Function Export-Psus($mcFile) {
	$prm = "$($tempFolder)\$($mcFile.Name)", "dir"
	$saveList = & $cmd $prm
	if($saveList.getType().Name -eq "String") {
		Write-Output "No saves found in $($mcFile.BaseName)"
		continue
	}
	$saves = New-Object Collections.Generic.List[String]
	for($i = 0; $i -lt $saveList.Length; $i = $i + 3) {
		if ($saveList[$i] -match 'S[A-Z][A-Z][A-Z]-\d\d\d\d\d') {
			$psuName = $saveList[$i].Substring(0, $psuNameMaxLength).Trim()
			if($psuName.Length) {
				$saves.Add($psuName)
			}
		}
	}
	
	if($saves.Length) {
		foreach($save in $saves) {
			Write-Output "Found $($save) in $($mcFile.BaseName)..."
			$fullMcFilePath = "$($tempFolder)\$($mcFile.Name)"
			& $cmd $fullMcFilePath export -d $tempFolder $save
		}
	}
	
}

Function Get-PsusFromBins {
	$binFiles = Get-ChildItem -Path "$($tempFolder)\*" -Include *.bin

	foreach($binFile in $binFiles) {
		Write-Output ''
		Export-Psus $binFile
	}
}

Function Get-PsusFromPs2s {
	$ps2Files = Get-ChildItem -Path "$($tempFolder)\*" -Include *.ps2

	foreach($ps2File in $ps2Files) {
		Export-Psus $ps2File
	}
}

Function Get-PsuWithGameId($saveFile) {
	Copy-Item -Path (Join-Path ".\" $basecard) -Destination (Join-Path $tempFolder "tempCard.bin")
	$prm = $prm = (Join-Path $tempFolder "tempCard.bin"), "import", (Join-Path $tempFolder $($saveFile.Name))
	& $cmd $prm
	$newSaveFile = Get-ChildItem -Path (Join-Path $tempFolder "tempCard.bin")
	Export-Psus($newSaveFile)
	Remove-Item -Path (Join-Path $tempFolder "tempCard.bin")
}

Function Repair-SavesWithNoGameId {
	$saveFiles = Get-ChildItem -Path "$($tempFolder)\*" -Include ('*.psu','*.xps','*.max','*.cbs','*.sps')
	foreach($saveFile in $saveFiles) {
		if(!($saveFile.BaseName -match 'S[A-Z][A-Z][A-Z]-\d\d\d\d\d')) {
			Get-PsuWithGameId($saveFile)
			Remove-Item -Path (Join-Path $saveFile.Directory $saveFile.Name)
		}
	}
}

Function New-CardIfNotExist {
	Param
    (
         [Parameter(Mandatory=$true, Position=0)]
         [string] $gameId,
         [Parameter(Mandatory=$true, Position=1)]
         [string] $channelNum
    )
	if (!(Test-Path -Path (Join-Path $exportFolder $gameId))) {
		New-Item -ItemType Directory -Force -Path (Join-Path $exportFolder $gameId)
	}

	if (!(Test-Path -Path (Join-Path $exportFolder $gameId | Join-Path -ChildPath "$($gameId)-$($channelNum).bin"))) {
		Copy-Item -Path (Join-Path ".\" $basecard) -Destination (Join-Path $exportFolder $gameId | Join-Path -ChildPath "$($gameId)-$($channelNum).bin")
	}
}

Function Import-FileToCard {
	Param
    (
         [Parameter(Mandatory=$true, Position=0)]
         [string] $gameId,
         [Parameter(Mandatory=$true, Position=1)]
         [string] $channelNum,
		 [Parameter(Mandatory=$true, Position=2)]
         $saveFile
    )
	$prm = ".\$($exportFolder)\$($gameId)\$($gameId)-$($channelNum).bin", "import", ".\$($tempFolder)\$($saveFile.Name)"
	$result = & $cmd $prm 2>&1
	$result = [string] $result
	if($result.indexOf("directory exists") -gt -1 -or $result.indexOf("out of space") -gt -1) {
		return $false
	} else {
		return $result
	}

}

Function New-Vmcs {
	$saveFiles = Get-ChildItem -Path "$($tempFolder)\*" -Include ('*.psu','*.xps','*.max','*.cbs','*.sps')

	foreach($saveFile in $saveFiles) {
		$channelNum = 1
		if($saveFile.BaseName -match 'S[A-Z][A-Z][A-Z]-\d\d\d\d\d') {
			$gameId = $Matches.0
		} else {
			Write-Output "Could not find Game ID in $($saveFile.Name)"
			continue
		}

		New-CardIfNotExist $gameId $channelNum
		$result = Import-FileToCard $gameId $channelNum $saveFile
		if($result) {
			Write-Output $result
			continue
		}

		for ($nextChannel = 2; $nextChannel -lt 10; $nextChannel++) {
			if ($nextChannel -eq 9) {
				Write-Output "Too many saves for $($saveFile.BaseName), ignoring"
				continue
			} 
			New-CardIfNotExist $gameId $nextChannel
			$result = Import-FileToCard $gameId $nextChannel $saveFile
			if($result) {
				Write-Output $result
				break
			}
		}
	}

	$exportFiles = $saveFiles = Get-ChildItem -Recurse -Path "$($exportFolder)\*" -Include *.bin

	foreach($exportFile in $exportFiles) {
		Move-Item -Path "$($exportFile.Directory)\$($exportFile.Name)" -Destination "$($exportFile.Directory)\$($exportFile.BaseName).mc2" -Force
	}
}

Function New-TempDir {
	if (!(Test-Path -Path "$($tempFolder)")) {
		New-Item -ItemType Directory -Force -Path "$($tempFolder)"
	}
}

Function Clear-TempDir {
	Remove-Item -Force -Recurse -Path "$($tempFolder)"
}

Function Move-FilesToTempDir {
	Move-SaveFilesToTemp
	Move-Mc2sToTemp
	Move-Ps2sToTemp
	Move-BinsToTemp
}

Function Convert-PsvFiles {
	$psvFiles = Get-ChildItem -Path (Join-Path $importFolder "\*") -Include *.psv
	if($psvFiles.Length -gt 0 -and !(Confirm-PsvConverterPresent)) {
		Write-Output ".psv files ignored as psv-converter-win.exe not found - please check the readme"
		return
	}
	Move-PsvsToTemp
	Convert-PsvsToPsus
}

Function Get-Psus {
	Get-PsusFromBins
	Get-PsusFromPs2s
}

Confirm-MyMcPresent
Confirm-MyMcVersion
Confirm-CommandIsValid

if($command -eq "split") {
	Confirm-BaseCardExists
	Confirm-FilesToImport
	New-TempDir 
	Move-FilesToTempDir
	Convert-PsvFiles
	Get-Psus
	Repair-SavesWithNoGameId
	New-Vmcs
	Clear-TempDir
}

if($command -eq "import") {
	Confirm-PsuFileExists
	Confirm-FilesInExistingCards
	Rename-ExistingCardsMc2sToBin
	Import-PsuToExistingCards
	Rename-ExistingCardsBinsToMc2
}

if($command -eq "add") {
	Confirm-FileToAddExists
	Confirm-FilesInExistingCards
	Rename-ExistingCardsMc2sToBin
	Add-FileToExistingCards
	Rename-ExistingCardsBinsToMc2
}

if($command -eq "remove" -and $folder) {
	Confirm-FolderToDelete
	Confirm-FilesInExistingCards
	Rename-ExistingCardsMc2sToBin
	Remove-FolderFromExistingCards
	Rename-ExistingCardsBinsToMc2
}

if($command -eq "remove" -and $file) {
	Confirm-FileToRemove
	Confirm-FilesInExistingCards
	Rename-ExistingCardsMc2sToBin
	Remove-FileFromExistingCards
	Rename-ExistingCardsBinsToMc2
}

