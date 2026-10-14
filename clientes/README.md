# Clientes .NET del Proyecto 1 (Web Forms y WinForms)

Para un sistema .NET Framework 4.8 viejo, la Lambda es **solo una URL que recibe y devuelve JSON**.
No hace falta reescribir nada ni instalar el SDK de AWS.

```
Web Forms (Pedidos.aspx) ─┐
                          ├─ HTTP POST /pedidos ─▶ API Gateway ─▶ Lambda crear-pedido ─▶ DynamoDB + SQS
WinForms (ClientePedidos) ┘                                         └─▶ (cola) Lambda procesar-pedido
```

| Pieza | Dónde |
|---|---|
| Cliente compartido (`HttpClient` + `JavaScriptSerializer`, sin NuGet) | `dotnet/PedidosApi.cs` |
| Página Web Forms | `D:\2026\LABS\DemoFacturacionWebForms\DemoFacturacion\Pedidos.aspx` (menú "Pedidos (nube)") |
| WinForms | `winforms/ClientePedidos.sln` |

Los dos proyectos **enlazan** el mismo `PedidosApi.cs` (`<Compile Include="..." Link="..."/>` en el .csproj).
Si lo cambias, cambia en los dos.

## De dónde sacan la URL

`Web.config` / `App.config` → `PedidosApiUrl`:
- `auto`: lee `p1-pedidos-lambda/url-api.txt`, que escribe `scripts/levantar-todo.sh` después de cada apply.
  En LocalStack la URL cambia cada vez porque la API recibe un id nuevo.
- Una URL fija: para AWS real, pega la `url_pedidos` que muestra `sh scripts/aws-real.sh apply`.

## Correrlos

1. LocalStack arriba: `wsl -d Ubuntu -u root -- sh /mnt/d/2026/LABS/p1-pedidos-lambda/scripts/levantar-todo.sh`
2. Web Forms: abre `DemoFacturacion.sln` en VS 2022 → F5 → menú **Pedidos (nube)**.
   Esta página no necesita SQL Server.
3. WinForms: abre `winforms/ClientePedidos.sln` → F5.

Pruebas automáticas, sin apretar botones (8 oct):
- `powershell -ExecutionPolicy Bypass -File D:\2026\LABS\DemoFacturacionWebForms\probar-pedidos.ps1`
  (con IIS Express corriendo): crear → 201, qty 0 → 400, FALLA → 201, consultar → explica que falta GET.
- `powershell -ExecutionPolicy Bypass -File D:\2026\LABS\p1-pedidos-lambda\clientes\winforms\probar-winforms.ps1`:
  abre la ventana, aprieta los botones y lee la barra de estado.

## Lo que hay que entender (para estudiar)

1. **Nunca `.Result` ni `.Wait()`** en una página o un formulario. Deja la app colgada (deadlock).
   - Web Forms: `Async="true"` en el `.aspx` + `RegisterAsyncTask(new PageAsyncTask(async () => ...))`.
   - WinForms: `private async void btnCrear_Click(...)` + `await`. Después del await se vuelve solo al hilo de la ventana.
2. **Un solo `HttpClient` estático**. Crear uno por petición agota los puertos.
3. **`ConfigureAwait(false)` en la librería**, no en la pantalla: la librería no necesita el hilo de la UI.
4. **Errores como datos**: `ResultadoApi<T>` trae `Ok`, `Status` y `Error`; la pantalla decide cómo mostrarlo.
   - Sin conexión → `Status = 0`.
   - 400 → el mensaje de la Lambda.
   - 403 o 404 → la ruta no existe.
5. **AWS real responde 403 "Missing Authentication Token"** a una ruta que no existe, no 404.
   Confunde a todos la primera vez.

## Tu ejercicio (repaso)

Los botones **Consultar estados** (Web Forms y WinForms) y **Cargar todos** (WinForms) ya llaman a
`GET /pedidos/{id}` y `GET /pedidos`, pero esas rutas **no existen todavía en la API**. Te toca crearlas:

1. `src/ver-pedido.ts`: un `GetCommand` por id → 200 con el pedido, o 404.
2. `src/listar-pedidos.ts`: un `ScanCommand` → 200 con la lista.
   Ojo: Scan lee toda la tabla; sirve para el lab, pero no para millones de filas.
3. `scripts/build.mjs`: agrega las dos funciones a la lista.
4. `infra/`:
   - la Lambda y su zip;
   - el recurso `{id}` colgando de `/pedidos`;
   - los métodos `GET` con su integración `AWS_PROXY`;
   - el `lambda_permission`;
   - agregar los nuevos ids a los `triggers` del deployment;
   - permiso `dynamodb:Scan` en la política.
5. Pruebas Jest para las dos (copia el estilo de `test/unit/crear-pedido.test.ts`).

Cuando estén, los botones funcionan **sin tocar nada de .NET**. Eso es justamente lo que se gana separando el cliente de la API.
