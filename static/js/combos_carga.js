/**
 * Carga robusta de combos dependientes (compañía → planilla → proceso → periodo).
 * Cada combo admite una sola carga vigente: la anterior se aborta y su respuesta se descarta.
 * Si una carga falla, el combo ofrece la opción "Reintentar".
 */
(function (global) {
    const VALOR_REINTENTAR = '__reintentar__';
    const estado = new WeakMap();

    function iniciarCarga(select, reintentar) {
        const prev = estado.get(select);
        if (prev && prev.ctrl) prev.ctrl.abort();
        const ctrl = typeof AbortController !== 'undefined' ? new AbortController() : null;
        const seq = (prev ? prev.seq : 0) + 1;
        estado.set(select, { seq, ctrl, reintentar: reintentar || null });
        select.dataset.cargaSeq = String(seq);
        return {
            signal: ctrl ? ctrl.signal : undefined,
            vigente: () => (estado.get(select) || {}).seq === seq
        };
    }

    function resetSelect(select, texto, valor) {
        if (!select) return;
        iniciarCarga(select, null);
        const v = valor != null ? String(valor) : '';
        select.innerHTML = '';
        const opt = document.createElement('option');
        opt.value = v;
        opt.textContent = texto || 'Seleccione...';
        select.appendChild(opt);
        select.value = v;
        select.disabled = true;
    }

    function mostrarError(select, valor) {
        const v = valor != null ? String(valor) : '';
        select.innerHTML = '';
        const optErr = document.createElement('option');
        optErr.value = v;
        optErr.textContent = 'Error al cargar';
        const optRetry = document.createElement('option');
        optRetry.value = VALOR_REINTENTAR;
        optRetry.textContent = 'Reintentar';
        select.appendChild(optErr);
        select.appendChild(optRetry);
        select.value = v;
        select.disabled = false;
    }

    function valorValido(select) {
        const v = String((select && select.value) || '').trim();
        return v === VALOR_REINTENTAR ? '' : v;
    }

    function textoValido(select) {
        if (!valorValido(select)) return '';
        const opt = select.options[select.selectedIndex];
        return opt ? opt.textContent.trim() : '';
    }

    function seleccionarPorTexto(select, texto) {
        const want = String(texto || '').trim().toUpperCase();
        if (!select || !want) return false;
        const opt = Array.prototype.find.call(
            select.options,
            (o) => o.value !== '' && o.value !== VALOR_REINTENTAR && o.textContent.trim().toUpperCase() === want
        );
        if (!opt) return false;
        select.value = opt.value;
        return true;
    }

    function esAbort(err) {
        return !!(err && err.name === 'AbortError');
    }

    async function fetchJson(url, signal) {
        const res = await fetch(url, { signal });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    }

    /**
     * Combo "Seleccione..." + items {id, text}. Devuelve true solo si la respuesta sigue vigente.
     * opciones.textoVacio: texto de la primera opción cuando la lista llega vacía.
     * opciones.conservarValor: reselecciona el valor previo si existe en la nueva lista.
     */
    async function poblarSelect(url, select, opciones) {
        opciones = opciones || {};
        if (!select) return false;
        const prev = opciones.conservarValor ? valorValido(select) : '';
        const carga = iniciarCarga(select, () => poblarSelect(url, select, opciones));
        select.innerHTML = '<option value="">Cargando...</option>';
        select.disabled = true;
        try {
            const data = await fetchJson(url, carga.signal);
            if (!carga.vigente()) return false;
            const items = Array.isArray(data) ? data : [];
            select.innerHTML = '';
            const def = document.createElement('option');
            def.value = '';
            def.textContent = !items.length && opciones.textoVacio ? opciones.textoVacio : 'Seleccione...';
            select.appendChild(def);
            items.forEach((item) => {
                const opt = document.createElement('option');
                opt.value = item.id != null ? String(item.id) : '';
                opt.textContent = item.text != null ? String(item.text) : opt.value;
                select.appendChild(opt);
            });
            if (prev && Array.prototype.some.call(select.options, (o) => o.value === prev)) {
                select.value = prev;
            }
            select.disabled = false;
            return true;
        } catch (err) {
            if (!carga.vigente() || esAbort(err)) return false;
            console.error(err);
            mostrarError(select, '');
            return false;
        }
    }

    /**
     * Combo con opción "Todos" fija (unidades, centros de costo, perfiles contables).
     * opciones: valorTodos, textoTodos, preferido (valor a reseleccionar), omitirValorTodos.
     */
    async function poblarConTodos(url, select, opciones) {
        opciones = opciones || {};
        if (!select) return false;
        const valorTodos = opciones.valorTodos != null ? String(opciones.valorTodos) : '0';
        const textoTodos = opciones.textoTodos || 'Todos';
        const prev = opciones.preferido != null ? String(opciones.preferido).trim() : (valorValido(select) || valorTodos);
        const carga = iniciarCarga(select, () => poblarConTodos(url, select, Object.assign({}, opciones, { preferido: prev })));
        select.innerHTML = '';
        const optAll = document.createElement('option');
        optAll.value = valorTodos;
        optAll.textContent = textoTodos;
        select.appendChild(optAll);
        select.value = valorTodos;
        if (!url) {
            select.disabled = false;
            return true;
        }
        select.disabled = true;
        try {
            const data = await fetchJson(url, carga.signal);
            if (!carga.vigente()) return false;
            (Array.isArray(data) ? data : []).forEach((item) => {
                const id = item.id != null ? String(item.id).trim() : '';
                if (!id || id === valorTodos) return;
                const opt = document.createElement('option');
                opt.value = id;
                opt.textContent = item.text != null ? String(item.text) : id;
                select.appendChild(opt);
            });
            const existe = Array.prototype.some.call(select.options, (o) => o.value === prev);
            select.value = existe ? prev : valorTodos;
            select.disabled = false;
            return true;
        } catch (err) {
            if (!carga.vigente() || esAbort(err)) return false;
            console.error(err);
            mostrarError(select, valorTodos);
            return false;
        }
    }

    document.addEventListener('change', function (e) {
        const sel = e.target;
        if (!(sel instanceof HTMLSelectElement) || sel.value !== VALOR_REINTENTAR) return;
        e.stopPropagation();
        const st = estado.get(sel);
        if (st && typeof st.reintentar === 'function') st.reintentar();
    }, true);

    global.CombosCarga = {
        VALOR_REINTENTAR,
        iniciarCarga,
        resetSelect,
        mostrarError,
        valorValido,
        textoValido,
        seleccionarPorTexto,
        poblarSelect,
        poblarConTodos
    };
})(window);
