/**
 * Alertas del dashboard: vacaciones pendientes y cesados sin liquidación.
 * Consolida todas las empresas activas vía API.
 */
(function () {
    const URL_VACACIONES = '/api/alertas/vacaciones-pendientes';
    const URL_LIQUIDACION = '/api/alertas/liquidacion-cese-pendiente';

    let cacheVacaciones = [];
    let cacheLiquidacion = [];

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
            tbody.innerHTML = '<tr><td colspan="7" class="text-center text-muted py-3">Sin registros</td></tr>';
            return;
        }
        tbody.innerHTML = rows.map((r) => `
            <tr>
                <td>${escHtml(r.empresa)}</td>
                <td>${escHtml(r.documento)}</td>
                <td>${escHtml(r.nombre)}</td>
                <td>${escHtml(r.fecha_cese)}</td>
                <td class="text-end">${escHtml(r.dias_desde_cese)}</td>
                <td>${escHtml(r.motivo_cese)}</td>
                <td>${escHtml(r.tipoplanilla || r.tipoplanilla_desc)}</td>
            </tr>
        `).join('');
    }

    async function fetchAlerta(url) {
        const res = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: '{}',
        });
        const data = await res.json();
        if (!res.ok) {
            throw new Error(data.error || 'Error al consultar alertas.');
        }
        return data;
    }

    async function cargarAlertas() {
        setCardLoading('cardAlertaVacaciones', true);
        setCardLoading('cardAlertaLiquidacion', true);
        try {
            const [vac, liq] = await Promise.all([
                fetchAlerta(URL_VACACIONES),
                fetchAlerta(URL_LIQUIDACION),
            ]);
            cacheVacaciones = vac.rows || [];
            cacheLiquidacion = liq.rows || [];
            setCardState(
                'cardAlertaVacaciones',
                'textoAlertaVacaciones',
                'btnDetalleVacaciones',
                vac.total_trabajadores || 0,
                textoVacaciones,
                'alerta-card-warn'
            );
            setCardState(
                'cardAlertaLiquidacion',
                'textoAlertaLiquidacion',
                'btnDetalleLiquidacion',
                liq.total_trabajadores || 0,
                textoLiquidacion,
                'alerta-card-danger'
            );
        } catch (e) {
            console.error(e);
            const msg = e.message || 'No se pudieron cargar las alertas.';
            const tv = el('textoAlertaVacaciones');
            const tl = el('textoAlertaLiquidacion');
            if (tv) tv.textContent = msg;
            if (tl) tl.textContent = msg;
        } finally {
            setCardLoading('cardAlertaVacaciones', false);
            setCardLoading('cardAlertaLiquidacion', false);
        }
    }

    function initModales() {
        const modalVacEl = el('modalDetalleVacaciones');
        const modalLiqEl = el('modalDetalleLiquidacion');
        const modalVac = modalVacEl ? new bootstrap.Modal(modalVacEl) : null;
        const modalLiq = modalLiqEl ? new bootstrap.Modal(modalLiqEl) : null;

        const btnVac = el('btnDetalleVacaciones');
        if (btnVac && modalVac) {
            btnVac.addEventListener('click', () => {
                renderTablaVacaciones(cacheVacaciones);
                modalVac.show();
            });
        }

        const btnLiq = el('btnDetalleLiquidacion');
        if (btnLiq && modalLiq) {
            btnLiq.addEventListener('click', () => {
                renderTablaLiquidacion(cacheLiquidacion);
                modalLiq.show();
            });
        }
    }

    document.addEventListener('DOMContentLoaded', () => {
        initModales();
        cargarAlertas();
    });
})();
