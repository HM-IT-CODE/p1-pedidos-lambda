# Herramienta de depuración: lista lo que UI Automation ve de la ventana (tipos, nombres, ids).
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
$exe = Join-Path $PSScriptRoot "ClientePedidos\bin\Debug\ClientePedidos.exe"
$p = Start-Process $exe -PassThru
Start-Sleep 3
$raiz = [System.Windows.Automation.AutomationElement]::RootElement
$cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, $p.Id)
$ventana = $raiz.FindFirst([System.Windows.Automation.TreeScope]::Children, $cond)
$todos = $ventana.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
foreach ($e in $todos) { $e.Current.ControlType.ProgrammaticName + " | " + $e.Current.Name + " | " + $e.Current.AutomationId }
Stop-Process -Id $p.Id
