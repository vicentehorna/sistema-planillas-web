# Pendiente: workspace multiventana (estilo escritorio)

> **Estado:** guardado para implementación futura. No desarrollado aún.

## Problema

En el sistema cliente-servidor (PowerBuilder / MDI), los usuarios podían:

- Mantener varias ventanas abiertas y cargadas a la vez.
- Cambiar entre ellas con un selector sin recargar.
- Conservar grillas, filtros y datos en memoria.

En la versión web actual, cada navegación recarga la página. La persistencia de filtros (`localStorage`) ayuda, pero no reproduce la experiencia de “ventanas ya abiertas”.

## Solución recomendada

**Workspace con pestañas internas + iframes embebidos.**

1. Un contenedor fijo (sidebar + barra de pestañas).
2. Cada opción del menú abre o activa una pestaña.
3. La pantalla Flask se carga **una vez** en un `iframe` con `?embed=1`.
4. Al cambiar de pestaña, el iframe se oculta pero **no se destruye** → conserva estado.
5. Al cerrar la pestaña, se elimina el iframe y se libera memoria.

## Por qué iframes (y no SPA completa)

- El proyecto es Flask multipágina con ~52 pantallas.
- Cada pantalla tiene JS con `DOMContentLoaded` e IDs repetidos (`cboCompania`, etc.).
- Montar varias pantallas en el mismo documento causaría colisiones.
- Los iframes aíslan cada interfaz sin reescribir todo.

## Fases propuestas

| Fase | Alcance | Esfuerzo | ¿Solución completa? |
|------|---------|----------|---------------------|
| 0 | Usar pestañas del navegador (Ctrl+clic en menú) | Cero | No (parche inmediato) |
| 1 | Modo `embed=1` / `layout_embed.html` sin sidebar | Bajo | No (solo prerequisito técnico) |
| 2 | Ruta `/workspace` con tab bar + iframes | Medio | **Sí** (experiencia MDI) |
| 3 | Piloto: Trabajadores, Asignación conceptos, Procesar planilla | Medio | Extensión de Fase 2 |
| 4 | Resto del menú + persistencia de pestañas en sesión | Medio | Extensión de Fase 2 |

**Opción ideal para reproducir PowerBuilder:** Fase 2 (esfuerzo medio), precedida por Fase 1.

- **Fase 0** sirve como medida inmediata sin desarrollo, pero cada ventana queda en una pestaña de Chrome separada, sin integración con el menú del sistema.
- **Fase 1** prepara las pantallas para cargarse dentro de un iframe sin duplicar el sidebar; no entrega la experiencia multiventana por sí sola.
- **Fase 2** es la solución real: shell fijo + pestañas internas + iframes.

Ruta sugerida: **Fase 1 → Fase 2 → piloto (3 pantallas) → resto del menú**.

---

## ¿Cómo se verían las ventanas?

No habrá un selector interno de ventanas (como el listado MDI de PowerBuilder). La experiencia sería:

```
┌─────────────┬──────────────────────────────────────────────────┐
│             │ [Trabajadores] [Asignación ×] [Procesar planilla]  │  ← barra de pestañas
│   SIDEBAR   ├──────────────────────────────────────────────────┤
│   (menú)    │                                                  │
│   siempre   │     Contenido de la pestaña activa               │
│   visible   │     (un iframe con la pantalla Flask)            │
│             │                                                  │
└─────────────┴──────────────────────────────────────────────────┘
```

- El **menú lateral** sigue visible (no se duplica dentro del iframe gracias a `?embed=1`).
- Arriba aparece una **barra de pestañas** (estilo Chrome o Excel).
- Solo se ve **una pantalla a la vez** (la pestaña activa).
- Las demás quedan **ocultas pero vivas** en memoria del navegador (conservan filtros, grillas, etc.).
- Cerrar una pestaña (×) destruye el iframe y libera memoria en la PC del usuario.

---

## ¿Va a hacer lenta la navegación?

Depende de qué se entienda por “navegar”:

| Acción | Web actual | Workspace con pestañas |
|--------|------------|------------------------|
| Abrir una pantalla nueva | Carga completa de página | Igual: carga **una vez** al abrir la pestaña |
| Volver a una pantalla ya abierta | Vuelve a cargar todo | **Instantáneo**: solo se muestra el iframe oculto |
| Tener varias pantallas abiertas | No es posible (solo una) | Usa **más RAM en el navegador del usuario**, pero el cambio entre pestañas es rápido |

