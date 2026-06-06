/**
 * Persistencia autónoma por reporte (localStorage).
 * IDs: cboCompania, cboTipoPlanilla, cboProceso, cboPeriodo; opcional cboTrabajador (solo Promedio).
 */
(function (global) {
    const STORAGE_KEY_RESUMEN_TOTAL = 'filtros_resumen_total';
    const STORAGE_KEY_PROMEDIO_LIQ = 'filtros_promedio_liq';
    const STORAGE_KEY_PLANILLA_VERTICAL = 'filtros_planilla_vertical';
    const STORAGE_KEY_VACACIONES_DETALLE = 'filtros_vacaciones_detalle';
    const STORAGE_KEY_SALDO_VACACIONES = 'filtros_saldo_vacaciones';
    const STORAGE_KEY_DESCANSOS_MEDICOS_DETALLE = 'filtros_descansos_medicos_detalle';
    const STORAGE_KEY_PROCESAR_PLANILLA = 'filtros_procesar_planilla';
    const STORAGE_KEY_TRABAJADORES = 'filtros_trabajadores';
    const STORAGE_KEY_TELECREDITO = 'filtros_pago_haberes_telecredito';
    const STORAGE_KEY_INTERBANK = 'filtros_pago_haberes_interbank';
    const STORAGE_KEY_CONTINENTAL = 'filtros_pago_haberes_continental';
    const STORAGE_KEY_BANBIF = 'filtros_pago_haberes_banbif';
    const STORAGE_KEY_LISTADO_PAGOS = 'filtros_listado_pagos';

    function val(id) {
        const el = document.getElementById(id);
        return el && el.value != null ? String(el.value).trim() : '';
    }

    function optionExists(select, value) {
        if (!select || value === '' || value == null) return false;
        const v = String(value).trim();
        return Array.prototype.some.call(select.options, (o) => String(o.value).trim() === v);
    }

    /**
     * @param {string} storageKey
     * @param {boolean} incluyeEmpleado
     * @param {boolean} incluyeBancoHaberes
     */
    function crearPersistenciaReporte(storageKey, incluyeEmpleado, incluyeBancoHaberes) {
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

            const { poblarSelect, poblarBancosHaberes } = opts;
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

            await poblarSelect(
                `/api/selectores/periodos?cia=${encodeURIComponent(cia)}&payrolltype=${encodeURIComponent(payroll)}&processtype=${encodeURIComponent(proceso)}`,
                cboPer
            );

            const periodo = filtros.periodo != null ? String(filtros.periodo).trim() : '';
            if (periodo && optionExists(cboPer, periodo)) {
                cboPer.value = periodo;
            }

            if (incluyeEmpleado) {
                const cboTra = document.getElementById('cboTrabajador');
                if (cboTra) {
                    await poblarSelect(`/api/selectores/trabajadores?cia=${encodeURIComponent(cia)}`, cboTra);
                    const person = filtros.person != null ? String(filtros.person).trim() : '';
                    if (person && optionExists(cboTra, person)) {
                        cboTra.value = person;
                    }
                }
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

            const { poblarSelect, poblarBancosHaberes } = opts;
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
            await poblarSelect(`/api/selectores/conceptos?cia=${encodeURIComponent(cia)}`, cboConcepto);

            const payroll = filtros.payroll != null ? String(filtros.payroll).trim() : '';
            if (!payroll || !optionExists(cboPt, payroll)) {
                guardar();
                return true;
            }
            cboPt.value = payroll;

            const concept = filtros.concept != null ? String(filtros.concept).trim() : '';
            if (concept && optionExists(cboConcepto, concept)) {
                cboConcepto.value = concept;
            }

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

            await poblarSelect(
                `/api/selectores/periodos?cia=${encodeURIComponent(cia)}&payrolltype=${encodeURIComponent(payroll)}&processtype=${encodeURIComponent(proceso)}`,
                cboPer
            );

            const periodo = filtros.periodo != null ? String(filtros.periodo).trim() : '';
            if (periodo && optionExists(cboPer, periodo)) {
                cboPer.value = periodo;
            }

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

            guardar();
            return true;
        }

        function registrarGuardadoEnCambio() {
            [
                'cboCompania', 'cboTipoPlanilla', 'cboProceso', 'cboPeriodo',
                'cboMoneda', 'cboConcepto', 'cboCesados'
            ].forEach((id) => {
                const el = document.getElementById(id);
                if (el) el.addEventListener('change', guardar);
            });
            const txtFechaPago = document.getElementById('txtFechaPago');
            if (txtFechaPago) txtFechaPago.addEventListener('change', guardar);
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

            const { poblarSelect, poblarBancosHaberes } = opts;
            const filtros = leer();
            if (!filtros || !filtros.cia) return false;

            const cboCia = document.getElementById('cboCompania');
            const cboPt = document.getElementById('cboTipoPlanilla');
            if (!cboCia || !cboPt) return false;

            const cia = String(filtros.cia).trim();
            if (!optionExists(cboCia, cia)) return false;
            cboCia.value = cia;

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

            guardar();
            return true;
        }

        function registrarGuardadoEnCambio() {
            ['cboCompania', 'cboTipoPlanilla', 'cboTrabajador', 'cboEstado', 'cboCesados', 'cboBancoHaberes'].forEach((id) => {
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

    global.FiltrosPlanillasReportes = {
        STORAGE_KEY_RESUMEN_TOTAL,
        STORAGE_KEY_PROMEDIO_LIQ,
        STORAGE_KEY_PLANILLA_VERTICAL,
        STORAGE_KEY_VACACIONES_DETALLE,
        STORAGE_KEY_SALDO_VACACIONES,
        STORAGE_KEY_DESCANSOS_MEDICOS_DETALLE,
        STORAGE_KEY_PROCESAR_PLANILLA,
        STORAGE_KEY_TRABAJADORES,
        STORAGE_KEY_TELECREDITO,
        STORAGE_KEY_INTERBANK,
        STORAGE_KEY_CONTINENTAL,
        STORAGE_KEY_BANBIF,
        STORAGE_KEY_LISTADO_PAGOS,
        /** Misma lógica que optionExists interno (valor y option.value con trim). */
        optionExistsTrim: optionExists,
        resumenTotal: function () {
            return crearPersistenciaReporte(STORAGE_KEY_RESUMEN_TOTAL, false);
        },
        promedioLiquidaciones: function () {
            return crearPersistenciaReporte(STORAGE_KEY_PROMEDIO_LIQ, true);
        },
        planillaVertical: function () {
            return crearPersistenciaReporte(STORAGE_KEY_PLANILLA_VERTICAL, true, true);
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
            return crearPersistenciaPagoHaberes(STORAGE_KEY_CONTINENTAL, false);
        },
        banbif: function () {
            return crearPersistenciaPagoHaberes(STORAGE_KEY_BANBIF, true);
        },
        listadoPagos: function () {
            return crearPersistenciaPagoHaberes(STORAGE_KEY_LISTADO_PAGOS, false, true);
        }
    };
})(typeof window !== 'undefined' ? window : this);
