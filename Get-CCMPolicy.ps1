<#
.SYNOPSIS
SCCM Policy Check Tool. Will run across multiple computers listed ($ComputerName accepts multiple). 

Can be run via Powershell command line, or executed without any policy to run and will launch a GUI that can be used and reused for other computers.

.DESCRIPTION
SCCM Policy Check Tool. Will run across multiple computers listed ($ComputerName accepts multiple). 

Can be run via Powershell command line, or executed without any policy to run and will launch a GUI that can be used and reused for other computers.

.PARAMETER ComputerName
Computer, or list of computers to run SCCM policies against.

.PARAMETER AppEvaluation
Runs the Application Evaluation cycle

.PARAMETER CheckPolicy
Runs the Machine Policy check from SCCM.

.PARAMETER SWUpdateScanCycle
Runs the Software Update Scan Cycle

.PARAMETER SWUpdateEvaluation
Runs the Software Update Evaluation Cycle

.PARAMETER HardwareInventory
Runs the hardware inventory cycle.

.PARAMETER ScanType
Same as the above parameters, but lets you choose a combination of policy checks instead:
 '1 - AppEval and Policy',
 '2 - Policy',
 '3 - AppEval',
 '4 - HWInv',
 '5 - SWUpdateScan',
 '6 - SWUpdateEval',
 '7 - All, No HWInv'

.PARAMETER ResetSCCMPolicy
Resets the SCCM Policy back to default. 
Recommend running CheckPolicy afterward to speed things along.

.EXAMPLE
.\Get-CCMPolicy.ps1 -ComputerName "MyPC" -AppEvaluation -CheckPolicy

.EXAMPLE
.\Get-CCMPolicy.ps1 -ComputerName "MyPC"
#This will launch the GUI, with "MyPC" listed in the computers to check against.

.EXAMPLE
.\Get-CCMPolicy.ps1 -ComputerName "MyPC", "YourPC", "TheirPC"
#This will launch the GUI, with "MyPC", "YourPC" and "TheirPC" listed in the computers to check against.

.NOTES
General notes
Author: Jonathan Caum
Last Updated: 10/18/2021


#>



[cmdletbinding()]


param(
    [Parameter(Position = 0)]
    [Alias('CN')]
    [PSCustomObject]$ComputerName,
    [switch]$AppEvaluation,
    [switch]$CheckPolicy,
    [switch]$SWUpdateScanCycle,
    [switch]$SWUpdateEvaluation,
    [switch]$HardwareInventory,
    [switch]$ResetSCCMPolicy,
    [Parameter(Position = 2, HelpMessage = "CCM Scan type. Combo1 = Policy and AppEval")]
    [ValidateSet(
        '1 - AppEval and Policy',
        '2 - Policy',
        '3 - AppEval',
        '4 - HWInv',
        '5 - SWUpdateScan',
        '6 - SWUpdateEval',
        '7 - All, No HWInv'
    )]
    [string]$ScanType
)


$script:rerun = ""




Add-Type -Name Window -Namespace Console -MemberDefinition '

[DllImport("Kernel32.dll")]

public static extern IntPtr GetConsoleWindow();

[DllImport("user32.dll")]

public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);

'

function Show-Console {

    $consolePtr = [Console.Window]::GetConsoleWindow()

    #5 show

    [Console.Window]::ShowWindow($consolePtr, 5)

}

function Hide-Console {

    $consolePtr = [Console.Window]::GetConsoleWindow()

    #0 hide

    [Console.Window]::ShowWindow($consolePtr, 0)

}