Conclusiones:

- **Cambiar entre ventanas ya abiertas → más rápido** que hoy (equivalente a PowerBuilder).
- **Abrir muchas ventanas a la vez → más pesado** en la PC del usuario (por eso el límite de pestañas).
- El **servidor Flask no se vuelve más lento** por tener iframes; el costo principal en servidor es cada petición HTTP/API, igual que hoy.
- El riesgo en servidor aparece si las pestañas ocultas siguen haciendo **consultas o timers en segundo plano** (multiplica carga concurrente a la BD).

---

## Contexto de producción actual

Restricciones a considerar para elegir la mejor opción:

| Factor | Valor actual |
|--------|--------------|
| Usuarios concurrentes | Hasta **7** |
| Hosting | **Render Starter — 512 MB RAM** |
| Stack | Flask + SQL Server remoto |

### Dónde va la RAM (importante)

| Componente | ¿Dónde vive? | Impacto en Render 512 MB |
|------------|--------------|---------------------------|
| Páginas abiertas en iframes | Navegador del usuario (PC) | Casi ninguno en el servidor |
| Flask + Python + librerías | Servidor Render | Alto (base fija ~150–250 MB) |
| Cada petición HTTP / API / cálculo | Servidor Render | Pico temporal por usuario |
| Sesión Flask por usuario | Servidor Render | Bajo |
| Conexiones a SQL Server | Servidor Render | Moderado |

La multiventana con iframes **no duplica la RAM del servidor** como si las ventanas vivieran en Render. Lo que carga el servidor es **cada petición de página o API**, igual que en la navegación actual.

Con **512 MB y 7 usuarios** el plan ya va ajustado para Flask + SQL Server, con o sin multiventana. Si varios usuarios ejecutan cálculos o reportes pesados al mismo tiempo, puede haber lentitud o reinicios. El cuello de botella más probable es el **plan de hosting**, más que las ventanas en sí.

---

## Recomendación según restricciones de hosting

| Prioridad | Recomendación |
|-----------|---------------|
| **Corto plazo (ahora, 512 MB)** | **Fase 0**: Ctrl+clic en menú para abrir en pestaña nueva del navegador. Cero desarrollo, mínimo impacto en servidor (cada usuario suele tener una pantalla activa pidiendo datos). |
| **Mediano plazo (objetivo UX)** | **Fase 2 en modo conservador**: máx. **3–4 pestañas** (no 6–8), sin actividad en pestañas ocultas, carga lazy del iframe. |
| **Hosting** | Con 7 usuarios en producción, valorar subir a **Render Standard (2 GB)** al implementar workspace o si hay lentitud en horas pico. |

### Fase 2 viable en 512 MB solo si se implementa con salvaguardas

- Máximo **3–4 pestañas** abiertas por usuario (no 6–8).
- Al ocultar un iframe, **pausar** timers y consultas automáticas (`visibilitychange`, etc.).
- Cargar el iframe **solo la primera vez** que se abre la pestaña.
- Aviso al usuario al intentar superar el límite.
- Procesos largos (cálculo, importación) pueden seguir en pestaña oculta, pero sin polling innecesario.

---

## Límites a definir

- Máximo sugerido en producción actual (512 MB): **3–4 interfaces abiertas** por usuario.
- Máximo general (con hosting ampliado): **6–8 interfaces abiertas** (memoria del navegador).
- Aviso antes de cerrar pestaña con cambios sin guardar.
- Sesión vencida: resolver en el shell, no dentro del iframe.
- Procesos largos (cálculo, importación) deben poder continuar en pestaña oculta, pero sin consultas de fondo innecesarias.

## Qué evitar

- SPA completa (Vue/React): costo muy alto para el tamaño actual del proyecto.
- Varias pantallas en el mismo DOM sin iframe: IDs duplicados rompen la UI.
- Pestañas ilimitadas sin control de actividad en segundo plano: multiplica carga al servidor y a la BD.

## Referencia

Análisis visual: `canvases/analisis-navegacion-multiventana.canvas.tsx` (Cursor).
