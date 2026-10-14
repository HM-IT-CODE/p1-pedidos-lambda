using System;
using System.ComponentModel;
using System.Drawing;
using System.Threading.Tasks;
using System.Windows.Forms;
using P1.Clientes;

namespace ClientePedidos
{
    /// <summary>
    /// WinForms que usa la API de pedidos (Lambda). Compáralo con Pedidos.aspx del Web Forms:
    ///
    ///   Web Forms → RegisterAsyncTask: la petición del navegador espera y luego se dibuja la página.
    ///   WinForms  → "async void" en el Click: la ventana NO se congela mientras la API responde,
    ///               y después del await el código vuelve SOLO al hilo de la ventana
    ///               (por eso se puede tocar dgvPedidos sin Invoke).
    ///
    /// El error clásico en WinForms es el mismo de Web Forms: llamar .Result en un Click
    /// → la ventana se congela para siempre (deadlock). Siempre await.
    /// </summary>
    public partial class FormPedidos : Form
    {
        // BindingList: el DataGridView se entera solo cuando se agregan o quitan filas.
        private readonly BindingList<Pedido> pedidos = new BindingList<Pedido>();
        private bool ocupado;

        public FormPedidos()
        {
            InitializeComponent();
            dgvPedidos.DataSource = pedidos;
        }

        private void FormPedidos_Load(object sender, EventArgs e)
        {
            lblUrl.Text = "API: " + (PedidosApi.UrlActual() ?? "(no encontrada: corre scripts/levantar-todo.sh)");
        }

        private async void btnCrear_Click(object sender, EventArgs e)
        {
            if (string.IsNullOrWhiteSpace(txtSku.Text)) { Estado("Escribe un SKU.", false); return; }
            await Ocupado(async () =>
            {
                var r = await PedidosApi.CrearAsync(txtSku.Text.Trim(), (int)nudQty.Value);
                if (r.Ok)
                {
                    pedidos.Insert(0, r.Datos);
                    Estado("Creado " + r.Datos.Id + " (HTTP " + r.Status + "). procesar-pedido lo tomará de la cola.", true);
                }
                else
                {
                    Estado(r.Status == 0 ? r.Error : "La API respondió " + r.Status + ": " + r.Error, false);
                }
            });
        }

        private async void btnEstados_Click(object sender, EventArgs e)
        {
            await ConsultarEstados();
        }

        private async Task ConsultarEstados()
        {
            if (pedidos.Count == 0) { Estado("No hay pedidos que consultar.", false); return; }
            await Ocupado(async () =>
            {
                foreach (var p in pedidos)
                {
                    var r = await PedidosApi.VerAsync(p.Id);
                    if (r.Ok && r.Datos != null)
                    {
                        p.Estado = r.Datos.Estado;
                        p.Procesado = r.Datos.Procesado;
                    }
                    else
                    {
                        if (PedidosApi.RutaNoExiste(r.Status))
                        {
                            chkAuto.Checked = false;
                            Estado("Falta GET /pedidos/{id} en la API: es tu ejercicio del repaso (Lambda ver-pedido).", false);
                        }
                        else Estado("Error: " + r.Error, false);
                        return;
                    }
                }
                // Pedido no avisa cuando cambia una propiedad (no implementa INotifyPropertyChanged),
                // así que le pedimos a la grilla que vuelva a leer todo.
                pedidos.ResetBindings();
                Estado("Estados actualizados " + DateTime.Now.ToString("HH:mm:ss"), true);
            });
        }

        private async void btnListar_Click(object sender, EventArgs e)
        {
            await Ocupado(async () =>
            {
                var r = await PedidosApi.ListarAsync();
                if (r.Ok && r.Datos != null)
                {
                    pedidos.Clear();
                    foreach (var p in r.Datos) pedidos.Add(p);
                    Estado("Cargados " + r.Datos.Count + " pedidos desde la API.", true);
                }
                else if (PedidosApi.RutaNoExiste(r.Status))
                    Estado("Falta GET /pedidos (listar) en la API: ejercicio del repaso (Lambda listar-pedidos con Scan).", false);
                else
                    Estado("Error: " + r.Error, false);
            });
        }

        private void chkAuto_CheckedChanged(object sender, EventArgs e)
        {
            timerAuto.Enabled = chkAuto.Checked;
        }

        private async void timerAuto_Tick(object sender, EventArgs e)
        {
            if (!ocupado) await ConsultarEstados();
        }

        /// <summary>Colorea la columna Estado: verde PROCESADO, ámbar PENDIENTE.</summary>
        private void dgvPedidos_CellFormatting(object sender, DataGridViewCellFormattingEventArgs e)
        {
            if (dgvPedidos.Columns[e.ColumnIndex].DataPropertyName != "Estado" || e.Value == null) return;
            var estado = e.Value.ToString();
            e.CellStyle.ForeColor = estado == "PROCESADO" ? Color.ForestGreen : estado == "PENDIENTE" ? Color.DarkOrange : Color.Black;
        }

        /// <summary>Desactiva los botones mientras hay una llamada en curso (evita doble clic = doble pedido).</summary>
        private async Task Ocupado(Func<Task> trabajo)
        {
            ocupado = true;
            btnCrear.Enabled = btnEstados.Enabled = btnListar.Enabled = false;
            Cursor = Cursors.WaitCursor;
            try { await trabajo(); }
            finally
            {
                ocupado = false;
                btnCrear.Enabled = btnEstados.Enabled = btnListar.Enabled = true;
                Cursor = Cursors.Default;
            }
        }

        private void Estado(string texto, bool ok)
        {
            lblEstado.Text = texto;
            lblEstado.ForeColor = ok ? Color.ForestGreen : Color.Firebrick;
        }
    }
}