Function Get-CCMPolicy {

    [cmdletbinding()]      
    
    param (
    
        [Parameter(Position = 0)]
        [Alias('CN')]
        [PSCustomObject]$ComputerName,
        [bool]$AppEvaluation,
        [bool]$CheckPolicy,
        [bool]$SWUpdateScanCycle,
        [bool]$SWUpdateEvaluation,
        [bool]$HardwareInventory,
        [bool]$resetsccmpolicy,
        [Parameter(Position = 2, HelpMessage = "CCM Scan type. Combo1 = Policy and AppEval")]
        [ValidateSet(
            '1 - AppEval and Policy',
            '2 - Policy',
            '3 - AppEval',
            '4 - HWInv',
            '5 - SWUpdateScan',
            '6 - SWUpdateEval',
            '7 - All, No HWInv',
            '9 - Purge/Reset CCM Policy'
        )]
        [string]$ScanType
    )

    

    if ($ComputerName -like $NULL) { $ComputerName = $env:COMPUTERNAME }

    if ($scantype -like '1 - AppEval and Policy') {
        [switch]$CheckPolicy = $TRUE
        [switch]$AppEvaluation = $TRUE
    }
    if ($ScanType -like '2 - Policy') {
        [switch]$CheckPolicy = $TRUE
    }
    if ($ScanType -like '3 - AppEval') {
        [switch]$AppEvaluation = $TRUE
    }
    if ($scantype -like '4 - HWInv') {
        [switch]$HardwareInventory = $TRUE
    }
    if ($ScanType -like '6 - SWUpdateEval') {
        [switch]$SWUpdateEvaluation = $TRUE
    }
    if ($scantype -like '5 - SWUpdateScan') {
        [switch]$SWUpdateScanCycle = $TRUE
    }
    if ($scantype -like '7 - All, No HWInv') {
        [switch]$AppEvaluation = $TRUE
        [switch]$CheckPolicy = $TRUE
        [switch]$SWUpdateEvaluation = $TRUE
        [switch]$SWUpdateScanCycle = $TRUE
    }
    if ($ScanType -like '9 - Purge/Reset CCM Policy') {
        [switch]$AppEvaluation = $False
        [switch]$CheckPolicy = $False
        [switch]$SWUpdateEvaluation = $False
        [switch]$SWUpdateScanCycle = $False
        [switch]$ResetSCCMPolicy = $True
    }

    $i = 0

        foreach ($pc in $ComputerName) {
            $i++
            [int]$script:pct = ($i / $ComputerName.Count) * 100
            if ((Test-Connection -ComputerName $pc -count 1 -quiet) -ne $FALSE) {  
                Write-Verbose -Message "Binding \\$pc\root\ccm:SMS_Client"
                $SMSCli = [wmiclass] "\\$pc\root\ccm:SMS_Client"  
                if ($SMSCli) {
                    Write-Output "$pc"  
                    if ($CheckPolicy -eq $TRUE) {
                        try {
                            $getpolicy = $SMSCli.RequestMachinePolicy()
                            $evalpolicy = $SMSCli.EvaluateMachinePolicy()
                            Write-Output "SUCCESS: Ran machine policy request on $pc"
                        }
                        catch { "ERROR: Could not run policy on $PC. Result: $getpolicy, $evalpolicy" }
                    }
                    if ($HardwareInventory -eq $TRUE) {
                    
                        try {
                            $check = $SMScli.TriggerSchedule("{00000000-0000-0000-0000-000000000001}")
                            Write-Output "SUCCESS: Ran hardware inventory scan on $pc"
                        }
                        catch { "ERROR: Could not run HW Inventory on PC. Result: $check" }

                    }
                    if ($AppEvaluation -eq $TRUE) {
                        #Application manager policy action 
                        try {
                            $check = $SMScli.TriggerSchedule("{00000000-0000-0000-0000-000000000121}")
                            Write-Output "SUCCESS: Ran Application Eval scan on $pc"
                        }
                        catch { "ERROR: Could not run App Eval on $PC. Result: $check" }
                    }
                    if ($SWUpdateEvaluation -eq $TRUE) {
                        #Application manager policy action 
                        try {
                            $check = $SMScli.TriggerSchedule("{00000000-0000-0000-0000-000000000114}")
                            Write-Output "SUCCESS: Ran SW Update Eval scan on $pc"
                        }
                        catch { "ERROR: Could not SW Update Eval on $PC. Result: $check" }
                    }
                    if ($SWUpdateScanCycle -eq $TRUE) {
                        #Application manager policy action 
                        try {
                            $check = $SMScli.TriggerSchedule("{00000000-0000-0000-0000-000000000113}")
                            Write-Output "SUCCESS: Ran SW Update Scan Cycle on $pc"
                        }
                        catch { "ERROR: Could not run SW Update Scan on $PC. Result: $check" }
                    }
                    if ($ResetSCCMPolicy -eq $TRUE) {
                        try {
                            ([WMIClass]"\\$($PC)\root\ccm:SMS_Client").psbase.InvokeMethod("ResetPolicy", 1)
                            Write-Output "SUCCESS: Reset CCM Policy on $PC"
                        }
                        catch { Write-Warning "ERROR: Could not reset policy on $PC" }
                    }
                    Write-Output " "
                }  
                else {  
                    write-output "FAILED - Could not bind WMI class SMS_Client on $PC"  
                }  
            }
            else {
                Write-output "FAILED: Computer $pc is not online"
                Write-Output " "
            }
        }        

    }


