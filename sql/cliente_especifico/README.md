# SPs de cálculo por proceso — NO desplegar vía consolidado

Estos procedimientos **varían por cliente**. No deben ir en
`deploy_planillas_web_completo.sql` ni sobrescribirse al actualizar una BD.

Incluye:
- `sp_pr_calcular_finmes_persona`
- `sp_pr_calcular_gratificacion_persona`
- `sp_pr_calcular_liquidacion_persona`
- `sp_pr_calcular_quincena_persona`
- `sp_pr_calcular_provcts_persona`
- `sp_pr_calcular_provgrati_persona`
- `sp_pr_calcular_provvac_persona`

La app usa `PR_ProcessType.ProcedureName` de cada BD cliente.

Sí se despliegan (carpeta `sql/`):
- `sp_pr_calcularplanillas_web.sql`
- `sp_pr_calcularplanillas_masivo_web.sql`

Referencia histórica únicamente. No ejecutar en masa sobre clientes.
