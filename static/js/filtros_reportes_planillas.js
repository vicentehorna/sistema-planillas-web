/**
 * Persistencia autónoma por reporte (localStorage).
 * IDs: cboCompania, cboTipoPlanilla, cboProceso, cboPeriodo; opcional cboTrabajador (solo Promedio).
 */
(function (global) {
    const STORAGE_KEY_RESUMEN_TOTAL = 'filtros_resumen_total';
    const STORAGE_KEY_PROMEDIO_LIQ = 'filtros_promedio_liq';
    const STORAGE_KEY_PLANILLA_VERTICAL = 'filtros_planilla_vertical';
    const STORAGE_KEY_PLANILLA_CONSOLIDADA = 'filtros_planilla_consolidada';
    const STORAGE_KEY_VACACIONES_DETALLE = 'filtros_vacaciones_detalle';
    const STORAGE_KEY_SALDO_VACACIONES = 'filtros_saldo_vacaciones';
    const STORAGE_KEY_DESCANSOS_MEDICOS_DETALLE = 'filtros_descansos_medicos_detalle';
    const STORAGE_KEY_PROCESAR_PLANILLA = 'filtros_procesar_planilla';
    const STORAGE_KEY_LOG_CALCULO = 'filtros_log_calculo';
    const STORAGE_KEY_TRABAJADORES = 'filtros_trabajadores';
    const STORAGE_KEY_TELECREDITO = 'filtros_pago_haberes_telecredito';
    const STORAGE_KEY_INTERBANK = 'filtros_pago_haberes_interbank';
    const STORAGE_KEY_CONTINENTAL = 'filtros_pago_haberes_continental';
    const STORAGE_KEY_BANBIF = 'filtros_pago_haberes_banbif';
    const STORAGE_KEY_LISTADO_PAGOS = 'filtros_listado_pagos';
    const STORAGE_KEY_ASIGNACION_CONCEPTOS = 'filtros_asignacion_conceptos';
    const STORAGE_KEY_REGISTRO_VACACIONES = 'filtros_registro_vacaciones';
    const STORAGE_KEY_REGISTRO_DESCANSOS = 'filtros_registro_descansos_medicos';
    const STORAGE_KEY_APERTURAR_PERIODOS = 'filtros_aperturar_periodos';
    const STORAGE_KEY_GENERAR_BOLETAS = 'filtros_generar_boletas';
    const STORAGE_KEY_CERTIFICADO_TRABAJO = 'filtros_certificado_trabajo';
    const STORAGE_KEY_CERTIFICADO_RETIRO_CTS = 'filtros_certificado_retiro_cts';
    const STORAGE_KEY_FORMATO_LIQUIDACION = 'filtros_formato_liquidacion';
    const STORAGE_KEY_FORMATO_UTILIDADES = 'filtros_formato_utilidades';
    const STORAGE_KEY_CERTIFICADO_QUINTA = 'filtros_certificado_quinta';
    const STORAGE_KEY_CALCULO_QUINTA_TRAB = 'filtros_calculo_quinta_trabajador';
    const STORAGE_KEY_PLANILLA_POR_CONCEPTOS = 'filtros_planilla_por_conceptos';

    function val(id) {
        const el = document.getElementById(id);
        return el && el.value != null ? String(el.value).trim() : '';
    }

    function optionExists(select, value) {
        if (!select || value === '' || value == null) return false;
        const v = String(value).trim();
        return Array.prototype.some.call(select.options, (o) => String(o.value).trim() === v);
    }

    async function obtenerPeriodoActivo(cia, payrolltype, processtype) {
        try {
            const url = `/api/selectores/periodo-activo?cia=${encodeURIComponent(cia)}&payrolltype=${encodeURIComponent(payrolltype)}&processtype=${encodeURIComponent(processtype)}`;
            const res = await fetch(url);
            const data = await res.json();
            return data && data.prperiod != null ? String(data.prperiod).trim() : '';
        } catch (e) {
            console.error(e);
            return '';
        }
    }

    /**
     * Carga periodos del proceso y selecciona el preferido o, si no hay, el activo (PR_ProcessControl).
     * @param {string} periodoPreferido — valor guardado en filtros; vacío usa periodo activo.
     */
    async function poblarPeriodosConActivo(cia, payrolltype, processtype, selectElement, poblarSelect, periodoPreferido) {
        if (!selectElement || typeof poblarSelect !== 'function') return;
        await poblarSelect(
            `/api/selectores/periodos?cia=${encodeURIComponent(cia)}&payrolltype=${encodeURIComponent(payrolltype)}&processtype=${encodeURIComponent(processtype)}`,
            selectElement
        );
        let periodo = periodoPreferido != null ? String(periodoPreferido).trim() : '';
        if (!periodo) {
            periodo = await obtenerPeriodoActivo(cia, payrolltype, processtype);
        }
        if (periodo && optionExists(selectElement, periodo)) {
            selectElement.value = periodo;
        }
    }

    async function obtenerConceptoNeto(cia) {
        try {
            const url = `/api/selectores/concepto-neto?cia=${encodeURIComponent(cia)}`;
            const res = await fetch(url);
            const data = await res.json();
            return data && data.concept != null ? String(data.concept).trim() : '';
        } catch (e) {
            console.error(e);
            return '';
        }
    }

    /**
     * Carga conceptos de la compañía y selecciona el preferido o, si no hay, Neto a recibir (FormulaCode NETO).
     * @param {string} conceptoPreferido — valor guardado en filtros; vacío usa concepto NETO.
     */
    async function poblarConceptosConNeto(cia, selectElement, poblarSelect, conceptoPreferido) {
        if (!selectElement || typeof poblarSelect !== 'function') return;
        await poblarSelect(
            `/api/selectores/conceptos?cia=${encodeURIComponent(cia)}`,
            selectElement
        );
        let concepto = conceptoPreferido != null ? String(conceptoPreferido).trim() : '';
        if (!concepto) {
            concepto = await obtenerConceptoNeto(cia);
        }
        if (concepto && optionExists(selectElement, concepto)) {
            selectElement.value = concepto;
        }
    }

    /**
     * @param {string} storageKey
     * @param {boolean} incluyeEmpleado
     * @param {boolean} incluyeBancoHaberes
     */
    function restaurarFechaIngresoDesdeFiltros(filtros) {
        const chkFechaIngreso = document.getElementById('chkFechaIngreso');
        const txtFechaIngresoDesde = document.getElementById('txtFechaIngresoDesde');
        const txtFechaIngresoHasta = document.getElementById('txtFechaIngresoHasta');
        const usarRango = filtros && filtros.fechaIngresoActivo === true;
        if (chkFechaIngreso) {
            chkFechaIngreso.checked = usarRango;
        }
        if (txtFechaIngresoDesde) {
            txtFechaIngresoDesde.disabled = !usarRango;
            txtFechaIngresoDesde.value = usarRango && filtros.fechaIngresoDesde
                ? String(filtros.fechaIngresoDesde).trim()
                : '';
        }
        if (txtFechaIngresoHasta) {
            txtFechaIngresoHasta.disabled = !usarRango;
            txtFechaIngresoHasta.value = usarRango && filtros.fechaIngresoHasta
                ? String(filtros.fechaIngresoHasta).trim()
                : '';
        }
    }

    function crearPersistenciaResumenTotal() {
        function guardar() {
            try {
                const estado = {
                    cia: val('cboCompania'),
                    periodo: val('cboPeriodo'),
                    timestamp: Date.now()
                };
                localStorage.setItem(STORAGE_KEY_RESUMEN_TOTAL, JSON.stringify(estado));
            } catch (e) {
                console.warn('filtros resumen total: no se pudo guardar', e);
            }
        }

        function leer() {
            try {
                const raw = localStorage.getItem(STORAGE_KEY_RESUMEN_TOTAL);
                if (!raw) return null;
                const o = JSON.parse(raw);
                if (!o || typeof o !== 'object') return null;
                return o;
            } catch (e) {
                return null;
            }
        }

        async function aplicarRestauracionCascada(opts) {
            if (!opts || typeof opts.poblarSelect !== 'function') return false;
            const { poblarSelect } = opts;
            const filtros = leer();
            if (!filtros || !filtros.cia) return false;

            const cboCia = document.getElementById('cboCompania');
            const cboPer = document.getElementById('cboPeriodo');
            if (!cboCia || !cboPer) return false;

            const cia = String(filtros.cia).trim();
            if (!optionExists(cboCia, cia)) return false;
            cboCia.value = cia;

            await poblarSelect(`/api/selectores/periodos-plame?cia=${encodeURIComponent(cia)}`, cboPer);
            const periodo = filtros.periodo != null ? String(filtros.periodo).trim() : '';
            if (periodo && optionExists(cboPer, periodo)) {
                cboPer.value = periodo;
            } else if (cboPer.options.length > 1) {
                // periodos-plame: primera opción útil (después del placeholder)
                const primera = Array.from(cboPer.options).find((o) => String(o.value || '').trim());
                if (primera) cboPer.value = primera.value;
            }
            guardar();
            return true;
        }

        function registrarGuardadoEnCambio() {
            ['cboCompania', 'cboPeriodo'].forEach((id) => {
                const el = document.getElementById(id);
                if (el) el.addEventListener('change', guardar);
            });
        }

        return {
            STORAGE_KEY: STORAGE_KEY_RESUMEN_TOTAL,
            guardar,
            leer,
            aplicarRestauracionCascada,
            registrarGuardadoEnCambio
        };
    }

    function crearPersistenciaReporte(storageKey, incluyeEmpleado, incluyeBancoHaberes, incluyeFechaIngreso, incluyeUnidad) {
        function guardar() {
            try {
                const estado = {
                    cia: val('cboCompania'),
                    payroll: val('cboTipoPlanilla'),
                    proceso: val('cboProceso'),
                    periodo: val('cboPeriodo'),
                    timestamp: Date.now()
                };
                if (incluyeEmpleado) {
                    estado.person = val('cboTrabajador');
                }
                if (incluyeBancoHaberes) {
                    estado.salarybank = val('cboBancoHaberes');
                }
                if (incluyeFechaIngreso) {
                    estado.fechaIngresoActivo = !!document.getElementById('chkFechaIngreso')?.checked;
                    estado.fechaIngresoDesde = val('txtFechaIngresoDesde');
                    estado.fechaIngresoHasta = val('txtFechaIngresoHasta');
                }
                if (incluyeUnidad) {
                    estado.repunit = val('cboUnidad') || '0';
                }
                localStorage.setItem(storageKey, JSON.stringify(estado));
            } catch (e) {
                console.warn('filtros reporte: no se pudo guardar', e);
            }
        }

        function leer() {
            try {
                const raw = localStorage.getItem(storageKey);
                if (!raw) return null;
                const o = JSON.parse(raw);
                if (!o || typeof o !== 'object') return null;
                return o;
            } catch (e) {
                return null;
            }
        }

        /**
         * @param {{ poblarSelect: (url: string, el: HTMLElement) => Promise<void> }} opts
         */
        async function aplicarRestauracionCascada(opts) {
            if (!opts || typeof opts.poblarSelect !== 'function') return false;

            const { poblarSelect, poblarBancosHaberes, cargarTrabajadores, cargarUnidades } = opts;
            const filtros = leer();
            if (!filtros || !filtros.cia) return false;

            const cboCia = document.getElementById('cboCompania');
            const cboPt = document.getElementById('cboTipoPlanilla');
            const cboProc = document.getElementById('cboProceso');
            const cboPer = document.getElementById('cboPeriodo');
            if (!cboCia || !cboPt || !cboProc || !cboPer) return false;

            const cia = String(filtros.cia).trim();
            if (!optionExists(cboCia, cia)) return false;
            cboCia.value = cia;

            if (incluyeUnidad && typeof cargarUnidades === 'function') {
                await cargarUnidades();
                const cboUnidad = document.getElementById('cboUnidad');
                if (cboUnidad) {
                    const repunit = filtros.repunit != null ? String(filtros.repunit).trim() : '0';
                    if (repunit && optionExists(cboUnidad, repunit)) {
                        cboUnidad.value = repunit;
                    } else if (optionExists(cboUnidad, '0')) {
                        cboUnidad.value = '0';
                    }
                }
            }

            async function cargarEmpleadoSelect() {
                if (!incluyeEmpleado) return;
                const cboTra = document.getElementById('cboTrabajador');
                if (!cboTra) return;
                const ciaActual = String(cboCia.value || cia || '').trim();
                if (!ciaActual) return;
                if (typeof cargarTrabajadores === 'function') {
                    await cargarTrabajadores();
                } else {
                    await poblarSelect(`/api/selectores/trabajadores?cia=${encodeURIComponent(ciaActual)}`, cboTra);
                }
                const person = filtros.person != null ? String(filtros.person).trim() : '';
                if (person && optionExists(cboTra, person)) {
                    cboTra.value = person;
                }
            }

            if (incluyeBancoHaberes && typeof poblarBancosHaberes === 'function') {
                await poblarBancosHaberes(cia);
                const cboBanco = document.getElementById('cboBancoHaberes');
                if (cboBanco) {
                    let salarybank = filtros.salarybank != null ? String(filtros.salarybank).trim() : '';
                    if (salarybank === '0') salarybank = '';
                    if (salarybank === '') {
                        cboBanco.value = '';
                    } else if (optionExists(cboBanco, salarybank)) {
                        cboBanco.value = salarybank;
                    } else {
                        cboBanco.value = '';
                    }
                }
            }

            await poblarSelect(`/api/selectores/planillas?cia=${encodeURIComponent(cia)}`, cboPt);

            const payroll = filtros.payroll != null ? String(filtros.payroll).trim() : '';
            if (!payroll || !optionExists(cboPt, payroll)) {
                await cargarEmpleadoSelect();
                guardar();
                return true;
            }
            cboPt.value = payroll;

            await poblarSelect(
                `/api/selectores/procesos?cia=${encodeURIComponent(cia)}&payrolltype=${encodeURIComponent(payroll)}`,
                cboProc
            );

            const proceso = filtros.proceso != null ? String(filtros.proceso).trim() : '';
            if (!proceso || !optionExists(cboProc, proceso)) {
                await cargarEmpleadoSelect();
                guardar();
                return true;
            }
            cboProc.value = proceso;

            await poblarSelect(
                `/api/selectores/periodos?cia=${encodeURIComponent(cia)}&payrolltype=${encodeURIComponent(payroll)}&processtype=${encodeURIComponent(proceso)}`,
                cboPer
            );

            const periodo = filtros.periodo != null ? String(filtros.periodo).trim() : '';
            if (periodo && optionExists(cboPer, periodo)) {
                cboPer.value = periodo;
            }

            await cargarEmpleadoSelect();

            if (incluyeFechaIngreso) {
                restaurarFechaIngresoDesdeFiltros(filtros);
            }

            guardar();
            return true;
        }

        function registrarGuardadoEnCambio() {
            ['cboCompania', 'cboTipoPlanilla', 'cboProceso', 'cboPeriodo'].forEach((id) => {
                const el = document.getElementById(id);
                if (el) el.addEventListener('change', guardar);
            });
            if (incluyeEmpleado) {
                const t = document.getElementById('cboTrabajador');
                if (t) t.addEventListener('change', guardar);
            }
            if (incluyeBancoHaberes) {
                const b = document.getElementById('cboBancoHaberes');
                if (b) b.addEventListener('change', guardar);
            }
            if (incluyeFechaIngreso) {
                const chk = document.getElementById('chkFechaIngreso');
                if (chk) chk.addEventListener('change', guardar);
                ['txtFechaIngresoDesde', 'txtFechaIngresoHasta'].forEach((id) => {
                    const el = document.getElementById(id);
                    if (el) el.addEventListener('change', guardar);
                });
            }
            if (incluyeUnidad) {
                const u = document.getElementById('cboUnidad');
                if (u) u.addEventListener('change', guardar);
            }
        }

        return {
            STORAGE_KEY: storageKey,
            guardar,
            leer,
            aplicarRestauracionCascada,
            registrarGuardadoEnCambio
        };
    }

    function crearPersistenciaReporteConsolidada(storageKey, incluyeEmpleado, incluyeBancoHaberes, incluyeFechaIngreso, incluyeUnidad) {
        function guardar() {
            try {
                const estado = {
                    payroll: val('cboTipoPlanilla'),
                    proceso: val('cboProceso'),
                    periodo: val('cboPeriodo'),
                    timestamp: Date.now()
                };
                if (incluyeEmpleado) {
                    estado.person = val('cboTrabajador');
                }
                if (incluyeBancoHaberes) {
                    estado.salarybank = val('cboBancoHaberes');
                }
                if (incluyeFechaIngreso) {
                    estado.fechaIngresoActivo = !!document.getElementById('chkFechaIngreso')?.checked;
                    estado.fechaIngresoDesde = val('txtFechaIngresoDesde');
                    estado.fechaIngresoHasta = val('txtFechaIngresoHasta');
                }
                if (incluyeUnidad) {
                    estado.repunit = val('cboUnidad') || '0';
                }
                localStorage.setItem(storageKey, JSON.stringify(estado));
            } catch (e) {
                console.warn('filtros reporte consolidada: no se pudo guardar', e);
            }
        }

        function leer() {
            try {
                const raw = localStorage.getItem(storageKey);
                if (!raw) return null;
                const o = JSON.parse(raw);
                if (!o || typeof o !== 'object') return null;
                return o;
            } catch (e) {
                return null;
            }
        }

        async function aplicarRestauracionCascada(opts) {
            if (!opts || typeof opts.poblarSelect !== 'function') return false;

            const { poblarSelect, poblarBancosHaberes, cargarUnidades } = opts;
            const filtros = leer();
            if (!filtros) return false;

            const cboPt = document.getElementById('cboTipoPlanilla');
            const cboProc = document.getElementById('cboProceso');
            const cboPer = document.getElementById('cboPeriodo');
            if (!cboPt || !cboProc || !cboPer) return false;

            if (incluyeUnidad && typeof cargarUnidades === 'function') {
                await cargarUnidades();
                const cboUnidad = document.getElementById('cboUnidad');
                if (cboUnidad) {
                    const repunit = filtros.repunit != null ? String(filtros.repunit).trim() : '0';
                    if (repunit && optionExists(cboUnidad, repunit)) {
                        cboUnidad.value = repunit;
                    } else if (optionExists(cboUnidad, '0')) {
                        cboUnidad.value = '0';
                    }
                }
            }

            await poblarSelect('/api/selectores/planillas-consolidada', cboPt);

            const payroll = filtros.payroll != null ? String(filtros.payroll).trim() : '';
            if (!payroll || !optionExists(cboPt, payroll)) {
                guardar();
                return true;
            }
            cboPt.value = payroll;

            if (incluyeBancoHaberes && typeof poblarBancosHaberes === 'function') {
                await poblarBancosHaberes();
                const cboBanco = document.getElementById('cboBancoHaberes');
                if (cboBanco) {
                    let salarybank = filtros.salarybank != null ? String(filtros.salarybank).trim() : '';
                    if (salarybank === '0') salarybank = '';
                    if (salarybank === '') {
                        cboBanco.value = '';
                    } else if (optionExists(cboBanco, salarybank)) {
                        cboBanco.value = salarybank;
                    } else {
                        cboBanco.value = '';
                    }
                }
            }

            await poblarSelect(
                `/api/selectores/procesos-consolidada?payroll_desc=${encodeURIComponent(payroll)}`,
                cboProc
            );

            const proceso = filtros.proceso != null ? String(filtros.proceso).trim() : '';
            if (!proceso || !optionExists(cboProc, proceso)) {
                guardar();
                return true;
            }
            cboProc.value = proceso;

            await poblarSelect(
                `/api/selectores/periodos-consolidada?payroll_desc=${encodeURIComponent(payroll)}&proceso_desc=${encodeURIComponent(proceso)}`,
                cboPer
            );

            const periodo = filtros.periodo != null ? String(filtros.periodo).trim() : '';
            if (periodo && optionExists(cboPer, periodo)) {
                cboPer.value = periodo;
            }

            if (incluyeEmpleado) {
                const cboTra = document.getElementById('cboTrabajador');
                if (cboTra) {
                    await poblarSelect('/api/selectores/trabajadores-consolidada', cboTra);
                    const person = filtros.person != null ? String(filtros.person).trim() : '';
                    if (person && optionExists(cboTra, person)) {
                        cboTra.value = person;
                    }
                }
            }

            if (incluyeFechaIngreso) {
                restaurarFechaIngresoDesdeFiltros(filtros);
            }

            guardar();
            return true;
        }

        function registrarGuardadoEnCambio() {
            ['cboTipoPlanilla', 'cboProceso', 'cboPeriodo'].forEach((id) => {
                const el = document.getElementById(id);
                if (el) el.addEventListener('change', guardar);
            });
            if (incluyeEmpleado) {
                const t = document.getElementById('cboTrabajador');
                if (t) t.addEventListener('change', guardar);
            }
            if (incluyeBancoHaberes) {
                const b = document.getElementById('cboBancoHaberes');
                if (b) b.addEventListener('change', guardar);
            }
            if (incluyeFechaIngreso) {
                const chk = document.getElementById('chkFechaIngreso');
                if (chk) chk.addEventListener('change', guardar);
                ['txtFechaIngresoDesde', 'txtFechaIngresoHasta'].forEach((id) => {
                    const el = document.getElementById(id);
                    if (el) el.addEventListener('change', guardar);
                });
            }
            if (incluyeUnidad) {
                const u = document.getElementById('cboUnidad');
                if (u) u.addEventListener('change', guardar);
            }
        }

        return {
            STORAGE_KEY: storageKey,
            guardar,
            leer,
            aplicarRestauracionCascada,
            registrarGuardadoEnCambio
        };
    }

    function valHidden(id) {
        const el = document.getElementById(id);
        return el && el.value != null ? String(el.value).trim() : '';
    }

    function crearPersistenciaProcesarPlanilla() {
        function guardar() {
            try {
                const seleccionPersonas = [];
                document.querySelectorAll('.check-trabajador:checked').forEach((c) => {
                    seleccionPersonas.push(String(c.value).trim());
                });
                const estado = {
                    cia: val('cboCompania'),
                    payroll: val('cboTipoPlanilla'),
                    proceso: val('cboProcesoCalculo'),
                    cesados: val('cboCesados'),
                    repunit: val('cboUnidad'),
                    periodo: valHidden('hidPeriodoCalculo'),
                    seleccionPersonas: seleccionPersonas,
                    timestamp: Date.now()
                };
                localStorage.setItem(STORAGE_KEY_PROCESAR_PLANILLA, JSON.stringify(estado));
            } catch (e) {
                console.warn('filtros procesar planilla: no se pudo guardar', e);
            }
        }

        function leer() {
            try {
                const raw = localStorage.getItem(STORAGE_KEY_PROCESAR_PLANILLA);
                if (!raw) return null;
                const o = JSON.parse(raw);
                if (!o || typeof o !== 'object') return null;
                return o;
            } catch (e) {
                return null;
            }
        }

        function registrarGuardadoEnCambio() {
            ['cboCompania', 'cboTipoPlanilla', 'cboProcesoCalculo', 'cboCesados', 'cboUnidad'].forEach((id) => {
                const el = document.getElementById(id);
                if (el) el.addEventListener('change', guardar);
            });
            const chkAll = document.getElementById('checkAll');
            if (chkAll) chkAll.addEventListener('change', guardar);
            const tbody = document.getElementById('tbodyTrabajadores');
            if (tbody) {
                tbody.addEventListener('change', function (e) {
                    const t = e.target;
                    if (t && t.classList && t.classList.contains('check-trabajador')) guardar();
                });
            }
        }

        return {
            STORAGE_KEY: STORAGE_KEY_PROCESAR_PLANILLA,
            guardar,
            leer,
            registrarGuardadoEnCambio
        };
    }

    function crearPersistenciaVacacionesDetalle() {
        function guardar() {
            try {
                const estado = {
                    cia: val('cboCompania'),
                    payroll: val('cboTipoPlanilla'),
                    periodo: val('cboPeriodo'),
                    person: val('cboTrabajador'),
                    timestamp: Date.now()
                };
                localStorage.setItem(STORAGE_KEY_VACACIONES_DETALLE, JSON.stringify(estado));
            } catch (e) {
                console.warn('filtros vacaciones detalle: no se pudo guardar', e);
            }
        }

        function leer() {
            try {
                const raw = localStorage.getItem(STORAGE_KEY_VACACIONES_DETALLE);
                if (!raw) return null;
                const o = JSON.parse(raw);
                if (!o || typeof o !== 'object') return null;
                return o;
            } catch (e) {
                return null;
            }
        }

        async function aplicarRestauracionCascada(opts) {
            if (!opts || typeof opts.poblarSelect !== 'function') return false;

            const { poblarSelect, poblarPeriodoVacaciones } = opts;
            const filtros = leer();
            if (!filtros || !filtros.cia) return false;

            const cboCia = document.getElementById('cboCompania');
            const cboPt = document.getElementById('cboTipoPlanilla');
            const cboPer = document.getElementById('cboPeriodo');
            if (!cboCia || !cboPt || !cboPer) return false;

            const cia = String(filtros.cia).trim();
            if (!optionExists(cboCia, cia)) return false;
            cboCia.value = cia;

            await poblarSelect(`/api/selectores/planillas?cia=${encodeURIComponent(cia)}`, cboPt);

            const payroll = filtros.payroll != null ? String(filtros.payroll).trim() : '';
            if (!payroll || !optionExists(cboPt, payroll)) {
                guardar();
                return true;
            }
            cboPt.value = payroll;

            if (typeof poblarPeriodoVacaciones === 'function') {
                await poblarPeriodoVacaciones(cia, payroll, cboPer);
            } else {
                await poblarSelect(
                    `/api/selectores/periodos-asig?cia=${encodeURIComponent(cia)}&payrolltype=${encodeURIComponent(payroll)}`,
                    cboPer
                );
            }

            const periodo = filtros.periodo != null ? String(filtros.periodo).trim() : '';
            if (periodo && optionExists(cboPer, periodo)) {
                cboPer.value = periodo;
            } else if (optionExists(cboPer, '0')) {
                cboPer.value = '0';
            }

            const cboTra = document.getElementById('cboTrabajador');
            if (cboTra) {
                await poblarSelect(`/api/selectores/trabajadores?cia=${encodeURIComponent(cia)}`, cboTra);
                const person = filtros.person != null ? String(filtros.person).trim() : '';
                if (person && optionExists(cboTra, person)) {
                    cboTra.value = person;
                }
            }

            guardar();
            return true;
        }

        function registrarGuardadoEnCambio() {
            ['cboCompania', 'cboTipoPlanilla', 'cboPeriodo', 'cboTrabajador'].forEach((id) => {
                const el = document.getElementById(id);
                if (el) el.addEventListener('change', guardar);
            });
        }

        return {
            STORAGE_KEY: STORAGE_KEY_VACACIONES_DETALLE,
            guardar,
            leer,
            aplicarRestauracionCascada,
            registrarGuardadoEnCambio
        };
    }

    function crearPersistenciaSaldoVacaciones() {
        function guardar() {
            try {
                const estado = {
                    cia: val('cboCompania'),
                    payroll: val('cboTipoPlanilla'),
                    person: val('cboTrabajador'),
                    fecha: val('txtFecha'),
                    cesados: val('cboCesados'),
                    timestamp: Date.now()
                };
                localStorage.setItem(STORAGE_KEY_SALDO_VACACIONES, JSON.stringify(estado));
            } catch (e) {
                console.warn('filtros saldo vacaciones: no se pudo guardar', e);
            }
        }

        function leer() {
            try {
                const raw = localStorage.getItem(STORAGE_KEY_SALDO_VACACIONES);
                if (!raw) return null;
                const o = JSON.parse(raw);
                if (!o || typeof o !== 'object') return null;
                return o;
            } catch (e) {
                return null;
            }
        }

        async function aplicarRestauracionCascada(opts) {
            if (!opts || typeof opts.poblarSelect !== 'function') return false;

            const { poblarSelect } = opts;
            const filtros = leer();
            if (!filtros || !filtros.cia) return false;

            const cboCia = document.getElementById('cboCompania');
            const cboPt = document.getElementById('cboTipoPlanilla');
            if (!cboCia || !cboPt) return false;

            const cia = String(filtros.cia).trim();
            if (!optionExists(cboCia, cia)) return false;
            cboCia.value = cia;

            await poblarSelect(`/api/selectores/planillas?cia=${encodeURIComponent(cia)}`, cboPt);

            const payroll = filtros.payroll != null ? String(filtros.payroll).trim() : '';
            if (!payroll || !optionExists(cboPt, payroll)) {
                guardar();
                return true;
            }
            cboPt.value = payroll;

            const cboTra = document.getElementById('cboTrabajador');
            if (cboTra) {
                await poblarSelect(`/api/selectores/trabajadores?cia=${encodeURIComponent(cia)}`, cboTra);
                const person = filtros.person != null ? String(filtros.person).trim() : '';
                if (person && optionExists(cboTra, person)) {
                    cboTra.value = person;
                }
            }

            guardar();
            return true;
        }

        function registrarGuardadoEnCambio() {
            ['cboCompania', 'cboTipoPlanilla', 'cboTrabajador', 'txtFecha', 'cboCesados'].forEach((id) => {
                const el = document.getElementById(id);
                if (el) el.addEventListener('change', guardar);
            });
        }

        return {
            STORAGE_KEY: STORAGE_KEY_SALDO_VACACIONES,
            guardar,
            leer,
            aplicarRestauracionCascada,
            registrarGuardadoEnCambio
        };
    }

    function crearPersistenciaDescansosMedicosDetalle() {
        function guardar() {
            try {
                const estado = {
                    cia: val('cboCompania'),
                    payroll: val('cboTipoPlanilla'),
                    periodo: val('cboPeriodo'),
                    person: val('cboTrabajador'),
                    medicalresttype: val('cboTipoDescanso'),
                    timestamp: Date.now()
                };
                localStorage.setItem(STORAGE_KEY_DESCANSOS_MEDICOS_DETALLE, JSON.stringify(estado));
            } catch (e) {
                console.warn('filtros descansos médicos detalle: no se pudo guardar', e);
            }
        }

        function leer() {
            try {
                const raw = localStorage.getItem(STORAGE_KEY_DESCANSOS_MEDICOS_DETALLE);
                if (!raw) return null;
                const o = JSON.parse(raw);
                if (!o || typeof o !== 'object') return null;
                return o;
            } catch (e) {
                return null;
            }
        }

        async function aplicarRestauracionCascada(opts) {
            if (!opts || typeof opts.poblarSelect !== 'function') return false;

            const { poblarSelect, poblarPeriodoVacaciones, poblarTiposDescansoMedico } = opts;
            const filtros = leer();
            if (!filtros || !filtros.cia) return false;

            const cboCia = document.getElementById('cboCompania');
            const cboPt = document.getElementById('cboTipoPlanilla');
            const cboPer = document.getElementById('cboPeriodo');
            if (!cboCia || !cboPt || !cboPer) return false;

            const cia = String(filtros.cia).trim();
            if (!optionExists(cboCia, cia)) return false;
            cboCia.value = cia;

            const cboTipoDm = document.getElementById('cboTipoDescanso');
            if (cboTipoDm && typeof poblarTiposDescansoMedico === 'function') {
                await poblarTiposDescansoMedico(cia, cboTipoDm);
                const mrt = filtros.medicalresttype != null ? String(filtros.medicalresttype).trim() : '';
                if (mrt && optionExists(cboTipoDm, mrt)) {
                    cboTipoDm.value = mrt;
                } else if (optionExists(cboTipoDm, '0')) {
                    cboTipoDm.value = '0';
                }
            }

            await poblarSelect(`/api/selectores/planillas?cia=${encodeURIComponent(cia)}`, cboPt);

            const payroll = filtros.payroll != null ? String(filtros.payroll).trim() : '';
            if (!payroll || !optionExists(cboPt, payroll)) {
                guardar();
                return true;
            }
            cboPt.value = payroll;

            if (typeof poblarPeriodoVacaciones === 'function') {
                await poblarPeriodoVacaciones(cia, payroll, cboPer);
            } else {
                await poblarSelect(
                    `/api/selectores/periodos-asig?cia=${encodeURIComponent(cia)}&payrolltype=${encodeURIComponent(payroll)}`,
                    cboPer
                );
            }

            const periodo = filtros.periodo != null ? String(filtros.periodo).trim() : '';
            if (periodo && optionExists(cboPer, periodo)) {
                cboPer.value = periodo;
            } else if (optionExists(cboPer, '0')) {
                cboPer.value = '0';
            }

            const cboTra = document.getElementById('cboTrabajador');
            if (cboTra) {
                await poblarSelect(`/api/selectores/trabajadores?cia=${encodeURIComponent(cia)}`, cboTra);
                const person = filtros.person != null ? String(filtros.person).trim() : '';
                if (person && optionExists(cboTra, person)) {
                    cboTra.value = person;
                }
            }

            guardar();
            return true;
        }

        function registrarGuardadoEnCambio() {
            ['cboCompania', 'cboTipoPlanilla', 'cboPeriodo', 'cboTrabajador', 'cboTipoDescanso'].forEach((id) => {
                const el = document.getElementById(id);
                if (el) el.addEventListener('change', guardar);
            });
        }

        return {
            STORAGE_KEY: STORAGE_KEY_DESCANSOS_MEDICOS_DETALLE,
            guardar,
            leer,
            aplicarRestauracionCascada,
            registrarGuardadoEnCambio
        };
    }

    function crearPersistenciaAsignacionConceptos() {
        function guardar() {
            try {
                const estado = {
                    cia: val('cboCompania'),
                    payroll: val('cboTipoPlanilla'),
                    periodo: val('cboPeriodo') || '0',
                    concept: val('cboConcepto') || '0',
                    person: val('cboTrabajador') || '0',
                    unidad: val('cboUnidad') || '0',
                    cesados: val('cboCesados') || 'T',
                    tipoConcepto: val('cboTipoConcepto') || '0',
                    timestamp: Date.now()
                };
                localStorage.setItem(STORAGE_KEY_ASIGNACION_CONCEPTOS, JSON.stringify(estado));
            } catch (e) {
                console.warn('filtros asignacion conceptos: no se pudo guardar', e);
            }
        }

        function leer() {
            try {
                const raw = localStorage.getItem(STORAGE_KEY_ASIGNACION_CONCEPTOS);
                if (!raw) return null;
                const o = JSON.parse(raw);
                if (!o || typeof o !== 'object') return null;
                return o;
            } catch (e) {
                return null;
            }
        }

        async function aplicarRestauracionCascada(opts) {
            if (!opts || typeof opts.poblarSelect !== 'function') return false;

            const { poblarSelect, poblarPeriodosAsignacion, poblarConceptos } = opts;
            const filtros = leer();
            if (!filtros || !filtros.cia) return false;

            const cboCia = document.getElementById('cboCompania');
            const cboPt = document.getElementById('cboTipoPlanilla');
            const cboPer = document.getElementById('cboPeriodo');
            const cboConcepto = document.getElementById('cboConcepto');
            const cboCesados = document.getElementById('cboCesados');
            const cboTipoConcepto = document.getElementById('cboTipoConcepto');
            const cboUnidad = document.getElementById('cboUnidad');
            const cboTrabajador = document.getElementById('cboTrabajador');
            if (!cboCia || !cboPt || !cboPer || !cboConcepto) return false;

            const cia = String(filtros.cia).trim();
            if (!optionExists(cboCia, cia)) return false;
            cboCia.value = cia;

            await poblarSelect(`/api/selectores/planillas?cia=${encodeURIComponent(cia)}`, cboPt);

            if (typeof poblarConceptos === 'function') {
                await poblarConceptos(cia, cboConcepto);
            } else {
                await poblarSelect(
                    `/api/selectores/conceptos?cia=${encodeURIComponent(cia)}`,
                    cboConcepto
                );
            }
            cboConcepto.disabled = false;

            if (cboTrabajador && cia) {
                if (typeof opts.poblarTrabajadoresFiltro === 'function') {
                    await opts.poblarTrabajadoresFiltro(cia, cboTrabajador);
                } else {
                    await poblarSelect(
                        `/api/selectores/trabajadores?cia=${encodeURIComponent(cia)}`,
                        cboTrabajador
                    );
                    if (typeof opts.etiquetaTrabajadorTodosPorDefecto === 'function') {
                        opts.etiquetaTrabajadorTodosPorDefecto(cboTrabajador);
                    } else if (cboTrabajador.options.length && cboTrabajador.options[0].value === '') {
                        cboTrabajador.options[0].textContent = 'Todos (por defecto)';
                    }
                }
                cboTrabajador.disabled = false;
            }

            const payroll = filtros.payroll != null ? String(filtros.payroll).trim() : '';
            if (!payroll || !optionExists(cboPt, payroll)) {
                const concept = filtros.concept != null ? String(filtros.concept).trim() : '0';
                if (concept && optionExists(cboConcepto, concept)) {
                    cboConcepto.value = concept;
                } else if (optionExists(cboConcepto, '0')) {
                    cboConcepto.value = '0';
                }
                guardar();
                return true;
            }
            cboPt.value = payroll;

            if (cboTrabajador && typeof opts.poblarTrabajadoresFiltro === 'function') {
                await opts.poblarTrabajadoresFiltro(cia, cboTrabajador, payroll);
                cboTrabajador.disabled = false;
            }

            const concept = filtros.concept != null ? String(filtros.concept).trim() : '0';
            if (concept && optionExists(cboConcepto, concept)) {
                cboConcepto.value = concept;
            } else if (optionExists(cboConcepto, '0')) {
                cboConcepto.value = '0';
            }

            if (typeof poblarPeriodosAsignacion === 'function') {
                await poblarPeriodosAsignacion(cia, payroll, cboPer);
            } else {
                await poblarSelect(
                    `/api/selectores/periodos-asig?cia=${encodeURIComponent(cia)}&payrolltype=${encodeURIComponent(payroll)}`,
                    cboPer
                );
            }

            const periodo = filtros.periodo != null ? String(filtros.periodo).trim() : '';
            // Solo restaurar periodo guardado si es un periodo concreto (no "Todos"/vacío).
            // Si no hay guardado útil, dejar el periodo abierto de Fin de mes que ya eligió poblarPeriodosAsignacion.
            if (periodo && periodo !== '0' && optionExists(cboPer, periodo)) {
                cboPer.value = periodo;
            }

            if (cboCesados) {
                const cesados = filtros.cesados != null ? String(filtros.cesados).trim().toUpperCase() : 'T';
                if (['T', 'Y', 'N'].includes(cesados) && optionExists(cboCesados, cesados)) {
                    cboCesados.value = cesados;
                }
            }

            if (cboTipoConcepto) {
                const tipoConcepto = filtros.tipoConcepto != null ? String(filtros.tipoConcepto).trim().toUpperCase() : '0';
                if (['0', 'P', 'T'].includes(tipoConcepto) && optionExists(cboTipoConcepto, tipoConcepto)) {
                    cboTipoConcepto.value = tipoConcepto;
                } else if (optionExists(cboTipoConcepto, '0')) {
                    cboTipoConcepto.value = '0';
                }
            }

            if (cboUnidad) {
                const unidad = filtros.unidad != null ? String(filtros.unidad).trim() : '0';
                if (unidad && optionExists(cboUnidad, unidad)) {
                    cboUnidad.value = unidad;
                } else if (optionExists(cboUnidad, '0')) {
                    cboUnidad.value = '0';
                }
            }

            if (cboTrabajador && cia) {
                const person = filtros.person != null ? String(filtros.person).trim() : '';
                if (person && person !== '0' && optionExists(cboTrabajador, person)) {
                    cboTrabajador.value = person;
                } else if (optionExists(cboTrabajador, '')) {
                    cboTrabajador.value = '';
                }
            }

            guardar();
            return true;
        }

        function registrarGuardadoEnCambio() {
            ['cboCompania', 'cboTipoPlanilla', 'cboPeriodo', 'cboConcepto', 'cboUnidad', 'cboTrabajador', 'cboCesados', 'cboTipoConcepto'].forEach((id) => {
                const el = document.getElementById(id);
                if (el) el.addEventListener('change', guardar);
            });
        }

        return {
            STORAGE_KEY: STORAGE_KEY_ASIGNACION_CONCEPTOS,
            guardar,
            leer,
            aplicarRestauracionCascada,
            registrarGuardadoEnCambio
        };
    }

    function crearPersistenciaPlameArchivo14() {
        const STORAGE_KEY = 'filtros_plame_archivo14';

        function guardar() {
            try {
                const estado = {
                    cia: val('cboCompania'),
                    period: val('cboPeriodoTributario'),
                    timestamp: Date.now()
                };
                localStorage.setItem(STORAGE_KEY, JSON.stringify(estado));
            } catch (e) {
                console.warn('filtros plame archivo14: no se pudo guardar', e);
            }
        }

        function leer() {
            try {
                const raw = localStorage.getItem(STORAGE_KEY);
                if (!raw) return null;
                const o = JSON.parse(raw);
                if (!o || typeof o !== 'object') return null;
                return o;
            } catch (e) {
                return null;
            }
        }

        function registrarGuardadoEnCambio() {
            ['cboCompania', 'cboPeriodoTributario'].forEach((id) => {
                const el = document.getElementById(id);
                if (el) el.addEventListener('change', guardar);
            });
        }

        return {
            STORAGE_KEY,
            guardar,
            leer,
            registrarGuardadoEnCambio
        };
    }

    function crearPersistenciaDeclaracionAfp() {
        const STORAGE_KEY = 'filtros_declaracion_afp';

        function guardar() {
            try {
                const estado = {
                    cia: val('cboCompania'),
                    period: val('cboPeriodo'),
                    payroll: val('cboPlanilla'),
                    afp: val('cboAfp'),
                    employee: val('cboTrabajador'),
                    timestamp: Date.now()
                };
                localStorage.setItem(STORAGE_KEY, JSON.stringify(estado));
            } catch (e) {
                console.warn('filtros declaracion afp: no se pudo guardar', e);
            }
        }

        function leer() {
            try {
                const raw = localStorage.getItem(STORAGE_KEY);
                if (!raw) return null;
                const o = JSON.parse(raw);
                if (!o || typeof o !== 'object') return null;
                return o;
            } catch (e) {
                return null;
            }
        }

        function registrarGuardadoEnCambio() {
            ['cboCompania', 'cboPeriodo', 'cboPlanilla', 'cboAfp', 'cboTrabajador'].forEach((id) => {
                const el = document.getElementById(id);
                if (el) el.addEventListener('change', guardar);
            });
        }

        return {
            STORAGE_KEY,
            guardar,
            leer,
            registrarGuardadoEnCambio
        };
    }

    function crearPersistenciaControlPagosAfp() {
        const STORAGE_KEY = 'filtros_control_pagos_afp';

        function guardar() {
            try {
                const estado = {
                    cia: val('cboCompania'),
                    payroll: val('cboTipoPlanilla'),
                    period: val('cboPeriodo'),
                    timestamp: Date.now()
                };
                localStorage.setItem(STORAGE_KEY, JSON.stringify(estado));
            } catch (e) {
                console.warn('filtros control pagos afp: no se pudo guardar', e);
            }
        }

        function leer() {
            try {
                const raw = localStorage.getItem(STORAGE_KEY);
                if (!raw) return null;
                const o = JSON.parse(raw);
                if (!o || typeof o !== 'object') return null;
                return o;
            } catch (e) {
                return null;
            }
        }

        function registrarGuardadoEnCambio() {
            ['cboCompania', 'cboTipoPlanilla', 'cboPeriodo'].forEach((id) => {
                const el = document.getElementById(id);
                if (el) el.addEventListener('change', guardar);
            });
        }

        return {
            STORAGE_KEY,
            guardar,
            leer,
            registrarGuardadoEnCambio
        };
    }

    function crearPersistenciaConceptos() {
        const STORAGE_KEY = 'filtros_maestro_conceptos';

        function guardar() {
            try {
                const tipos = [];
                const chkTodos = document.getElementById('chkTipoConceptoTodos');
                const todos = chkTodos && chkTodos.checked;
                if (!todos) {
                    document.querySelectorAll('#contenedorFiltroTiposConcepto .chk-tipo-concepto:checked').forEach((chk) => {
                        const sn = String(chk.getAttribute('data-shortname') || '').trim().toUpperCase();
                        if (sn) tipos.push(sn);
                    });
                }
                const estado = {
                    cia: val('cboCompania'),
                    busqueda: val('txtBuscarConcepto'),
                    tipos: tipos,
                    timestamp: Date.now()
                };
                localStorage.setItem(STORAGE_KEY, JSON.stringify(estado));
            } catch (e) {
                console.warn('filtros conceptos: no se pudo guardar', e);
            }
        }

        function leer() {
            try {
                const raw = localStorage.getItem(STORAGE_KEY);
                if (!raw) return null;
                const o = JSON.parse(raw);
                if (!o || typeof o !== 'object') return null;
                return o;
            } catch (e) {
                return null;
            }
        }

        function registrarGuardadoEnCambio() {
            ['cboCompania', 'txtBuscarConcepto'].forEach((id) => {
                const el = document.getElementById(id);
                if (el) el.addEventListener('change', guardar);
            });
            const txt = document.getElementById('txtBuscarConcepto');
            if (txt) txt.addEventListener('input', guardar);
            const contTipos = document.getElementById('contenedorFiltroTiposConcepto');
            if (contTipos) {
                contTipos.addEventListener('change', guardar);
            }
        }

        return {
            STORAGE_KEY,
            guardar,
            leer,
            registrarGuardadoEnCambio
        };
    }

    function crearPersistenciaPlameArchivo18() {
        const STORAGE_KEY = 'filtros_plame_archivo18';

        function guardar() {
            try {
                const estado = {
                    cia: val('cboCompania'),
                    period: val('cboPeriodoTributario'),
                    cesados: val('cboCesados') || 'T',
                    timestamp: Date.now()
                };
                localStorage.setItem(STORAGE_KEY, JSON.stringify(estado));
            } catch (e) {
                console.warn('filtros plame archivo18: no se pudo guardar', e);
            }
        }

        function leer() {
            try {
                const raw = localStorage.getItem(STORAGE_KEY);
                if (!raw) return null;
                const o = JSON.parse(raw);
                if (!o || typeof o !== 'object') return null;
                return o;
            } catch (e) {
                return null;
            }
        }

        function registrarGuardadoEnCambio() {
            ['cboCompania', 'cboPeriodoTributario', 'cboCesados'].forEach((id) => {
                const el = document.getElementById(id);
                if (el) el.addEventListener('change', guardar);
            });
        }

        return {
            STORAGE_KEY,
            guardar,
            leer,
            registrarGuardadoEnCambio
        };
    }

    function crearPersistenciaPlameArchivo26() {
        const STORAGE_KEY = 'filtros_plame_archivo26';

        function guardar() {
            try {
                const estado = {
                    cia: val('cboCompania'),
                    period: val('cboPeriodoTributario'),
                    timestamp: Date.now()
                };
                localStorage.setItem(STORAGE_KEY, JSON.stringify(estado));
            } catch (e) {
                console.warn('filtros plame archivo26: no se pudo guardar', e);
            }
        }

        function leer() {
            try {
                const raw = localStorage.getItem(STORAGE_KEY);
                if (!raw) return null;
                const o = JSON.parse(raw);
                if (!o || typeof o !== 'object') return null;
                return o;
            } catch (e) {
                return null;
            }
        }

        function registrarGuardadoEnCambio() {
            ['cboCompania', 'cboPeriodoTributario'].forEach((id) => {
                const el = document.getElementById(id);
                if (el) el.addEventListener('change', guardar);
            });
        }

        return {
            STORAGE_KEY,
            guardar,
            leer,
            registrarGuardadoEnCambio
        };
    }

    function crearPersistenciaPlameArchivos720() {
        const STORAGE_KEY = 'filtros_plame_archivos_7_20';

        function guardar() {
            try {
                const estado = {
                    cia: val('cboCompania'),
                    period: val('cboPeriodoTributario'),
                    timestamp: Date.now()
                };
                localStorage.setItem(STORAGE_KEY, JSON.stringify(estado));
            } catch (e) {
                console.warn('filtros plame archivos 7,20: no se pudo guardar', e);
            }
        }

        function leer() {
            try {
                const raw = localStorage.getItem(STORAGE_KEY);
                if (!raw) return null;
                const o = JSON.parse(raw);
                if (!o || typeof o !== 'object') return null;
                return o;
            } catch (e) {
                return null;
            }
        }

        function registrarGuardadoEnCambio() {
            ['cboCompania', 'cboPeriodoTributario'].forEach((id) => {
                const el = document.getElementById(id);
                if (el) el.addEventListener('change', guardar);
            });
        }

        return {
            STORAGE_KEY,
            guardar,
            leer,
            registrarGuardadoEnCambio
        };
    }

    function crearPersistenciaPlameTRegistro() {
        const STORAGE_KEY = 'filtros_plame_tregistro';

        function guardar() {
            try {
                const archivos = Array.from(document.querySelectorAll('.chk-archivo-tregistro:checked'))
                    .map((cb) => String(cb.value || '').trim())
                    .filter(Boolean);
                const estado = {
                    cia: val('cboCompania'),
                    fecha_desde: val('txtFechaDesde'),
                    fecha_hasta: val('txtFechaHasta'),
                    activos: document.getElementById('chkActivos')
                        ? document.getElementById('chkActivos').checked
                        : true,
                    archivos,
                    timestamp: Date.now()
                };
                localStorage.setItem(STORAGE_KEY, JSON.stringify(estado));
            } catch (e) {
                console.warn('filtros plame t-registro: no se pudo guardar', e);
            }
        }

        function leer() {
            try {
                const raw = localStorage.getItem(STORAGE_KEY);
                if (!raw) return null;
                const o = JSON.parse(raw);
                if (!o || typeof o !== 'object') return null;
                return o;
            } catch (e) {
                return null;
            }
        }

        function registrarGuardadoEnCambio() {
            ['cboCompania', 'txtFechaDesde', 'txtFechaHasta', 'chkActivos'].forEach((id) => {
                const el = document.getElementById(id);
                if (el) el.addEventListener('change', guardar);
            });
            document.querySelectorAll('.chk-archivo-tregistro').forEach((el) => {
                el.addEventListener('change', guardar);
            });
        }

        return {
            STORAGE_KEY,
            guardar,
            leer,
            registrarGuardadoEnCambio
        };
    }

    function crearPersistenciaPlameValidar() {
        const STORAGE_KEY = 'filtros_plame_validar';

        function guardar() {
            try {
                const estado = {
                    cia: val('cboCompania'),
                    period: val('cboPeriodoTributario'),
                    timestamp: Date.now()
                };
                localStorage.setItem(STORAGE_KEY, JSON.stringify(estado));
            } catch (e) {
                console.warn('filtros plame validar: no se pudo guardar', e);
            }
        }

        function leer() {
            try {
                const raw = localStorage.getItem(STORAGE_KEY);
                if (!raw) return null;
                const o = JSON.parse(raw);
                if (!o || typeof o !== 'object') return null;
                return o;
            } catch (e) {
                return null;
            }
        }

        function registrarGuardadoEnCambio() {
            ['cboCompania', 'cboPeriodoTributario'].forEach((id) => {
                const el = document.getElementById(id);
                if (el) el.addEventListener('change', guardar);
            });
        }

        return {
            STORAGE_KEY,
            guardar,
            leer,
            registrarGuardadoEnCambio
        };
    }

    function crearPersistenciaPlameArchivo15() {
        const STORAGE_KEY = 'filtros_plame_archivo15';

        function guardar() {
            try {
                const estado = {
                    cia: val('cboCompania'),
                    period: val('cboPeriodoTributario'),
                    timestamp: Date.now()
                };
                localStorage.setItem(STORAGE_KEY, JSON.stringify(estado));
            } catch (e) {
                console.warn('filtros plame archivo15: no se pudo guardar', e);
            }
        }

        function leer() {
            try {
                const raw = localStorage.getItem(STORAGE_KEY);
                if (!raw) return null;
                const o = JSON.parse(raw);
                if (!o || typeof o !== 'object') return null;
                return o;
            } catch (e) {
                return null;
            }
        }

        function registrarGuardadoEnCambio() {
            ['cboCompania', 'cboPeriodoTributario'].forEach((id) => {
                const el = document.getElementById(id);
                if (el) el.addEventListener('change', guardar);
            });
        }

        return {
            STORAGE_KEY,
            guardar,
            leer,
            registrarGuardadoEnCambio
        };
    }

    /**
     * @param {string} storageKey
     * @param {boolean} incluyeTodosBancos
     * @param {boolean} incluyeBancoHaberes
     */
    function crearPersistenciaPagoHaberes(storageKey, incluyeTodosBancos, incluyeBancoHaberes) {
        function guardar() {
            try {
                const estado = {
                    cia: val('cboCompania'),
                    payroll: val('cboTipoPlanilla'),
                    proceso: val('cboProceso'),
                    periodo: val('cboPeriodo'),
                    currency: val('cboMoneda') || 'LO',
                    concept: val('cboConcepto'),
                    paydate: val('txtFechaPago'),
                    cesados: val('cboCesados') || 'T',
                    timestamp: Date.now()
                };
                if (incluyeBancoHaberes) {
                    estado.salarybank = val('cboBancoHaberes') || '0';
                }
                if (incluyeTodosBancos) {
                    const chk = document.getElementById('chkTodosBancos');
                    estado.todos_bancos = !!(chk && chk.checked);
                }
                const cboUnidad = document.getElementById('cboUnidad');
                if (cboUnidad) {
                    estado.unidad = val('cboUnidad') || '0';
                }
                const txtRef = document.getElementById('txtReferencia');
                if (txtRef) {
                    estado.referencia = String(txtRef.value || '').trim().slice(0, 25);
                }
                localStorage.setItem(storageKey, JSON.stringify(estado));
            } catch (e) {
                console.warn('filtros pago haberes: no se pudo guardar', e);
            }
        }

        function leer() {
            try {
                const raw = localStorage.getItem(storageKey);
                if (!raw) return null;
                const o = JSON.parse(raw);
                if (!o || typeof o !== 'object') return null;
                return o;
            } catch (e) {
                return null;
            }
        }

        async function aplicarRestauracionCascada(opts) {
            if (!opts || typeof opts.poblarSelect !== 'function') return false;

            const { poblarSelect, poblarBancosHaberes, poblarUnidades } = opts;
            const filtros = leer();
            if (!filtros || !filtros.cia) return false;

            const cboCia = document.getElementById('cboCompania');
            const cboPt = document.getElementById('cboTipoPlanilla');
            const cboProc = document.getElementById('cboProceso');
            const cboPer = document.getElementById('cboPeriodo');
            const cboConcepto = document.getElementById('cboConcepto');
            const cboMoneda = document.getElementById('cboMoneda');
            const txtFechaPago = document.getElementById('txtFechaPago');
            const cboCesados = document.getElementById('cboCesados');
            const cboUnidad = document.getElementById('cboUnidad');
            const chkTodosBancos = incluyeTodosBancos ? document.getElementById('chkTodosBancos') : null;
            if (!cboCia || !cboPt || !cboProc || !cboPer || !cboConcepto) return false;

            const cia = String(filtros.cia).trim();
            if (!optionExists(cboCia, cia)) return false;
            cboCia.value = cia;

            if (incluyeBancoHaberes && typeof poblarBancosHaberes === 'function') {
                await poblarBancosHaberes(cia);
                const cboBanco = document.getElementById('cboBancoHaberes');
                if (cboBanco) {
                    const salarybank = filtros.salarybank != null ? String(filtros.salarybank).trim() : '0';
                    if (optionExists(cboBanco, salarybank)) {
                        cboBanco.value = salarybank;
                    } else if (optionExists(cboBanco, '0')) {
                        cboBanco.value = '0';
                    }
                }
            }

            await poblarSelect(`/api/selectores/planillas?cia=${encodeURIComponent(cia)}`, cboPt);
            const concept = filtros.concept != null ? String(filtros.concept).trim() : '';
            await poblarConceptosConNeto(cia, cboConcepto, poblarSelect, concept);

            const payroll = filtros.payroll != null ? String(filtros.payroll).trim() : '';
            if (!payroll || !optionExists(cboPt, payroll)) {
                guardar();
                return true;
            }
            cboPt.value = payroll;

            await poblarSelect(
                `/api/selectores/procesos?cia=${encodeURIComponent(cia)}&payrolltype=${encodeURIComponent(payroll)}`,
                cboProc
            );

            const proceso = filtros.proceso != null ? String(filtros.proceso).trim() : '';
            if (!proceso || !optionExists(cboProc, proceso)) {
                guardar();
                return true;
            }
            cboProc.value = proceso;

            const periodo = filtros.periodo != null ? String(filtros.periodo).trim() : '';
            await poblarPeriodosConActivo(cia, payroll, proceso, cboPer, poblarSelect, periodo);

            if (cboMoneda) {
                const currency = filtros.currency != null ? String(filtros.currency).trim().toUpperCase() : 'LO';
                if (optionExists(cboMoneda, currency)) {
                    cboMoneda.value = currency;
                }
            }

            if (txtFechaPago && filtros.paydate) {
                txtFechaPago.value = String(filtros.paydate);
            }

            if (cboCesados) {
                const cesados = filtros.cesados != null ? String(filtros.cesados).trim().toUpperCase() : 'T';
                if (['T', 'Y', 'N'].includes(cesados) && optionExists(cboCesados, cesados)) {
                    cboCesados.value = cesados;
                }
            }

            if (chkTodosBancos) {
                chkTodosBancos.checked = !!filtros.todos_bancos;
            }

            if (cboUnidad) {
                if (typeof poblarUnidades === 'function') {
                    await poblarUnidades();
                }
                const unidad = filtros.unidad != null ? String(filtros.unidad).trim() : '0';
                if (unidad && optionExists(cboUnidad, unidad)) {
                    cboUnidad.value = unidad;
                } else if (optionExists(cboUnidad, '0')) {
                    cboUnidad.value = '0';
                }
            }

            const txtReferencia = document.getElementById('txtReferencia');
            if (txtReferencia && filtros.referencia != null) {
                txtReferencia.value = String(filtros.referencia).slice(0, 25);
            }

            guardar();
            return true;
        }

        function registrarGuardadoEnCambio() {
            [
                'cboCompania', 'cboTipoPlanilla', 'cboProceso', 'cboPeriodo',
                'cboMoneda', 'cboConcepto', 'cboCesados', 'cboUnidad'
            ].forEach((id) => {
                const el = document.getElementById(id);
                if (el) el.addEventListener('change', guardar);
            });
            const txtFechaPago = document.getElementById('txtFechaPago');
            if (txtFechaPago) txtFechaPago.addEventListener('change', guardar);
            const txtReferencia = document.getElementById('txtReferencia');
            if (txtReferencia) {
                txtReferencia.addEventListener('change', guardar);
                txtReferencia.addEventListener('input', guardar);
            }
            if (incluyeTodosBancos) {
                const chkTodosBancos = document.getElementById('chkTodosBancos');
                if (chkTodosBancos) chkTodosBancos.addEventListener('change', guardar);
            }
            if (incluyeBancoHaberes) {
                const cboBanco = document.getElementById('cboBancoHaberes');
                if (cboBanco) cboBanco.addEventListener('change', guardar);
            }
        }

        return {
            STORAGE_KEY: storageKey,
            guardar,
            leer,
            aplicarRestauracionCascada,
            registrarGuardadoEnCambio
        };
    }

    function crearPersistenciaAperturarPeriodos() {
        function guardar() {
            try {
                const estado = {
                    cia: val('cboCompania'),
                    payroll: val('cboTipoPlanilla'),
                    periodo: val('cboPeriodoApertura'),
                    timestamp: Date.now()
                };
                localStorage.setItem(STORAGE_KEY_APERTURAR_PERIODOS, JSON.stringify(estado));
            } catch (e) {
                console.warn('filtros aperturar periodos: no se pudo guardar', e);
            }
        }

        function leer() {
            try {
                const raw = localStorage.getItem(STORAGE_KEY_APERTURAR_PERIODOS);
                if (!raw) return null;
                const o = JSON.parse(raw);
                if (!o || typeof o !== 'object') return null;
                return o;
            } catch (e) {
                return null;
            }
        }

        function registrarGuardadoEnCambio() {
            ['cboCompania', 'cboTipoPlanilla', 'cboPeriodoApertura'].forEach((id) => {
                const el = document.getElementById(id);
                if (el) el.addEventListener('change', guardar);
            });
        }

        return {
            STORAGE_KEY: STORAGE_KEY_APERTURAR_PERIODOS,
            guardar,
            leer,
            registrarGuardadoEnCambio
        };
    }

    function crearPersistenciaTrabajadores() {
        function guardar() {
            try {
                const estado = {
                    cia: val('cboCompania'),
                    payroll: val('cboTipoPlanilla') || '0',
                    person: val('cboTrabajador') || '0',
                    docnro: val('txtDni'),
                    nombre: val('txtNombre'),
                    estadoFiltro: val('cboEstado') || 'A',
                    cesados: val('cboCesados') || 'T',
                    salarybank: val('cboBancoHaberes') || '0',
                    repunit: val('cboUnidad') || '0',
                    timestamp: Date.now()
                };
                localStorage.setItem(STORAGE_KEY_TRABAJADORES, JSON.stringify(estado));
            } catch (e) {
                console.warn('filtros trabajadores: no se pudo guardar', e);
            }
        }

        function leer() {
            try {
                const raw = localStorage.getItem(STORAGE_KEY_TRABAJADORES);
                if (!raw) return null;
                const o = JSON.parse(raw);
                if (!o || typeof o !== 'object') return null;
                return o;
            } catch (e) {
                return null;
            }
        }

        async function aplicarRestauracionCascada(opts) {
            if (!opts || typeof opts.poblarSelect !== 'function') return false;

            const { poblarSelect, poblarBancosHaberes, cargarUnidades } = opts;
            const filtros = leer();
            if (!filtros || !filtros.cia) return false;

            const cboCia = document.getElementById('cboCompania');
            const cboPt = document.getElementById('cboTipoPlanilla');
            if (!cboCia || !cboPt) return false;

            const cia = String(filtros.cia).trim();
            if (!optionExists(cboCia, cia)) return false;
            cboCia.value = cia;

            if (typeof cargarUnidades === 'function') {
                await cargarUnidades();
                const cboUnidad = document.getElementById('cboUnidad');
                if (cboUnidad) {
                    const repunit = filtros.repunit != null ? String(filtros.repunit).trim() : '0';
                    if (repunit && optionExists(cboUnidad, repunit)) {
                        cboUnidad.value = repunit;
                    } else if (optionExists(cboUnidad, '0')) {
                        cboUnidad.value = '0';
                    }
                }
            }

            if (typeof poblarBancosHaberes === 'function') {
                await poblarBancosHaberes(cia);
                const cboBanco = document.getElementById('cboBancoHaberes');
                if (cboBanco) {
                    const salarybank = filtros.salarybank != null ? String(filtros.salarybank).trim() : '0';
                    if (optionExists(cboBanco, salarybank)) {
                        cboBanco.value = salarybank;
                    } else if (optionExists(cboBanco, '0')) {
                        cboBanco.value = '0';
                    }
                }
            }

            await poblarSelect(
                `/api/selectores/planillas?cia=${encodeURIComponent(cia)}`,
                cboPt,
                { incluyeTodos: true, valorTodos: '0', textoTodos: 'Todos' }
            );

            const payroll = filtros.payroll != null ? String(filtros.payroll).trim() : '0';
            if (optionExists(cboPt, payroll)) {
                cboPt.value = payroll;
            } else if (optionExists(cboPt, '0')) {
                cboPt.value = '0';
            }

            const cboTra = document.getElementById('cboTrabajador');
            if (cboTra) {
                await poblarSelect(
                    `/api/selectores/trabajadores?cia=${encodeURIComponent(cia)}`,
                    cboTra,
                    { incluyeTodos: true, valorTodos: '0', textoTodos: 'Todos (por defecto)' }
                );
                const person = filtros.person != null ? String(filtros.person).trim() : '0';
                if (person && optionExists(cboTra, person)) {
                    cboTra.value = person;
                } else if (optionExists(cboTra, '0')) {
                    cboTra.value = '0';
                }
            }

            const cboEst = document.getElementById('cboEstado');
            if (cboEst) {
                const estadoFiltro = filtros.estadoFiltro != null ? String(filtros.estadoFiltro).trim() : 'A';
                if (optionExists(cboEst, estadoFiltro)) {
                    cboEst.value = estadoFiltro;
                } else if (optionExists(cboEst, 'A')) {
                    cboEst.value = 'A';
                }
            }

            const cboCesados = document.getElementById('cboCesados');
            if (cboCesados) {
                const cesados = filtros.cesados != null ? String(filtros.cesados).trim().toUpperCase() : 'T';
                if (['T', 'Y', 'N'].includes(cesados) && optionExists(cboCesados, cesados)) {
                    cboCesados.value = cesados;
                } else if (optionExists(cboCesados, 'T')) {
                    cboCesados.value = 'T';
                }
            }

            const txtNombre = document.getElementById('txtNombre');
            if (txtNombre && filtros.nombre != null) {
                txtNombre.value = String(filtros.nombre);
            }

            const txtDni = document.getElementById('txtDni');
            if (txtDni && filtros.docnro != null) {
                txtDni.value = String(filtros.docnro);
            }

            guardar();
            return true;
        }

        function registrarGuardadoEnCambio() {
            ['cboCompania', 'cboTipoPlanilla', 'cboTrabajador', 'cboEstado', 'cboCesados', 'cboBancoHaberes', 'cboUnidad'].forEach((id) => {
                const el = document.getElementById(id);
                if (el) el.addEventListener('change', guardar);
            });
        }

        return {
            STORAGE_KEY: STORAGE_KEY_TRABAJADORES,
            guardar,
            leer,
            aplicarRestauracionCascada,
            registrarGuardadoEnCambio
        };
    }

    function crearPersistenciaRegistroVacaciones() {
        function guardar() {
            try {
                localStorage.setItem(STORAGE_KEY_REGISTRO_VACACIONES, JSON.stringify({
                    cia: val('cboCompania'),
                    payrolltype: val('cboTipoPlanilla') || '0',
                }));
            } catch (e) {
                console.error(e);
            }
        }

        function leer() {
            try {
                const raw = localStorage.getItem(STORAGE_KEY_REGISTRO_VACACIONES);
                return raw ? JSON.parse(raw) : null;
            } catch (e) {
                console.error(e);
                return null;
            }
        }

        function registrarGuardadoEnCambio() {
            ['cboCompania', 'cboTipoPlanilla'].forEach((id) => {
                const el = document.getElementById(id);
                if (el) el.addEventListener('change', guardar);
            });
        }

        return {
            STORAGE_KEY: STORAGE_KEY_REGISTRO_VACACIONES,
            guardar,
            leer,
            registrarGuardadoEnCambio
        };
    }

    function crearPersistenciaRegistroDescansosMedicos() {
        function guardar() {
            try {
                localStorage.setItem(STORAGE_KEY_REGISTRO_DESCANSOS, JSON.stringify({
                    cia: val('cboCompania'),
                    payrolltype: val('cboTipoPlanilla') || '0',
                    cesados: val('cboCesados') || 'T',
                }));
            } catch (e) {
                console.error(e);
            }
        }

        function leer() {
            try {
                const raw = localStorage.getItem(STORAGE_KEY_REGISTRO_DESCANSOS);
                return raw ? JSON.parse(raw) : null;
            } catch (e) {
                console.error(e);
                return null;
            }
        }

        function registrarGuardadoEnCambio() {
            ['cboCompania', 'cboTipoPlanilla', 'cboCesados'].forEach((id) => {
                const el = document.getElementById(id);
                if (el) el.addEventListener('change', guardar);
            });
        }

        return {
            STORAGE_KEY: STORAGE_KEY_REGISTRO_DESCANSOS,
            guardar,
            leer,
            registrarGuardadoEnCambio
        };
    }

    function crearPersistenciaGenerarBoletas() {
        function guardar() {
            try {
                const estado = {
                    cia: val('cboCompania'),
                    payroll: val('cboTipoPlanilla'),
                    proceso: val('cboProceso'),
                    periodo: val('cboPeriodo'),
                    repunit: val('cboUnidad') || '0',
                    costcenter: val('cboCentroCosto') || '0',
                    sin_firma: document.getElementById('chkSinFirma')?.checked ? '1' : '0',
                    nombre: val('txtBuscarTrabajador'),
                    timestamp: Date.now()
                };
                localStorage.setItem(STORAGE_KEY_GENERAR_BOLETAS, JSON.stringify(estado));
            } catch (e) {
                console.warn('filtros generar boletas: no se pudo guardar', e);
            }
        }

        function leer() {
            try {
                const raw = localStorage.getItem(STORAGE_KEY_GENERAR_BOLETAS);
                if (!raw) return null;
                const o = JSON.parse(raw);
                if (!o || typeof o !== 'object') return null;
                return o;
            } catch (e) {
                return null;
            }
        }

        async function aplicarRestauracionCascada(opts) {
            if (!opts || typeof opts.poblarSelect !== 'function') return false;

            const { poblarSelect, cargarCentrosCosto } = opts;
            const filtros = leer();
            if (!filtros || !filtros.cia) return false;

            const cboCia = document.getElementById('cboCompania');
            const cboPt = document.getElementById('cboTipoPlanilla');
            const cboProc = document.getElementById('cboProceso');
            const cboPer = document.getElementById('cboPeriodo');
            const txtNombre = document.getElementById('txtBuscarTrabajador');
            if (!cboCia || !cboPt || !cboProc || !cboPer) return false;

            const cia = String(filtros.cia).trim();
            if (!optionExists(cboCia, cia)) return false;
            cboCia.value = cia;

            await poblarSelect(`/api/selectores/planillas?cia=${encodeURIComponent(cia)}`, cboPt);

            const payroll = filtros.payroll != null ? String(filtros.payroll).trim() : '';
            if (!payroll || !optionExists(cboPt, payroll)) {
                if (txtNombre && filtros.nombre != null) {
                    txtNombre.value = String(filtros.nombre);
                }
                guardar();
                return true;
            }
            cboPt.value = payroll;

            await poblarSelect(
                `/api/selectores/procesos?cia=${encodeURIComponent(cia)}&payrolltype=${encodeURIComponent(payroll)}`,
                cboProc
            );

            const proceso = filtros.proceso != null ? String(filtros.proceso).trim() : '';
            if (!proceso || !optionExists(cboProc, proceso)) {
                if (txtNombre && filtros.nombre != null) {
                    txtNombre.value = String(filtros.nombre);
                }
                guardar();
                return true;
            }
            cboProc.value = proceso;

            await poblarSelect(
                `/api/selectores/periodos?cia=${encodeURIComponent(cia)}&payrolltype=${encodeURIComponent(payroll)}&processtype=${encodeURIComponent(proceso)}`,
                cboPer
            );

            const periodo = filtros.periodo != null ? String(filtros.periodo).trim() : '';
            if (periodo && optionExists(cboPer, periodo)) {
                cboPer.value = periodo;
            }

            if (txtNombre && filtros.nombre != null) {
                txtNombre.value = String(filtros.nombre);
            }

            const cboUnidad = document.getElementById('cboUnidad');
            if (cboUnidad) {
                const repunit = filtros.repunit != null ? String(filtros.repunit).trim() : '0';
                if (repunit && optionExists(cboUnidad, repunit)) {
                    cboUnidad.value = repunit;
                } else if (optionExists(cboUnidad, '0')) {
                    cboUnidad.value = '0';
                }
            }

            const cboCentroCosto = document.getElementById('cboCentroCosto');
            if (cboCentroCosto) {
                if (typeof cargarCentrosCosto === 'function') {
                    await cargarCentrosCosto();
                }
                const costcenter = filtros.costcenter != null ? String(filtros.costcenter).trim() : '0';
                if (costcenter && optionExists(cboCentroCosto, costcenter)) {
                    cboCentroCosto.value = costcenter;
                } else if (optionExists(cboCentroCosto, '0')) {
                    cboCentroCosto.value = '0';
                }
            }

            const chkSinFirma = document.getElementById('chkSinFirma');
            if (chkSinFirma) {
                const sinFirma = String(filtros.sin_firma || '').trim().toLowerCase();
                chkSinFirma.checked = ['1', 'true', 'yes', 'y', 'on', 's', 'si'].includes(sinFirma);
            }

            guardar();
            return true;
        }

        function registrarGuardadoEnCambio() {
            ['cboCompania', 'cboTipoPlanilla', 'cboProceso', 'cboPeriodo', 'cboUnidad', 'cboCentroCosto'].forEach((id) => {
                const el = document.getElementById(id);
                if (el) el.addEventListener('change', guardar);
            });
            const chkSinFirma = document.getElementById('chkSinFirma');
            if (chkSinFirma) chkSinFirma.addEventListener('change', guardar);
            const txtNombre = document.getElementById('txtBuscarTrabajador');
            if (txtNombre) {
                txtNombre.addEventListener('change', guardar);
                txtNombre.addEventListener('input', guardar);
            }
        }

        return {
            STORAGE_KEY: STORAGE_KEY_GENERAR_BOLETAS,
            guardar,
            leer,
            aplicarRestauracionCascada,
            registrarGuardadoEnCambio
        };
    }

    function crearPersistenciaCertificadoTrabajo() {
        function guardar() {
            try {
                const estado = {
                    cia: val('cboCompania'),
                    payroll: val('cboTipoPlanilla'),
                    periodo: val('cboPeriodo'),
                    nombre: val('txtBuscarTrabajador'),
                    timestamp: Date.now()
                };
                localStorage.setItem(STORAGE_KEY_CERTIFICADO_TRABAJO, JSON.stringify(estado));
            } catch (e) {
                console.warn('filtros certificado trabajo: no se pudo guardar', e);
            }
        }

        function leer() {
            try {
                const raw = localStorage.getItem(STORAGE_KEY_CERTIFICADO_TRABAJO);
                if (!raw) return null;
                const o = JSON.parse(raw);
                if (!o || typeof o !== 'object') return null;
                return o;
            } catch (e) {
                return null;
            }
        }

        async function aplicarRestauracionCascada(opts) {
            if (!opts || typeof opts.poblarSelect !== 'function') return false;

            const { poblarSelect, cargarPeriodosLiquidacion } = opts;
            const filtros = leer();
            if (!filtros || !filtros.cia) return false;

            const cboCia = document.getElementById('cboCompania');
            const cboPt = document.getElementById('cboTipoPlanilla');
            const cboProc = document.getElementById('cboProceso');
            const cboPer = document.getElementById('cboPeriodo');
            const txtNombre = document.getElementById('txtBuscarTrabajador');
            if (!cboCia || !cboPt || !cboProc || !cboPer) return false;

            const cia = String(filtros.cia).trim();
            if (!optionExists(cboCia, cia)) return false;
            cboCia.value = cia;

            await poblarSelect(`/api/selectores/planillas?cia=${encodeURIComponent(cia)}`, cboPt);

            const payroll = filtros.payroll != null ? String(filtros.payroll).trim() : '';
            if (!payroll || !optionExists(cboPt, payroll)) {
                if (txtNombre && filtros.nombre != null) {
                    txtNombre.value = String(filtros.nombre);
                }
                guardar();
                return true;
            }
            cboPt.value = payroll;

            if (typeof cargarPeriodosLiquidacion === 'function') {
                await cargarPeriodosLiquidacion();
            }

            const periodo = filtros.periodo != null ? String(filtros.periodo).trim() : '';
            if (periodo && optionExists(cboPer, periodo)) {
                cboPer.value = periodo;
            }

            if (txtNombre && filtros.nombre != null) {
                txtNombre.value = String(filtros.nombre);
            }

            guardar();
            return true;
        }

        function registrarGuardadoEnCambio() {
            ['cboCompania', 'cboTipoPlanilla', 'cboPeriodo'].forEach((id) => {
                const el = document.getElementById(id);
                if (el) el.addEventListener('change', guardar);
            });
            const txtNombre = document.getElementById('txtBuscarTrabajador');
            if (txtNombre) {
                txtNombre.addEventListener('change', guardar);
                txtNombre.addEventListener('input', guardar);
            }
        }

        return {
            STORAGE_KEY: STORAGE_KEY_CERTIFICADO_TRABAJO,
            guardar,
            leer,
            aplicarRestauracionCascada,
            registrarGuardadoEnCambio
        };
    }

    function crearPersistenciaCertificadoRetiroCts() {
        function guardar() {
            try {
                const estado = {
                    cia: val('cboCompania'),
                    payroll: val('cboTipoPlanilla'),
                    periodo: val('cboPeriodo'),
                    nombre: val('txtBuscarTrabajador'),
                    timestamp: Date.now()
                };
                localStorage.setItem(STORAGE_KEY_CERTIFICADO_RETIRO_CTS, JSON.stringify(estado));
            } catch (e) {
                console.warn('filtros certificado retiro cts: no se pudo guardar', e);
            }
        }

        function leer() {
            try {
                const raw = localStorage.getItem(STORAGE_KEY_CERTIFICADO_RETIRO_CTS);
                if (!raw) return null;
                const o = JSON.parse(raw);
                if (!o || typeof o !== 'object') return null;
                return o;
            } catch (e) {
                return null;
            }
        }

        async function aplicarRestauracionCascada(opts) {
            if (!opts || typeof opts.poblarSelect !== 'function') return false;

            const { poblarSelect, cargarPeriodosLiquidacion } = opts;
            const filtros = leer();
            if (!filtros || !filtros.cia) return false;

            const cboCia = document.getElementById('cboCompania');
            const cboPt = document.getElementById('cboTipoPlanilla');
            const cboProc = document.getElementById('cboProceso');
            const cboPer = document.getElementById('cboPeriodo');
            const txtNombre = document.getElementById('txtBuscarTrabajador');
            if (!cboCia || !cboPt || !cboProc || !cboPer) return false;

            const cia = String(filtros.cia).trim();
            if (!optionExists(cboCia, cia)) return false;
            cboCia.value = cia;

            await poblarSelect(`/api/selectores/planillas?cia=${encodeURIComponent(cia)}`, cboPt);

            const payroll = filtros.payroll != null ? String(filtros.payroll).trim() : '';
            if (!payroll || !optionExists(cboPt, payroll)) {
                if (txtNombre && filtros.nombre != null) {
                    txtNombre.value = String(filtros.nombre);
                }
                guardar();
                return true;
            }
            cboPt.value = payroll;

            if (typeof cargarPeriodosLiquidacion === 'function') {
                await cargarPeriodosLiquidacion();
            }

            const periodo = filtros.periodo != null ? String(filtros.periodo).trim() : '';
            if (periodo && optionExists(cboPer, periodo)) {
                cboPer.value = periodo;
            }

            if (txtNombre && filtros.nombre != null) {
                txtNombre.value = String(filtros.nombre);
            }

            guardar();
            return true;
        }

        function registrarGuardadoEnCambio() {
            ['cboCompania', 'cboTipoPlanilla', 'cboPeriodo'].forEach((id) => {
                const el = document.getElementById(id);
                if (el) el.addEventListener('change', guardar);
            });
            const txtNombre = document.getElementById('txtBuscarTrabajador');
            if (txtNombre) {
                txtNombre.addEventListener('change', guardar);
                txtNombre.addEventListener('input', guardar);
            }
        }

        return {
            STORAGE_KEY: STORAGE_KEY_CERTIFICADO_RETIRO_CTS,
            guardar,
            leer,
            aplicarRestauracionCascada,
            registrarGuardadoEnCambio
        };
    }

    function crearPersistenciaFormatoLiquidacion() {
        function guardar() {
            try {
                const estado = {
                    cia: val('cboCompania'),
                    payroll: val('cboTipoPlanilla'),
                    periodo: val('cboPeriodo'),
                    nombre: val('txtBuscarTrabajador'),
                    timestamp: Date.now()
                };
                localStorage.setItem(STORAGE_KEY_FORMATO_LIQUIDACION, JSON.stringify(estado));
            } catch (e) {
                console.warn('filtros formato liquidacion: no se pudo guardar', e);
            }
        }

        function leer() {
            try {
                const raw = localStorage.getItem(STORAGE_KEY_FORMATO_LIQUIDACION);
                if (!raw) return null;
                const o = JSON.parse(raw);
                if (!o || typeof o !== 'object') return null;
                return o;
            } catch (e) {
                return null;
            }
        }

        async function aplicarRestauracionCascada(opts) {
            if (!opts || typeof opts.poblarSelect !== 'function') return false;

            const { poblarSelect, cargarPeriodosLiquidacion } = opts;
            const filtros = leer();
            if (!filtros || !filtros.cia) return false;

            const cboCia = document.getElementById('cboCompania');
            const cboPt = document.getElementById('cboTipoPlanilla');
            const cboProc = document.getElementById('cboProceso');
            const cboPer = document.getElementById('cboPeriodo');
            const txtNombre = document.getElementById('txtBuscarTrabajador');
            if (!cboCia || !cboPt || !cboProc || !cboPer) return false;

            const cia = String(filtros.cia).trim();
            if (!optionExists(cboCia, cia)) return false;
            cboCia.value = cia;

            await poblarSelect(`/api/selectores/planillas?cia=${encodeURIComponent(cia)}`, cboPt);

            const payroll = filtros.payroll != null ? String(filtros.payroll).trim() : '';
            if (!payroll || !optionExists(cboPt, payroll)) {
                if (txtNombre && filtros.nombre != null) {
                    txtNombre.value = String(filtros.nombre);
                }
                guardar();
                return true;
            }
            cboPt.value = payroll;

            if (typeof cargarPeriodosLiquidacion === 'function') {
                await cargarPeriodosLiquidacion();
            }

            const periodo = filtros.periodo != null ? String(filtros.periodo).trim() : '';
            if (periodo && optionExists(cboPer, periodo)) {
                cboPer.value = periodo;
            }

            if (txtNombre && filtros.nombre != null) {
                txtNombre.value = String(filtros.nombre);
            }

            guardar();
            return true;
        }

        function registrarGuardadoEnCambio() {
            ['cboCompania', 'cboTipoPlanilla', 'cboPeriodo'].forEach((id) => {
                const el = document.getElementById(id);
                if (el) el.addEventListener('change', guardar);
            });
            const txtNombre = document.getElementById('txtBuscarTrabajador');
            if (txtNombre) {
                txtNombre.addEventListener('change', guardar);
                txtNombre.addEventListener('input', guardar);
            }
        }

        return {
            STORAGE_KEY: STORAGE_KEY_FORMATO_LIQUIDACION,
            guardar,
            leer,
            aplicarRestauracionCascada,
            registrarGuardadoEnCambio
        };
    }

    function crearPersistenciaFormatoUtilidades() {
        function guardar() {
            try {
                const estado = {
                    cia: val('cboCompania'),
                    payroll: val('cboTipoPlanilla'),
                    periodo: val('cboPeriodo'),
                    nombre: val('txtBuscarTrabajador'),
                    fecha_pago: val('txtFechaPago'),
                    timestamp: Date.now()
                };
                localStorage.setItem(STORAGE_KEY_FORMATO_UTILIDADES, JSON.stringify(estado));
            } catch (e) {
                console.warn('filtros formato utilidades: no se pudo guardar', e);
            }
        }

        function leer() {
            try {
                const raw = localStorage.getItem(STORAGE_KEY_FORMATO_UTILIDADES);
                if (!raw) return null;
                const o = JSON.parse(raw);
                if (!o || typeof o !== 'object') return null;
                return o;
            } catch (e) {
                return null;
            }
        }

        async function aplicarRestauracionCascada(opts) {
            if (!opts || typeof opts.poblarSelect !== 'function') return false;

            const { poblarSelect, cargarPeriodosUtilidad } = opts;
            const filtros = leer();
            if (!filtros || !filtros.cia) return false;

            const cboCia = document.getElementById('cboCompania');
            const cboPt = document.getElementById('cboTipoPlanilla');
            const cboProc = document.getElementById('cboProceso');
            const cboPer = document.getElementById('cboPeriodo');
            const txtNombre = document.getElementById('txtBuscarTrabajador');
            const txtFechaPago = document.getElementById('txtFechaPago');
            if (!cboCia || !cboPt || !cboProc || !cboPer) return false;

            const cia = String(filtros.cia).trim();
            if (!optionExists(cboCia, cia)) return false;
            cboCia.value = cia;

            await poblarSelect(`/api/selectores/planillas?cia=${encodeURIComponent(cia)}`, cboPt);

            const payroll = filtros.payroll != null ? String(filtros.payroll).trim() : '';
            if (!payroll || !optionExists(cboPt, payroll)) {
                if (txtNombre && filtros.nombre != null) {
                    txtNombre.value = String(filtros.nombre);
                }
                if (txtFechaPago && filtros.fecha_pago) {
                    txtFechaPago.value = String(filtros.fecha_pago);
                }
                guardar();
                return true;
            }
            cboPt.value = payroll;

            if (typeof cargarPeriodosUtilidad === 'function') {
                await cargarPeriodosUtilidad();
            }

            const periodo = filtros.periodo != null ? String(filtros.periodo).trim() : '';
            if (periodo && optionExists(cboPer, periodo)) {
                cboPer.value = periodo;
            }

            if (txtNombre && filtros.nombre != null) {
                txtNombre.value = String(filtros.nombre);
            }
            if (txtFechaPago && filtros.fecha_pago) {
                txtFechaPago.value = String(filtros.fecha_pago);
            }

            guardar();
            return true;
        }

        function registrarGuardadoEnCambio() {
            ['cboCompania', 'cboTipoPlanilla', 'cboPeriodo'].forEach((id) => {
                const el = document.getElementById(id);
                if (el) el.addEventListener('change', guardar);
            });
            const txtNombre = document.getElementById('txtBuscarTrabajador');
            const txtFechaPago = document.getElementById('txtFechaPago');
            if (txtNombre) {
                txtNombre.addEventListener('change', guardar);
                txtNombre.addEventListener('input', guardar);
            }
            if (txtFechaPago) {
                txtFechaPago.addEventListener('change', guardar);
            }
        }

        return {
            STORAGE_KEY: STORAGE_KEY_FORMATO_UTILIDADES,
            guardar,
            leer,
            aplicarRestauracionCascada,
            registrarGuardadoEnCambio
        };
    }

    function crearPersistenciaCertificadoQuinta() {
        function guardar() {
            try {
                const estado = {
                    cia: val('cboCompania'),
                    payroll: val('cboTipoPlanilla'),
                    anio: val('cboAnio'),
                    fecha_emision: val('txtFechaEmision'),
                    nombre: val('txtBuscarTrabajador'),
                    timestamp: Date.now()
                };
                localStorage.setItem(STORAGE_KEY_CERTIFICADO_QUINTA, JSON.stringify(estado));
            } catch (e) {
                console.warn('filtros certificado quinta: no se pudo guardar', e);
            }
        }

        function leer() {
            try {
                const raw = localStorage.getItem(STORAGE_KEY_CERTIFICADO_QUINTA);
                if (!raw) return null;
                const o = JSON.parse(raw);
                if (!o || typeof o !== 'object') return null;
                return o;
            } catch (e) {
                return null;
            }
        }

        async function aplicarRestauracionCascada(opts) {
            if (!opts || typeof opts.poblarSelect !== 'function') return false;

            const { poblarSelect, poblarAnios } = opts;
            const filtros = leer();
            if (!filtros || !filtros.cia) return false;

            const cboCia = document.getElementById('cboCompania');
            const cboPt = document.getElementById('cboTipoPlanilla');
            const cboAnio = document.getElementById('cboAnio');
            const txtFechaEmision = document.getElementById('txtFechaEmision');
            const txtNombre = document.getElementById('txtBuscarTrabajador');
            if (!cboCia || !cboPt || !cboAnio) return false;

            const cia = String(filtros.cia).trim();
            if (!optionExists(cboCia, cia)) return false;
            cboCia.value = cia;

            await poblarSelect(`/api/selectores/planillas?cia=${encodeURIComponent(cia)}`, cboPt);

            const payroll = filtros.payroll != null ? String(filtros.payroll).trim() : '';
            if (payroll && optionExists(cboPt, payroll)) {
                cboPt.value = payroll;
            }

            if (typeof poblarAnios === 'function') {
                poblarAnios(filtros.anio);
            } else if (filtros.anio != null && optionExists(cboAnio, String(filtros.anio).trim())) {
                cboAnio.value = String(filtros.anio).trim();
            }

            if (txtNombre && filtros.nombre != null) {
                txtNombre.value = String(filtros.nombre);
            }
            if (txtFechaEmision && filtros.fecha_emision) {
                txtFechaEmision.value = String(filtros.fecha_emision).trim();
            }

            guardar();
            return true;
        }

        function registrarGuardadoEnCambio() {
            ['cboCompania', 'cboTipoPlanilla', 'cboAnio', 'txtFechaEmision'].forEach((id) => {
                const el = document.getElementById(id);
                if (el) el.addEventListener('change', guardar);
            });
            const txtNombre = document.getElementById('txtBuscarTrabajador');
            if (txtNombre) {
                txtNombre.addEventListener('change', guardar);
                txtNombre.addEventListener('input', guardar);
            }
        }

        return {
            STORAGE_KEY: STORAGE_KEY_CERTIFICADO_QUINTA,
            guardar,
            leer,
            aplicarRestauracionCascada,
            registrarGuardadoEnCambio
        };
    }

    function crearPersistenciaPlanillaPorConceptos() {
        function guardar() {
            try {
                const chk5 = document.getElementById('chkAfecto5ta');
                const chkAfp = document.getElementById('chkAfectoAfp');
                const chkUtil = document.getElementById('chkAfectoUtilidad');
                const estado = {
                    cia: val('cboCompania'),
                    periodo_desde: val('cboPeriodoDesde'),
                    periodo_hasta: val('cboPeriodoHasta'),
                    filtro_afecto5ta: chk5 && chk5.checked ? 'Y' : 'T',
                    filtro_afectoafp: chkAfp && chkAfp.checked ? 'Y' : 'T',
                    filtro_afectoutilidad: chkUtil && chkUtil.checked ? 'Y' : 'T',
                    timestamp: Date.now()
                };
                localStorage.setItem(STORAGE_KEY_PLANILLA_POR_CONCEPTOS, JSON.stringify(estado));
            } catch (e) {
                console.warn('filtros planilla por conceptos: no se pudo guardar', e);
            }
        }

        function leer() {
            try {
                const raw = localStorage.getItem(STORAGE_KEY_PLANILLA_POR_CONCEPTOS);
                if (!raw) return null;
                const o = JSON.parse(raw);
                if (!o || typeof o !== 'object') return null;
                return o;
            } catch (e) {
                return null;
            }
        }

        function registrarGuardadoEnCambio() {
            ['cboCompania', 'cboPeriodoDesde', 'cboPeriodoHasta'].forEach((id) => {
                const el = document.getElementById(id);
                if (el) el.addEventListener('change', guardar);
            });
            ['chkAfecto5ta', 'chkAfectoAfp', 'chkAfectoUtilidad'].forEach((id) => {
                const el = document.getElementById(id);
                if (el) el.addEventListener('change', guardar);
            });
        }

        return {
            STORAGE_KEY: STORAGE_KEY_PLANILLA_POR_CONCEPTOS,
            guardar,
            leer,
            registrarGuardadoEnCambio
        };
    }

    function crearPersistenciaCalculoQuintaTrabajador() {
        function guardar() {
            try {
                const estado = {
                    cia: val('cboCompania'),
                    payroll: val('cboTipoPlanilla'),
                    proceso: val('cboProceso'),
                    periodo: val('cboPeriodo'),
                    trabajador: val('cboTrabajador'),
                    timestamp: Date.now()
                };
                localStorage.setItem(STORAGE_KEY_CALCULO_QUINTA_TRAB, JSON.stringify(estado));
            } catch (e) {
                console.warn('filtros calculo quinta trabajador: no se pudo guardar', e);
            }
        }

        function leer() {
            try {
                const raw = localStorage.getItem(STORAGE_KEY_CALCULO_QUINTA_TRAB);
                if (!raw) return null;
                const o = JSON.parse(raw);
                if (!o || typeof o !== 'object') return null;
                return o;
            } catch (e) {
                return null;
            }
        }

        async function aplicarRestauracionCascada(opts) {
            if (!opts || typeof opts.poblarSelect !== 'function') return false;

            const { poblarSelect, cargarTrabajadores } = opts;
            const filtros = leer();
            if (!filtros || !filtros.cia) return false;

            const cboCia = document.getElementById('cboCompania');
            const cboPt = document.getElementById('cboTipoPlanilla');
            const cboProc = document.getElementById('cboProceso');
            const cboPer = document.getElementById('cboPeriodo');
            const cboTrab = document.getElementById('cboTrabajador');
            if (!cboCia || !cboPt || !cboProc || !cboPer || !cboTrab) return false;

            const cia = String(filtros.cia).trim();
            if (!optionExists(cboCia, cia)) return false;
            cboCia.value = cia;

            await poblarSelect(`/api/selectores/planillas?cia=${encodeURIComponent(cia)}`, cboPt);

            const payroll = filtros.payroll != null ? String(filtros.payroll).trim() : '';
            if (!payroll || !optionExists(cboPt, payroll)) {
                if (typeof cargarTrabajadores === 'function') await cargarTrabajadores();
                guardar();
                return true;
            }
            cboPt.value = payroll;

            await poblarSelect(
                `/api/selectores/procesos?cia=${encodeURIComponent(cia)}&payrolltype=${encodeURIComponent(payroll)}`,
                cboProc
            );

            const proceso = filtros.proceso != null ? String(filtros.proceso).trim() : '';
            if (!proceso || !optionExists(cboProc, proceso)) {
                if (typeof cargarTrabajadores === 'function') await cargarTrabajadores();
                guardar();
                return true;
            }
            cboProc.value = proceso;

            await poblarSelect(
                `/api/selectores/periodos?cia=${encodeURIComponent(cia)}&payrolltype=${encodeURIComponent(payroll)}&processtype=${encodeURIComponent(proceso)}`,
                cboPer
            );

            const periodo = filtros.periodo != null ? String(filtros.periodo).trim() : '';
            if (periodo && optionExists(cboPer, periodo)) {
                cboPer.value = periodo;
            }

            if (typeof cargarTrabajadores === 'function') {
                await cargarTrabajadores();
            }

            const trabajador = filtros.trabajador != null ? String(filtros.trabajador).trim() : '';
            if (trabajador && optionExists(cboTrab, trabajador)) {
                cboTrab.value = trabajador;
            }

            guardar();
            return true;
        }

        function registrarGuardadoEnCambio() {
            ['cboCompania', 'cboTipoPlanilla', 'cboProceso', 'cboPeriodo', 'cboTrabajador'].forEach((id) => {
                const el = document.getElementById(id);
                if (el) el.addEventListener('change', guardar);
            });
        }

        return {
            STORAGE_KEY: STORAGE_KEY_CALCULO_QUINTA_TRAB,
            guardar,
            leer,
            aplicarRestauracionCascada,
            registrarGuardadoEnCambio
        };
    }

    global.FiltrosPlanillasReportes = {
        STORAGE_KEY_RESUMEN_TOTAL,
        STORAGE_KEY_PROMEDIO_LIQ,
        STORAGE_KEY_PLANILLA_VERTICAL,
        STORAGE_KEY_VACACIONES_DETALLE,
        STORAGE_KEY_SALDO_VACACIONES,
        STORAGE_KEY_DESCANSOS_MEDICOS_DETALLE,
        STORAGE_KEY_PROCESAR_PLANILLA,
        STORAGE_KEY_LOG_CALCULO,
        STORAGE_KEY_TRABAJADORES,
        STORAGE_KEY_TELECREDITO,
        STORAGE_KEY_INTERBANK,
        STORAGE_KEY_CONTINENTAL,
        STORAGE_KEY_BANBIF,
        STORAGE_KEY_LISTADO_PAGOS,
        STORAGE_KEY_REGISTRO_VACACIONES,
        STORAGE_KEY_REGISTRO_DESCANSOS,
        STORAGE_KEY_APERTURAR_PERIODOS,
        STORAGE_KEY_GENERAR_BOLETAS,
        STORAGE_KEY_CERTIFICADO_TRABAJO,
        STORAGE_KEY_CERTIFICADO_RETIRO_CTS,
        STORAGE_KEY_FORMATO_LIQUIDACION,
        STORAGE_KEY_FORMATO_UTILIDADES,
        STORAGE_KEY_PLANILLA_POR_CONCEPTOS,
        /** Misma lógica que optionExists interno (valor y option.value con trim). */
        optionExistsTrim: optionExists,
        obtenerPeriodoActivo,
        poblarPeriodosConActivo,
        obtenerConceptoNeto,
        poblarConceptosConNeto,
        resumenTotal: function () {
            return crearPersistenciaResumenTotal();
        },
        promedioLiquidaciones: function () {
            return crearPersistenciaReporte(STORAGE_KEY_PROMEDIO_LIQ, true);
        },
        planillaVertical: function () {
            return crearPersistenciaReporte(STORAGE_KEY_PLANILLA_VERTICAL, true, true, true, true);
        },
        planillaConsolidada: function () {
            return crearPersistenciaReporteConsolidada(STORAGE_KEY_PLANILLA_CONSOLIDADA, true, true, true, true);
        },
        vacacionesDetalle: function () {
            return crearPersistenciaVacacionesDetalle();
        },
        saldoVacaciones: function () {
            return crearPersistenciaSaldoVacaciones();
        },
        descansosMedicosDetalle: function () {
            return crearPersistenciaDescansosMedicosDetalle();
        },
        procesarPlanilla: function () {
            return crearPersistenciaProcesarPlanilla();
        },
        logCalculo: function () {
            return crearPersistenciaReporte(STORAGE_KEY_LOG_CALCULO, true);
        },
        trabajadores: function () {
            return crearPersistenciaTrabajadores();
        },
        telecredito: function () {
            return crearPersistenciaPagoHaberes(STORAGE_KEY_TELECREDITO, false);
        },
        interbank: function () {
            return crearPersistenciaPagoHaberes(STORAGE_KEY_INTERBANK, false);
        },
        continental: function () {
            return crearPersistenciaPagoHaberes(STORAGE_KEY_CONTINENTAL, true);
        },
        banbif: function () {
            return crearPersistenciaPagoHaberes(STORAGE_KEY_BANBIF, true);
        },
        listadoPagos: function () {
            return crearPersistenciaPagoHaberes(STORAGE_KEY_LISTADO_PAGOS, false, true);
        },
        asignacionConceptos: function () {
            return crearPersistenciaAsignacionConceptos();
        },
        registroVacaciones: function () {
            return crearPersistenciaRegistroVacaciones();
        },
        registroDescansosMedicos: function () {
            return crearPersistenciaRegistroDescansosMedicos();
        },
        aperturarPeriodos: function () {
            return crearPersistenciaAperturarPeriodos();
        },
        plameArchivo14: function () {
            return crearPersistenciaPlameArchivo14();
        },
        plameArchivo15: function () {
            return crearPersistenciaPlameArchivo15();
        },
        plameArchivo18: function () {
            return crearPersistenciaPlameArchivo18();
        },
        plameArchivo26: function () {
            return crearPersistenciaPlameArchivo26();
        },
        plameArchivos720: function () {
            return crearPersistenciaPlameArchivos720();
        },
        plameTRegistro: function () {
            return crearPersistenciaPlameTRegistro();
        },
        plameValidar: function () {
            return crearPersistenciaPlameValidar();
        },
        declaracionAfp: function () {
            return crearPersistenciaDeclaracionAfp();
        },
        controlPagosAfp: function () {
            return crearPersistenciaControlPagosAfp();
        },
        conceptos: function () {
            return crearPersistenciaConceptos();
        },
        generarBoletas: function () {
            return crearPersistenciaGenerarBoletas();
        },
        certificadoTrabajo: function () {
            return crearPersistenciaCertificadoTrabajo();
        },
        certificadoRetiroCts: function () {
            return crearPersistenciaCertificadoRetiroCts();
        },
        formatoLiquidacion: function () {
            return crearPersistenciaFormatoLiquidacion();
        },
        formatoUtilidades: function () {
            return crearPersistenciaFormatoUtilidades();
        },
        planillaPorConceptos: function () {
            return crearPersistenciaPlanillaPorConceptos();
        },
        certificadoQuinta: function () {
            return crearPersistenciaCertificadoQuinta();
        },
        calculoQuintaTrabajador: function () {
            return crearPersistenciaCalculoQuintaTrabajador();
        }
    };
})(typeof window !== 'undefined' ? window : this);