Function QuitProgram {
    if ($form1 -notlike $NULL) {
        Write-Host "Form is $Form1"
        $form1.hide()
    }
    if ($form2 -notlike $NULL) {
        $form2.hide()
    }
    #return(0)
    Show-Console
}

Function Start-Over {
    if ($form1) {
        $form1.close()
        $form1.dispose()
    }
    if ($form2) {
        $form2.close()
        $form2.dispose()
    }
    #[GC]::Collect()
    #$script:rerun = $TRUE
    Start-Checks
}

Function Exit-Form {
    if ($form1) {
        $form1.close()
        $form1.dispose()
    }
    if ($form2) {
        $form2.close()
        $form2.dispose()
    }
    Show-Console
    #[GC]::Collect()
    #$script:rerun = $TRUE
}


Function set_background {
    $pen = [system.drawing.pen]::new([System.Drawing.Color]::FromName("lightblue"))
    $graphics = $_.Graphics;
    $rbackground = new-object system.drawing.rectangle(0, 0, $($this.width), $($this.height))
    $graphics.DrawRectangle($pen, $rbackground)
    $lightblue = [System.Drawing.Color]::SteelBlue
    $white = [system.drawing.color]::WhiteSmoke
    $brush = [System.Drawing.Drawing2D.LinearGradientBrush]::new($rbackground, $lightblue, $white, 30, $TRUE)
    $graphics.FillRectangle($brush, $rbackground)
    $brush.dispose()
}
 
