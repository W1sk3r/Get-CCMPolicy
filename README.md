# Get-CCMPolicy
SCCM Powershell Policy Tool


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