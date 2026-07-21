/**
 * Alertas del dashboard: vacaciones pendientes y cesados sin liquidación.
 * Resumen = solo conteos; detalle se pide al abrir el modal (evita JSON truncado).
 */
(function () {
    const URL_VACACIONES = '/api/alertas/vacaciones-pendientes';
    const URL_LIQUIDACION = '/api/alertas/liquidacion-cese-pendiente';

    let cacheVacaciones = [];
    let cacheLiquidacion = [];
    let detalleVacCargado = false;
    let detalleLiqCargado = false;

    function el(id) {
        return document.getElementById(id);
    }

    function pluralTrabajador(n) {
        return n === 1 ? 'trabajador' : 'trabajadores';
    }

    function textoVacaciones(n) {
        if (n <= 0) {
            return 'No hay trabajadores próximos a cumplir 30 días acumulados.';
        }
        return `Tiene ${n} ${pluralTrabajador(n)} próximo${n === 1 ? '' : 's'} a cumplir 30 días acumulados.`;
    }

    function textoLiquidacion(n) {
        if (n <= 0) {
            return 'No hay trabajadores cesados pendientes de liquidación.';
        }
        return `Tiene ${n} ${pluralTrabajador(n)} ya cesado${n === 1 ? '' : 's'} y aún no liquidado${n === 1 ? '' : 's'}.`;
    }

    function setCardLoading(cardId, loading) {
        const card = el(cardId);
        if (!card) return;
        card.classList.toggle('alerta-card-loading', loading);
        const spinner = card.querySelector('.alerta-card-spinner');
        if (spinner) spinner.classList.toggle('d-none', !loading);
    }

    function setCardState(cardId, textoId, btnId, count, textoFn, alertClass) {
        const card = el(cardId);
        if (!card) return;
        const texto = el(textoId);
        const btn = el(btnId);
        if (texto) texto.textContent = textoFn(count);
        card.classList.remove('alerta-card-warn', 'alerta-card-danger', 'alerta-card-ok');
        if (count > 0) {
            card.classList.add(alertClass);
        } else {
            card.classList.add('alerta-card-ok');
        }
        if (btn) {
            btn.disabled = count <= 0;
            btn.classList.toggle('d-none', count <= 0);
        }
    }

    function setCardError(textoId, msg) {
        const texto = el(textoId);
        if (texto) texto.textContent = msg;
    }

    function escHtml(s) {
        return String(s == null ? '' : s)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;');
    }

    function estadoPeriodoLabel(v) {
        const s = String(v || '').trim();
        if (s === 'DERECHO_VENCIDO') return 'Derecho vencido';
        if (s === 'ACUMULACION_PREVIA') return 'Acumulación previa';
        return s || '—';
    }

    function renderTablaVacaciones(rows) {
        const tbody = el('tbodyDetalleVacaciones');
        if (!tbody) return;
        if (!rows.length) {
            tbody.innerHTML = '<tr><td colspan="8" class="text-center text-muted py-3">Sin registros</td></tr>';
            return;
        }
        tbody.innerHTML = rows.map((r) => `
            <tr>
                <td>${escHtml(r.empresa)}</td>
                <td>${escHtml(r.documento)}</td>
                <td>${escHtml(r.nombre)}</td>
                <td>${escHtml(r.periodo_vacacional)}</td>
                <td class="text-end">${escHtml(r.dias_acumulados)}</td>
                <td class="text-end">${escHtml(r.dias_gozados)}</td>
                <td>${escHtml(estadoPeriodoLabel(r.estado_periodo))}</td>
                <td>${escHtml(r.fecha_reingreso || '')}</td>
            </tr>
        `).join('');
    }

    function renderTablaLiquidacion(rows) {
        const tbody = el('tbodyDetalleLiquidacion');
        if (!tbody) return;
        if (!rows.length) {
            tbody.innerHTML = '<tr><td colspan="8" class="text-center text-muted py-3">Sin registros</td></tr>';
            return;
        }
        tbody.innerHTML = rows.map((r) => `
            <tr>
                <td>${escHtml(r.empresa)}</td>
                <td>${escHtml(r.documento)}</td>
                <td>${escHtml(r.nombre)}</td>
                <td>${escHtml(r.fecha_ingreso)}</td>
                <td>${escHtml(r.fecha_cese)}</td>
                <td class="text-end">${escHtml(r.dias_desde_cese)}</td>
                <td>${escHtml(r.motivo_cese)}</td>
                <td>${escHtml(r.tipoplanilla || r.tipoplanilla_desc)}</td>
            </tr>
        `).join('');
    }

    async function fetchAlerta(url, detalle) {
        const res = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ detalle: !!detalle }),
        });
        const text = await res.text();
        let data;
        try {
            data = JSON.parse(text);
        } catch (e) {
            throw new Error(
                'Respuesta inválida del servidor'
                + (text && text.length ? ` (${text.length} bytes)` : '')
                + '.'
            );
        }
        if (!res.ok) {
            throw new Error(data.error || 'Error al consultar alertas.');
        }
        return data;
    }

    async function cargarAlertas() {
        setCardLoading('cardAlertaVacaciones', true);
        setCardLoading('cardAlertaLiquidacion', true);
        detalleVacCargado = false;
        detalleLiqCargado = false;
        cacheVacaciones = [];
        cacheLiquidacion = [];

        const results = await Promise.allSettled([
            fetchAlerta(URL_VACACIONES, false),
            fetchAlerta(URL_LIQUIDACION, false),
        ]);

        const vac = results[0];
        const liq = results[1];

        if (vac.status === 'fulfilled') {
            setCardState(
                'cardAlertaVacaciones',
                'textoAlertaVacaciones',
                'btnDetalleVacaciones',
                vac.value.total_trabajadores || 0,
                textoVacaciones,
                'alerta-card-warn'
            );
        } else {
            console.error(vac.reason);
            setCardError(
                'textoAlertaVacaciones',
                (vac.reason && vac.reason.message) || 'No se pudieron cargar las alertas.'
            );
        }

        if (liq.status === 'fulfilled') {
            setCardState(
                'cardAlertaLiquidacion',
                'textoAlertaLiquidacion',
                'btnDetalleLiquidacion',
                liq.value.total_trabajadores || 0,
                textoLiquidacion,
                'alerta-card-danger'
            );
        } else {
            console.error(liq.reason);
            setCardError(
                'textoAlertaLiquidacion',
                (liq.reason && liq.reason.message) || 'No se pudieron cargar las alertas.'
            );
        }

        setCardLoading('cardAlertaVacaciones', false);
        setCardLoading('cardAlertaLiquidacion', false);
    }

    async function cargarDetalleVacaciones() {
        if (detalleVacCargado) return cacheVacaciones;
        const data = await fetchAlerta(URL_VACACIONES, true);
        cacheVacaciones = data.rows || [];
        detalleVacCargado = true;
        return cacheVacaciones;
    }

    async function cargarDetalleLiquidacion() {
        if (detalleLiqCargado) return cacheLiquidacion;
        const data = await fetchAlerta(URL_LIQUIDACION, true);
        cacheLiquidacion = data.rows || [];
        detalleLiqCargado = true;
        return cacheLiquidacion;
    }

    function initModales() {
        const modalVacEl = el('modalDetalleVacaciones');
        const modalLiqEl = el('modalDetalleLiquidacion');
        const modalVac = modalVacEl ? new bootstrap.Modal(modalVacEl) : null;
        const modalLiq = modalLiqEl ? new bootstrap.Modal(modalLiqEl) : null;

        const btnVac = el('btnDetalleVacaciones');
        if (btnVac && modalVac) {
            btnVac.addEventListener('click', async () => {
                const tbody = el('tbodyDetalleVacaciones');
                if (tbody) {
                    tbody.innerHTML = '<tr><td colspan="8" class="text-center text-muted py-3">Cargando...</td></tr>';
                }
                modalVac.show();
                try {
                    const rows = await cargarDetalleVacaciones();
                    renderTablaVacaciones(rows);
                } catch (e) {
                    console.error(e);
                    if (tbody) {
                        tbody.innerHTML =
                            `<tr><td colspan="8" class="text-center text-danger py-3">${escHtml(e.message || 'Error')}</td></tr>`;
                    }
                }
            });
        }

        const btnLiq = el('btnDetalleLiquidacion');
        if (btnLiq && modalLiq) {
            btnLiq.addEventListener('click', async () => {
                const tbody = el('tbodyDetalleLiquidacion');
                if (tbody) {
                    tbody.innerHTML = '<tr><td colspan="8" class="text-center text-muted py-3">Cargando...</td></tr>';
                }
                modalLiq.show();
                try {
                    const rows = await cargarDetalleLiquidacion();
                    renderTablaLiquidacion(rows);
                } catch (e) {
                    console.error(e);
                    if (tbody) {
                        tbody.innerHTML =
                            `<tr><td colspan="8" class="text-center text-danger py-3">${escHtml(e.message || 'Error')}</td></tr>`;
                    }
                }
            });
        }
    }

    document.addEventListener('DOMContentLoaded', () => {
        initModales();
        cargarAlertas();
    });
})();