Function Start-Checks {

    Add-Type -AssemblyName System.Windows.Forms, System.Drawing, PresentationFramework
    [system.reflection.assembly]::LoadWithPartialName('System.Windows.Forms')
    [system.reflection.assembly]::LoadWithPartialName('System.Drawing')
    [system.reflection.assembly]::LoadWithPartialName('PresentationFramework')

    #$global:icon = [System.Drawing.Icon]::ExtractAssociatedIcon("C:\scripts\cmupdate.exe")
    $iconbase64 = @"
AAABAAEAICAQMwAAAADoAgAAFgAAACgAAAAgAAAAQAAAAAEABAAAAAAAgAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAACAAAAAgIAAgAAAAIAAgACAgAAAgICAAMDAwAAAAP8AAP8AAAD//wD/AAAA/wD/AP//AAD///8AAAAAAAAAAAAAAAAAAAAAAAAAAAh3d3d3d3d3dgAAAAAAAAAI//+IiIiIiIcAAAAAAAAACPj4////iIiHAAAAAAAAAAj/////iHd3hwAAAAAAAAAI///////4iIdmZmYAAAAAB4iIiHd3d3d3iIiGAAAAAAj////4iIiIh4iihgAAAAAI93d3d3dmZoeIqoYAB4iICPd3d3d3dmaHiIiGAAeAeAj3iId3d3dmh4iIhgAHgHgI94iIh3d3dof4iIYAB4AICPeIiIiHd3eH/4iGAAeIiIj4iIiIh3d3h//4hgAHd3d4+Ii                     IiIh3d4f//4cAB4iIiPiIiIiId3eI//+HAAeAeAj4iIiIiId3+P//hwAHgHgI+IiIiIiHd/j///cAB/AICPiIiHd3Zmb4d3d3AAf/+Ij/////////+IiIhwAH8H8HiIiIiIiIiIj//4cAB/B/B4B4dwAH//////+HAAfwDwDwCHcAB///////9wAH//////h3AAeIiId3d3cACPB/B/B/dwAI+IiIiIiHAAjwfwfwf3cACP//////hwAI8A8A8A93AAj//////4cACP//////dwAI///////3AAj//////3cACIiIiIh3dwAAiIiIiIh3AAAAAAAAAAAAAAiIiIiIhwAAAAAAAAAAAAAAh3d3dmYAAAAAAAAAAAD//////gAA//4AAP/+AAD//gAA//4AAAP+AAAD/gAAA4AAAAOAAAADgAAAA4AAAAOAAAADgAAAA4AAAAOAAAADgAAAA4AAAAOAAAADgAAAA4AAAAOAAYADgAGAA4ABgAOAAYADgAGAA4ABgAOAAYADgAGAA8AB///gAf//8AP//w==
"@
    $iconbmp = [System.IO.MemoryStream][System.Convert]::FromBase64String($iconbase64)
    $image = [system.drawing.bitmap][system.drawing.image]::fromstream($iconbmp)
    $global:icon = [system.drawing.icon]::FromHandle($image.GetHicon())


    [System.Windows.Forms.Application]::EnableVisualStyles()
    $tooltip1 = New-Object System.Windows.Forms.ToolTip

    $form1 = New-Object System.Windows.Forms.Form
    $form1.Text = "CCM Policy Tool"
    $form1.FormBorderStyle = "FixedSingle"
    $form1.icon = $global:icon
    $form1.ShowInTaskbar = $true
    $form1.ShowIcon = $true
    $form1.MaximizeBox = $false
    $form1.MinimizeBox = $false
    $form1.ControlBox = $true
    $CenterScreen = [System.Windows.Forms.FormStartPosition]::CenterScreen;
    $form1.StartPosition = $CenterScreen
    $form1.backcolor = [System.Drawing.Color]::FromName("White")
    $form1.height = 350
    $form1.width = 450

    $panel1 = new-object System.Windows.Forms.Panel
    $panel1.height = $form1.Height
    $panel1.Width = $form1.Width
    $panel1.paint
    

    $panel1.add_paint( { set_background })
    $panel1.BringToFront()
    $form1.controls.add($panel1)


    

    # create OK and cancel scriptblocks
    $oksb = {
        $form1.dialogresult = 1
        $form1.hide()
        Results
    }
    $cancelsb = {
        $form1.dialogresult = 2
        $form1.hide()
        Show-Console
        #return(0)
		
    }


    $browsefiles1 = {
        $browse = new-object windows.Forms.OpenFileDialog
        $browse.ShowDialog()
        $browse.openfile()
        $text = [IO.File]::ReadAllText($($browse.filename)) -replace ' ', "`n"
        $text1.Text = $text
        $global:importedPCS = $($text1.Lines)
        $global:imported = $TRUE
        $global:content = $($text1.Lines)
        #$form1.controls.add($text1)
                
    }

    $ResetPolicyClick = {
        if ($check9.Checked) {
            [bool]$script:resetsccmpolicy = $TRUE
            [bool]$script:CheckPolicy = $False
            [bool]$script:AppEvaluation = $False
            [bool]$script:SWUpdateScanCycle = $false
            [bool]$script:SWUpdateEvaluation = $false
            $Check1.Checked = $False
            $check2.checked = $false
            $check3.Checked = $false
            $check4.checked = $false
            $check5.checked = $false
            $CCMgroups.Enabled = $False
        }
        else {
            [bool]$script:resetsccmpolicy = $FALSE
            $Check1.Checked = $True
            [bool]$script:CheckPolicy = $true
            [bool]$script:AppEvaluation = $true
            [bool]$script:SWUpdateEvaluation = $true
            $check2.checked = $false
            $check3.Checked = $True
            $check4.checked = $True
            $check5.checked = $false
            $CCMgroups.Enabled = $True
        }
    }

 
    # create OK button
    $okbutton1 = New-Object system.Windows.Forms.Button
    $okbutton1.text = "O&K"
    $okbutton1.height = 25
    $okbutton1.width = 75
    #$okbutton1.top = 280 #51
    $okbutton1.top = $($form1.height - $okbutton1.Height - $okbutton1.Height - 25) #51
    $okbutton1.left = $($form1.width - $okbutton1.width - 75 - 30  ) #147
    $showhelp = $tooltip1.SetToolTip($okbutton1, "Start the CCM checks for the listed computers...")
    $okbutton1.add_MouseHover($ShowHelp)
    $okbutton1.add_click($oksb)
    $panel1.controls.add($okbutton1)
 
    # create Cancel button
    $cancelbutton1 = New-Object system.Windows.Forms.Button
    $cancelbutton1.text = "&Cancel"
    $cancelbutton1.height = 25
    $cancelbutton1.width = 75
    $cancelbutton1.top = $($form1.height - $cancelbutton1.height - $cancelbutton1.Height - 25) #51
    $cancelbutton1.left = $($form1.width - $cancelbutton1.Width - 24) #66
    $showhelp = $tooltip1.SetToolTip($cancelbutton1, "Cancel. Will not run CCM checks.")
    $cancelbutton1.add_MouseHover($ShowHelp)
    $cancelbutton1.add_click($cancelsb)
    $panel1.controls.add($cancelbutton1)
    
    #Create Import button
    $importbutton1 = New-Object System.Windows.Forms.Button
    $importbutton1.text = "&Import" 
    $importbutton1.height = 25
    $importbutton1.width = 75
    $importbutton1.top = $($form1.height - $importbutton1.Height - $importbutton1.height - 25)
    $importbutton1.left = 11
    if ($importbutton1.CanFocus) {
        $importbutton1.Focus();
    }
    $importbutton1.add_click($browsefiles1)
    $panel1.controls.add($importbutton1)

    # create label
    $label1 = New-Object system.Windows.Forms.Label
    $label1.Font = New-Object System.Drawing.Font("Tahoma", 10, [System.Drawing.FontStyle]::Regular)
    $label1.text = "Enter computer name:"
    $label1.ForeColor = [System.Drawing.Color]::FromName("White")
    $label1.BackColor = [System.Drawing.Color]::FromName("Transparent")
    $label1.TextAlign = "TopLeft"
    $label1.AutoSize = "True"
    $label1.left = 11
    $label1.top = 13
    $label1.width = 205
    $label1.height = 13
    $panel1.controls.add($label1)

    
    # create text box
    $text1 = New-Object System.Windows.Forms.TextBox
    #create a default value
    if ($script:rerun -like $NULL) {
        $text1.Text = ($script:ComputerName | out-string).Trim()
    }
    else {
        $text1.text = ($script:ThoseComputers | out-string).Trim()
    }
    $text1.left = 11
    $text1.top = 35
    $text1.height = 230
    $text1.width = 205
    $text1.BackColor = [System.Drawing.Color]::FromName("Black")
    
    $text1.ForeColor = [System.Drawing.Color]::FromName("LightGreen")
    $text1.multiline = $True
    $text1.scrollbars = "Vertical"
    $text1.Font = New-Object System.Drawing.Font("Tahoma", 10, [System.Drawing.FontStyle]::Regular)
    $tip = $tooltip1.SetToolTip($text1, "Enter a list of computers...")
    $text1.add_MouseHover($tip)
    if ($text1.CanFocus) {
        $text1.focus();
    }
    $panel1.controls.add($text1)

    # Version String
    $version = New-Object System.Windows.Forms.Label
    $version.text = "Version: 20211018"
    $version.width = 120
    $version.height = 18
    $version.BackColor = [System.Drawing.Color]::FromName("Transparent")
    $version.TextAlign = "MiddleCenter"
    $version.ForeColor = [System.Drawing.Color]::FromName("DarkGray")
    $version.top = $($text1.top + $text1.height - $version.size.Height)
    $version.font = New-Object System.Drawing.Font("Tahoma", 8, [System.Drawing.FontStyle]::Bold)
    $version.left = $($form1.width - $version.size.Width - 25)
    $panel1.controls.add($version)

    $cbcolor = [System.Drawing.Color]::FromName("Transparent")
    $cbfont = New-Object System.Drawing.Font("Tahoma", 10, [System.Drawing.FontStyle]::Regular)
    $groupboxfont = New-Object System.Drawing.Font("Tahoma", 8, [System.Drawing.FontStyle]::Regular)

    $CCMgroups = new-object System.Windows.Forms.GroupBox
    $CCMgroups.Name = "CCM Client Commands"
    $CCMgroups.Text = "CCM Client Commands"
    $CCMgroups.ForeColor = [System.Drawing.Color]::FromName("Black")
    $CCMgroups.Top = 30
    $CCMgroups.Left = 230
    $CCMgroups.Height = 150
    $CCMgroups.Width = 190
    $CCMgroups.BackColor = $cbcolor
    $CCMgroups.Font = $groupboxfont

    $ResetPolicy = New-Object System.Windows.Forms.GroupBox
    $ResetPolicy.Name = "Purge Policy"
    $ResetPolicy.Text = "Purge Policy"
    $resetpolicy.ForeColor = [System.Drawing.Color]::FromName("Black")
    $ResetPolicy.Top = $CCMgroups.Top + $CCMgroups.height + 15
    $ResetPolicy.height = 45
    $ResetPolicy.Width = 190
    $ResetPolicy.Left = 230
    $ResetPolicy.BackColor = $cbcolor
    $ResetPolicy.Font = $groupboxfont

    $c1cmd = {
        if ($check1.Checked) {
            #Check Policy
            [bool]$script:CheckPolicy = $True
        }
        else {
            [bool]$script:CheckPolicy = $False
        }
    }

    $c2cmd = {
        if ($check2.Checked) {
            #AppEval
            [bool]$script:AppEvaluation = $True
        }
        else { [bool]$script:AppEvaluation = $FALSE }
    }

    $c3cmd = {
        if ($check3.Checked) {
            [bool]$script:SWUpdateScanCycle = $true 
        }
        else { [bool]$script:SWUpdateScanCycle = $FALSE }
    }

    $c4cmd = {
        if ($check4.Checked) {
            [bool]$script:SWUpdateEvaluation = $TRUE
        }
        else { [bool]$script:SWUpdateEvaluation = $FALSE }
    }

    $c5cmd = {

        if ($check5.Checked) {
            [bool]$HardwareInventory = $TRUE
        }
        else { [bool]$HardwareInventory = $FALSE }
    }



    #create some check boxes
    $check1 = New-Object System.Windows.Forms.CheckBox
    $check1.width = 150
    $check1.Text = "Check Policy"
    $check1.font = $cbfont
    $check1.Top = 15
    $check1.Left = 12
    $check1.BackColor = $cbcolor
    $showhelp = $tooltip1.SetToolTip($check1, "Check Policy.")
    $check1.add_MouseHover($ShowHelp)
    $check1.Checked = $True
    $check1.add_click($c1cmd)
    $CCMgroups.controls.add($check1)

    #create some check boxes
    $check2 = New-Object system.Windows.Forms.CheckBox
    $check2.width = 150
    $check2.Text = "App Evaluation"
    $check2.font = $cbfont
    $check2.Top = 25 + $check1.top
    $check2.Left = $check1.Left
    $check2.BackColor = $cbcolor
    $showhelp = $tooltip1.SetToolTip($check2, "Application Evaluation.")
    $check2.add_MouseHover($ShowHelp)
    $check2.add_click($c2cmd)
    $check2.Checked = $True

    $CCMgroups.controls.add($check2)

    

    #create some check boxes
    $check3 = New-Object system.Windows.Forms.CheckBox
    $check3.width = 150
    $check3.Text = "SW Update Scan"
    $check3.font = $cbfont
    $check3.Top = 25 + $check2.top
    $check3.Left = $check1.Left
    $check3.BackColor = $cbcolor
    $showhelp = $tooltip1.SetToolTip($check3, "Software Update Scan Cycle.")        
    $check3.add_MouseHover($ShowHelp)
    $check3.add_click($c3cmd)
    $check3.Checked = $False

    $CCMgroups.controls.add($check3)

    #create some check boxes
    $check4 = New-Object system.Windows.Forms.CheckBox
    $check4.width = 150
    $check4.Text = "SW Update Evaluation"
    $check4.font = $cbfont
    $check4.Top = 25 + $check3.top
    $check4.Left = $check1.Left
    $check4.BackColor = $cbcolor
    $showhelp = $tooltip1.SetToolTip($check4, "Software Update Evaluation")
    $check4.add_MouseHover($ShowHelp)
    $check4.add_click($c4cmd)
    $check4.Checked = $TRUE

    $CCMgroups.controls.add($check4)

    #create some check boxes
    $check5 = New-Object system.Windows.Forms.CheckBox
    $check5.width = 150
    $check5.Text = "HW Inventory Scan"
    $check5.font = $cbfont
    $check5.Top = 25 + $check4.top
    $check5.Left = $check1.Left
    $check5.BackColor = $cbcolor
    $showhelp = $tooltip1.SetToolTip($check5, "Hardware Inventory Scan")
    $check5.add_MouseHover($ShowHelp)
    $check5.add_click($c5cmd)
    $check5.Checked = $False

    $CCMgroups.controls.add($check5)

    #Reset CCM Client Policy
    $Check9 = New-Object System.Windows.Forms.CheckBox
    $check9.width = 150
    $check9.Text = "Reset CCM Client Policy"
    $check9.Parent = $ResetPolicy
    $check9.font = New-Object System.Drawing.Font("Tahoma", 8, [System.Drawing.FontStyle]::Regular)
    $check9.Top = $check1.Top
    $check9.Left = $check1.Left
    $check9.BackColor = $cbcolor
    $showhelp = $tooltip1.SetToolTip($check9, "Reset CCM Client Policy")
    $check9.add_MouseHover($ShowHelp)
    $check9.add_click($ResetPolicyClick)
    $check9.Checked = $False

    $ResetPolicy.Controls.add($check9)
    $panel1.Controls.add($ResetPolicy)
    $panel1.Controls.add($CCMgroups)

    if ($check1.Checked) {
        #Check Policy
        [bool]$script:CheckPolicy = $true
    }
    else { [bool]$script:CheckPolicy = $False }

    if ($check2.Checked) {
        #AppEval
        [bool]$script:AppEvaluation = $True
    }
    else { [bool]$script:AppEvaluation = $FALSE }

    if ($check3.Checked) {
        [bool]$script:SWUpdateScanCycle = $true 
    }
    else { [bool]$script:SWUpdateScanCycle = $FALSE }

    if ($check4.Checked) {
        [bool]$script:SWUpdateEvaluation = $TRUE
    }
    else { [bool]$script:SWUpdateEvaluation = $FALSE }

    if ($check5.Checked) {
        [bool]$HardwareInventory = $TRUE
    }
    else { [bool]$HardwareInventory = $FALSE }

    if ($check9.Checked) {
        [bool]$script:resetsccmpolicy = $TRUE
        [bool]$script:CheckPolicy = $False
        [bool]$script:AppEvaluation = $False
        [bool]$script:SWUpdateScanCycle = $false
        [bool]$script:SWUpdateEvaluation = $false
        $CCMgroups.Enabled = $False
    }
    else {
        [bool]$script:resetsccmpolicy = $FALSE
        $CCMgroups.Enabled = $True
    }


    Hide-Console
    if ($form1.showdialog() -eq 2) {
        # show form 1
		
        # cancelled 
        $ComputerName = $NULL
        $Computers = $NULL
    }

}

