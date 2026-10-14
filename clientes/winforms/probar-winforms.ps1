# Prueba automática del WinForms con UI Automation (lo que usan los lectores de pantalla):
# abre la ventana, aprieta "Crear pedido" y lee la barra de estado. Luego la cierra.
#   powershell -ExecutionPolicy Bypass -File probar-winforms.ps1
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
$exe = Join-Path $PSScriptRoot "ClientePedidos\bin\Debug\ClientePedidos.exe"
$p = Start-Process $exe -PassThru
Start-Sleep 3
$raiz = [System.Windows.Automation.AutomationElement]::RootElement
$cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, $p.Id)
$ventana = $raiz.FindFirst([System.Windows.Automation.TreeScope]::Children, $cond)
Add-Type @"
using System; using System.Runtime.InteropServices;
public static class Win32 { [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l); }
"@
function Buscar($nombre) {
  $n = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $nombre)
  $ventana.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $n)
}
# BM_CLICK (0x00F5) = el mismo mensaje que Windows le manda a un botón cuando lo aprietas.
# (Desde una sesión sin escritorio activo, UI Automation ve los botones como "Pane" sin Invoke.)
function Apretar($nombre) {
  $h = [IntPtr](Buscar $nombre).Current.NativeWindowHandle
  [void][Win32]::PostMessage($h, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero)
  Start-Sleep 4
}
function Barra {
  $c = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::StatusBar)
  $b = $ventana.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $c)
  $t = $b.FindFirst([System.Windows.Automation.TreeScope]::Children, [System.Windows.Automation.Condition]::TrueCondition)
  $t.Current.Name
}
"Ventana: " + $ventana.Current.Name
Apretar "Crear pedido";       "1) crear      -> " + (Barra)
Apretar "Consultar estados";  "2) estados    -> " + (Barra)
Apretar "Cargar todos";       "3) listar     -> " + (Barra)
Stop-Process -Id $p.Id
