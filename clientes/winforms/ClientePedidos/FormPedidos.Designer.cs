namespace ClientePedidos
{
    partial class FormPedidos
    {
        private System.ComponentModel.IContainer components = null;

        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null)) components.Dispose();
            base.Dispose(disposing);
        }

        #region Código generado por el Diseñador de Windows Forms

        private void InitializeComponent()
        {
            this.components = new System.ComponentModel.Container();
            this.panelArriba = new System.Windows.Forms.Panel();
            this.lblUrl = new System.Windows.Forms.Label();
            this.lblSku = new System.Windows.Forms.Label();
            this.txtSku = new System.Windows.Forms.TextBox();
            this.lblQty = new System.Windows.Forms.Label();
            this.nudQty = new System.Windows.Forms.NumericUpDown();
            this.btnCrear = new System.Windows.Forms.Button();
            this.btnEstados = new System.Windows.Forms.Button();
            this.btnListar = new System.Windows.Forms.Button();
            this.chkAuto = new System.Windows.Forms.CheckBox();
            this.dgvPedidos = new System.Windows.Forms.DataGridView();
            this.barraEstado = new System.Windows.Forms.StatusStrip();
            this.lblEstado = new System.Windows.Forms.ToolStripStatusLabel();
            this.timerAuto = new System.Windows.Forms.Timer(this.components);
            this.panelArriba.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.nudQty)).BeginInit();
            ((System.ComponentModel.ISupportInitialize)(this.dgvPedidos)).BeginInit();
            this.barraEstado.SuspendLayout();
            this.SuspendLayout();
            //
            // panelArriba
            //
            this.panelArriba.Controls.Add(this.lblUrl);
            this.panelArriba.Controls.Add(this.lblSku);
            this.panelArriba.Controls.Add(this.txtSku);
            this.panelArriba.Controls.Add(this.lblQty);
            this.panelArriba.Controls.Add(this.nudQty);
            this.panelArriba.Controls.Add(this.btnCrear);
            this.panelArriba.Controls.Add(this.btnEstados);
            this.panelArriba.Controls.Add(this.btnListar);
            this.panelArriba.Controls.Add(this.chkAuto);
            this.panelArriba.Dock = System.Windows.Forms.DockStyle.Top;
            this.panelArriba.Height = 78;
            this.panelArriba.Name = "panelArriba";
            //
            // lblUrl
            //
            this.lblUrl.AutoEllipsis = true;
            this.lblUrl.ForeColor = System.Drawing.Color.DimGray;
            this.lblUrl.Location = new System.Drawing.Point(12, 8);
            this.lblUrl.Name = "lblUrl";
            this.lblUrl.Size = new System.Drawing.Size(760, 18);
            this.lblUrl.Text = "API: ...";
            //
            // lblSku / txtSku
            //
            this.lblSku.AutoSize = true;
            this.lblSku.Location = new System.Drawing.Point(12, 42);
            this.lblSku.Name = "lblSku";
            this.lblSku.Text = "SKU";
            this.txtSku.Location = new System.Drawing.Point(48, 39);
            this.txtSku.MaxLength = 40;
            this.txtSku.Name = "txtSku";
            this.txtSku.Size = new System.Drawing.Size(140, 22);
            this.txtSku.Text = "WINFORMS-01";
            //
            // lblQty / nudQty (mínimo 0 a propósito: para ver el 400 de la Lambda)
            //
            this.lblQty.AutoSize = true;
            this.lblQty.Location = new System.Drawing.Point(200, 42);
            this.lblQty.Name = "lblQty";
            this.lblQty.Text = "Cant.";
            this.nudQty.Location = new System.Drawing.Point(242, 39);
            this.nudQty.Minimum = 0;
            this.nudQty.Maximum = 1000;
            this.nudQty.Name = "nudQty";
            this.nudQty.Size = new System.Drawing.Size(60, 22);
            this.nudQty.Value = 1;
            //
            // botones
            //
            this.btnCrear.Location = new System.Drawing.Point(316, 37);
            this.btnCrear.Name = "btnCrear";
            this.btnCrear.Size = new System.Drawing.Size(110, 27);
            this.btnCrear.Text = "Crear pedido";
            this.btnCrear.Click += new System.EventHandler(this.btnCrear_Click);
            this.btnEstados.Location = new System.Drawing.Point(432, 37);
            this.btnEstados.Name = "btnEstados";
            this.btnEstados.Size = new System.Drawing.Size(130, 27);
            this.btnEstados.Text = "Consultar estados";
            this.btnEstados.Click += new System.EventHandler(this.btnEstados_Click);
            this.btnListar.Location = new System.Drawing.Point(568, 37);
            this.btnListar.Name = "btnListar";
            this.btnListar.Size = new System.Drawing.Size(110, 27);
            this.btnListar.Text = "Cargar todos";
            this.btnListar.Click += new System.EventHandler(this.btnListar_Click);
            //
            // chkAuto + timerAuto: refrescar estados cada 5 s
            //
            this.chkAuto.AutoSize = true;
            this.chkAuto.Location = new System.Drawing.Point(688, 42);
            this.chkAuto.Name = "chkAuto";
            this.chkAuto.Text = "cada 5 s";
            this.chkAuto.CheckedChanged += new System.EventHandler(this.chkAuto_CheckedChanged);
            this.timerAuto.Interval = 5000;
            this.timerAuto.Tick += new System.EventHandler(this.timerAuto_Tick);
            //
            // dgvPedidos
            //
            this.dgvPedidos.AllowUserToAddRows = false;
            this.dgvPedidos.AllowUserToDeleteRows = false;
            this.dgvPedidos.AutoSizeColumnsMode = System.Windows.Forms.DataGridViewAutoSizeColumnsMode.Fill;
            this.dgvPedidos.BackgroundColor = System.Drawing.SystemColors.Window;
            this.dgvPedidos.Dock = System.Windows.Forms.DockStyle.Fill;
            this.dgvPedidos.Name = "dgvPedidos";
            this.dgvPedidos.ReadOnly = true;
            this.dgvPedidos.RowHeadersVisible = false;
            this.dgvPedidos.SelectionMode = System.Windows.Forms.DataGridViewSelectionMode.FullRowSelect;
            this.dgvPedidos.CellFormatting += new System.Windows.Forms.DataGridViewCellFormattingEventHandler(this.dgvPedidos_CellFormatting);
            //
            // barraEstado
            //
            this.barraEstado.Items.AddRange(new System.Windows.Forms.ToolStripItem[] { this.lblEstado });
            this.barraEstado.Name = "barraEstado";
            this.lblEstado.Name = "lblEstado";
            this.lblEstado.Spring = true;
            this.lblEstado.TextAlign = System.Drawing.ContentAlignment.MiddleLeft;
            this.lblEstado.Text = "Listo";
            //
            // FormPedidos (el de Fill se agrega PRIMERO: así ocupa lo que dejan los de arriba y abajo)
            //
            this.AutoScaleDimensions = new System.Drawing.SizeF(8F, 16F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(800, 450);
            this.Controls.Add(this.dgvPedidos);
            this.Controls.Add(this.panelArriba);
            this.Controls.Add(this.barraEstado);
            this.Font = new System.Drawing.Font("Segoe UI", 9F);
            this.MinimumSize = new System.Drawing.Size(816, 300);
            this.Name = "FormPedidos";
            this.StartPosition = System.Windows.Forms.FormStartPosition.CenterScreen;
            this.Text = "Pedidos en la nube — Proyecto 1 (Lambda)";
            this.Load += new System.EventHandler(this.FormPedidos_Load);
            this.panelArriba.ResumeLayout(false);
            this.panelArriba.PerformLayout();
            ((System.ComponentModel.ISupportInitialize)(this.nudQty)).EndInit();
            ((System.ComponentModel.ISupportInitialize)(this.dgvPedidos)).EndInit();
            this.barraEstado.ResumeLayout(false);
            this.barraEstado.PerformLayout();
            this.ResumeLayout(false);
            this.PerformLayout();
        }

        #endregion

        private System.Windows.Forms.Panel panelArriba;
        private System.Windows.Forms.Label lblUrl;
        private System.Windows.Forms.Label lblSku;
        private System.Windows.Forms.TextBox txtSku;
        private System.Windows.Forms.Label lblQty;
        private System.Windows.Forms.NumericUpDown nudQty;
        private System.Windows.Forms.Button btnCrear;
        private System.Windows.Forms.Button btnEstados;
        private System.Windows.Forms.Button btnListar;
        private System.Windows.Forms.CheckBox chkAuto;
        private System.Windows.Forms.DataGridView dgvPedidos;
        private System.Windows.Forms.StatusStrip barraEstado;
        private System.Windows.Forms.ToolStripStatusLabel lblEstado;
        private System.Windows.Forms.Timer timerAuto;
    }
}