Function Results {
    



    # Initialize the output array
    $result = @()

    $text1.refresh()
    $computers = $($text1.Lines)


    ## If more than one computer is listed in the text box, display a progress bar.
    ##
    if ($Computers.Count -gt 0) {
        $i = 0
        $f3width = 400
        $f3height = 120
        $form3 = New-Object System.Windows.Forms.Form
        $form3.Text = "Running CCM Check on $Computer"
        $form3.font = New-Object System.Drawing.Font("Tahoma", 10, [System.Drawing.FontStyle]::Regular)
        $form3.icon = $global:icon
        $form3.height = $f3height
        $form3.width = $f3width
        $CenterScreen = [System.Windows.Forms.FormStartPosition]::CenterScreen;
        $form3.StartPosition = $CenterScreen
        $form3.formborderstyle = "FixedSingle"
        $form3.MinimizeBox = $FALSE
        $form3.MaximizeBox = $FALSE
        $form3.ControlBox = $True
        $label3 = new-object System.Windows.Forms.Label
        $label3.text = "Running CCM Checks on: $Computer - 0%"
        $label3.font = New-Object System.Drawing.Font("Tahoma", 10, [System.Drawing.FontStyle]::Regular)
        $label3.left = 10
        $label3.top = 10
        $label3.width = $($f3width - 20)
        $label3.height = 20
        $form3.controls.add($label3)
        $progressbar1 = New-Object System.Windows.Forms.ProgressBar
        $progressbar1.Name = 'progressBar1'
        $progressbar1.Value = 0
        $progressbar1.Style = "Continuous"
        $system_Drawing_Size = New-Object System.Drawing.Size
        $system_Drawing_Size.Width = $($f3width - 40)
        $system_Drawing_Size.Height = 20
        $progressbar1.Size = $system_Drawing_Size
        $progressbar1.Left = 10
        $progressbar1.Top = 40
        $form3.controls.add($progressbar1)
        $form3.Show()
        $script:ThoseComputers = $Computers
        $checks = Foreach ($Computer in $Computers) {   
            $i++
            [int]$pct = ($i / $Computers.Count) * 100
            $progressbar1.value = $pct
            #$form3.Text
            $label3.text = "Running CCM Checks on - $Computer   -   $($progressbar1.Value)%"
            Get-CCMPolicy -ComputerName $Computer -CheckPolicy $CheckPolicy -AppEvaluation $AppEvaluation -SWUpdateScanCycle $SWUpdateScanCycle -SWUpdateEvaluation $SWUpdateEvaluation -HardwareInventory $HardwareInventory -ResetSCCMPolicy $ResetSCCMPolicy
            $form3.refresh()
    
        }
    }
    else { $checks = "No Computers were specified." }
    $form3.Hide()
    $result += $checks

    Get-Policy


}

