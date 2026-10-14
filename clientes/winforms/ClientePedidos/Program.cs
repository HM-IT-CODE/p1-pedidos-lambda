using System;
using System.Configuration;
using System.Windows.Forms;
using P1.Clientes;

namespace ClientePedidos
{
    internal static class Program
    {
        [STAThread]
        private static void Main()
        {
            // La misma regla que el Web Forms: URL a mano en App.config, o "auto" = url-api.txt
            PedidosApi.FuenteUrl = () => PedidosApi.ResolverUrl(
                ConfigurationManager.AppSettings["PedidosApiUrl"],
                ConfigurationManager.AppSettings["PedidosApiUrlArchivo"]);

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new FormPedidos());
        }
    }
}
