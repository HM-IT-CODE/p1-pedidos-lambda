// ═══ Cliente .NET (Framework 4.8) para la API de pedidos del Proyecto 1 ═══════
// Lo usan DOS programas: el Web Forms (DemoFacturacionWebForms) y el WinForms
// (ClientePedidosWinForms). El archivo vive aquí una sola vez y cada .csproj lo
// "enlaza" (<Compile Include=... Link=...>): si lo cambias, cambia en los dos.
//
// La idea que hay que llevarse: un sistema .NET viejo NO necesita reescribirse para
// usar la nube. Para él, la Lambda es solo una URL que recibe y devuelve JSON.
//
//   Web Forms / WinForms ──HTTP POST /pedidos──▶ API Gateway ──▶ Lambda ──▶ DynamoDB + SQS
//
// Sin paquetes NuGet: HttpClient (System.Net.Http) y JavaScriptSerializer
// (System.Web.Extensions) vienen con .NET Framework.
using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using System.Web.Script.Serialization;

namespace P1.Clientes
{
    /// <summary>Un pedido tal como lo devuelve la Lambda (JSON → objeto).</summary>
    public class Pedido
    {
        // JavaScriptSerializer no distingue mayúsculas: "estado" del JSON llena Estado.
        public string Id { get; set; }
        public string Sku { get; set; }
        public int Qty { get; set; }
        public string Estado { get; set; }
        public string Creado { get; set; }
        public string Procesado { get; set; }
    }

    /// <summary>Lo que pasó con una llamada: o trae Datos, o trae Error. Nunca lanza excepción.</summary>
    public class ResultadoApi<T>
    {
        public bool Ok { get; set; }
        public int Status { get; set; }     // código HTTP (0 = ni siquiera hubo respuesta)
        public T Datos { get; set; }
        public string Error { get; set; }
    }

    public static class PedidosApi
    {
        // UN solo HttpClient para toda la aplicación. Crear uno por petición (con `using`)
        // parece más limpio pero agota los puertos del sistema bajo carga ("socket exhaustion").
        private static readonly HttpClient http = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
        private static readonly JavaScriptSerializer json = new JavaScriptSerializer();

        /// <summary>
        /// De dónde sacar la URL de la API. Cada programa la configura al arrancar.
        /// Se pregunta en CADA llamada porque en LocalStack la URL cambia cada vez que se
        /// recrea la infraestructura (el id de la API es nuevo).
        /// </summary>
        public static Func<string> FuenteUrl { get; set; }

        /// <summary>
        /// 1) La URL escrita a mano (Web.config / App.config), si no es "auto".
        /// 2) Si no, el archivo url-api.txt que escribe scripts/levantar-todo.sh después del apply.
        /// </summary>
        public static string ResolverUrl(string configurada, string archivo)
        {
            if (!string.IsNullOrWhiteSpace(configurada) && configurada.Trim() != "auto")
                return configurada.Trim();
            if (!string.IsNullOrWhiteSpace(archivo) && File.Exists(archivo))
            {
                var url = File.ReadAllText(archivo).Trim().Trim('"');
                if (url.Length > 0) return url;
            }
            return null;
        }

        public static string UrlActual()
        {
            return FuenteUrl == null ? null : FuenteUrl();
        }

        /// <summary>POST /pedidos → 201 con el pedido, o 400 con { error }.</summary>
        public static async Task<ResultadoApi<Pedido>> CrearAsync(string sku, int qty)
        {
            var cuerpo = json.Serialize(new { sku = sku, qty = qty }); // {"sku":"X","qty":2}
            using (var contenido = new StringContent(cuerpo, Encoding.UTF8, "application/json"))
            {
                return await Enviar<Pedido>(url => http.PostAsync(url, contenido));
            }
        }

        /// <summary>
        /// GET /pedidos/{id}. OJO: esta ruta todavía NO existe en la API: es el ejercicio
        /// del repaso (Lambda "ver-pedido"). Mientras tanto responde 403/404 y el programa
        /// lo explica. Cuando la crees, esto funciona sin tocar nada aquí.
        /// </summary>
        public static Task<ResultadoApi<Pedido>> VerAsync(string id)
        {
            return Enviar<Pedido>(url => http.GetAsync(url + "/" + Uri.EscapeDataString(id)));
        }

        /// <summary>GET /pedidos (listar). También es ejercicio: Lambda "listar-pedidos" con Scan.</summary>
        public static Task<ResultadoApi<List<Pedido>>> ListarAsync()
        {
            return Enviar<List<Pedido>>(url => http.GetAsync(url));
        }

        /// <summary>true si el error significa "esa ruta no existe en API Gateway".</summary>
        public static bool RutaNoExiste(int status)
        {
            // AWS real responde 403 "Missing Authentication Token" a rutas que no existen
            // (confunde a todo el mundo la primera vez). LocalStack responde 404.
            return status == 403 || status == 404;
        }

        private static async Task<ResultadoApi<T>> Enviar<T>(Func<string, Task<HttpResponseMessage>> llamada)
        {
            var url = UrlActual();
            if (url == null)
                return new ResultadoApi<T> { Error = "No sé la URL de la API. Corre scripts/levantar-todo.sh (escribe url-api.txt) o ponla en el .config" };
            try
            {
                // ConfigureAwait(false): esta librería no necesita volver al hilo de la pantalla.
                // Quien la llama (la página o el formulario) sí vuelve al suyo con su propio await.
                using (var r = await llamada(url).ConfigureAwait(false))
                {
                    var texto = await r.Content.ReadAsStringAsync().ConfigureAwait(false);
                    var res = new ResultadoApi<T> { Status = (int)r.StatusCode, Ok = r.IsSuccessStatusCode };
                    if (res.Ok) res.Datos = json.Deserialize<T>(texto);
                    else res.Error = ExtraerError(texto, res.Status);
                    return res;
                }
            }
            catch (TaskCanceledException)
            {
                return new ResultadoApi<T> { Error = "La API no respondió en 30 s (¿Lambda en arranque en frío? reintenta)" };
            }
            catch (HttpRequestException e)
            {
                var causa = e.InnerException != null ? e.InnerException.Message : e.Message;
                return new ResultadoApi<T> { Error = "No hay conexión con " + url + " (¿LocalStack arriba?): " + causa };
            }
        }

        private static string ExtraerError(string texto, int status)
        {
            try
            {
                var d = json.Deserialize<Dictionary<string, object>>(texto);
                if (d != null && d.ContainsKey("error")) return Convert.ToString(d["error"]);     // nuestra Lambda: { error }
                if (d != null && d.ContainsKey("message")) return Convert.ToString(d["message"]); // API Gateway: { message }
            }
            catch (ArgumentException) { /* no era JSON */ }
            catch (InvalidOperationException) { }
            if (RutaNoExiste(status)) return "esa ruta no existe en la API";
            return texto.Length > 200 ? texto.Substring(0, 200) + "…" : texto;
        }
    }
}