Function Get-Policy {

    Add-Type -AssemblyName System.Windows.Forms, System.Drawing, PresentationFramework

    $tooltip1 = New-Object System.Windows.Forms.ToolTip

 
    [System.Windows.Forms.Application]::EnableVisualStyles()
    #CreatingTheForm
    if ($form1) {
        $form1.close() | out-null
        $form1.dispose() | out-null
    }
    
    # 
    # create results form
    # create form 2
    $form2 = New-Object system.Windows.Forms.Form
    $form2.text = "CCM Policy Results"
    $form2.font = New-Object System.Drawing.Font("Tahoma", 10, [System.Drawing.FontStyle]::Regular)
    $form2.height = 350
    $form2.width = 400
    $CenterScreen = [System.Windows.Forms.FormStartPosition]::CenterScreen;
    $form2.StartPosition = $CenterScreen
    $form2.icon = $global:icon
    $form2.ShowIcon = $True
    $form2.ShowInTaskbar = $True
    $form2.MaximizeBox = $false
    $form2.minimizebox = $false
    $form2.ControlBox = $true
    $form2.ForeColor = [System.Drawing.Color]::FromName("black")

    $form2.formborderstyle = "FixedSingle"
    $formgraphics2 = $form2.creategraphics()
    $form2.add_paint( { set_background })
 
    # create OK and cancel scriptblocks
    $oksb2 = {
        $form2.dialogresult = 2
        $form2.hide()
        Show-Console
        Exit-Form
    }

    # Restartbutton scriptblock
    $restartb2 = {
        $form2.dialogresult = 1
        $form2.hide()
        $script:rerun = $TRUE
        Start-Over
            
    }
 
    #Create Restart Button
    $restartbutton2 = New-Object System.Windows.Forms.Button
    $restartbutton2.Text = "&Back"
    $restartbutton2.font = New-Object System.Drawing.Font("Tahoma", 8, [System.Drawing.FontStyle]::Regular)
    $restartbutton2.height = 25
    $restartbutton2.Width = 75
    $restartbutton2.Top = $($form2.height - $($restartbutton2.Height * 3))
    $restartbutton2.Left = $($form2.width/2) - $($($this.Width + 30 + $this.width)/2)
    $showhelp = $tooltip1.SetToolTip($restartbutton2, "Back")
    $restartbutton2.add_MouseHover($showhelp)
    $restartbutton2.add_click($restartb2)
    $form2.controls.add($restartbutton2)

    #Create Close Button
    $closebutton2 = New-Object System.Windows.Forms.Button
    $closebutton2.text = "&Close"
    $closebutton2.font = New-Object System.Drawing.Font("Tahoma", 8, [System.Drawing.FontStyle]::Regular)
    $closebutton2.height = 25
    $closebutton2.Width = 75
    $closebutton2.top = $($form2.height - $($closebutton2.height *3))
    $closebutton2.Left = $($form2.width/2) - $($($this.Width)/2) + 30
    $showhelp = $tooltip1.settooltip($closebutton2, "Close")
    $closebutton2.add_MouseHover($showhelp)
    $closebutton2.add_click($oksb2)
    $form2.controls.add($closebutton2)

    # Create a new text box
    # create text box
    $text2 = New-Object System.Windows.Forms.TextBox
    $text2.left = 15
    $text2.top = 15
    $text2.height = 250
    $text2.width = ($form2.width - ($text2.left * 2) - 18)
    $text2.BackColor = [System.Drawing.Color]::FromName("Black")
    $text2.ForeColor = [System.Drawing.Color]::FromName("LightGreen")
    $text2.multiline = $True
    $text2.scrollbars = "Vertical"
    $text2.Font = New-Object System.Drawing.Font("Tahoma", 10, [System.Drawing.FontStyle]::Regular)
    $text2.wordwrap = $True
    $showhelp = $tooltip1.SetToolTip($text2, "Results")
    $text2.text = ($result | Out-String).Trim()
    $form2.controls.add($text2)
    $form2.showdialog()

}

$guiactions = "$script:AppEvaluation" + "$script:CheckPolicy" + "$script:SWUpdateScanCycle" + "$script:SWUpdateEvaluation" + "$script:HardwareInventory" + "$script:ResetSCCMPolicy"

if ($script:ComputerName -like $NULL) { $script:ComputerName = $env:COMPUTERNAME }

if ($guiactions -notmatch "True") {
    Start-Over
}
#if ($ComputerName -eq $NULL) {
#    Start-Over
#}
#if ($actions -like $NULL) {}
else {
    Get-CCMPolicy -ComputerName $ComputerName -AppEvaluation $AppEvaluation -CheckPolicy $CheckPolicy -SWUpdateScanCycle $SWUpdateScanCycle -SWUpdateEvaluation $SWUpdateEvaluation -HardwareInventory $HardwareInventory -ResetSCCMPolicy $ResetSCCMPolicy
}


break