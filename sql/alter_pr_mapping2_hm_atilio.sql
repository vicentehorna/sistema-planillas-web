/*
  Alinear dbo.PR_mapping2 de hm_atilio con hm_aci2.
  Columnas faltantes: 20 (todas NULLABLE, como en origen).

  Ejecutar en: hm_atilio
*/
USE hm_atilio;
GO

ALTER TABLE dbo.[PR_mapping2] ADD [latitud] numeric(19,7) NULL;
ALTER TABLE dbo.[PR_mapping2] ADD [longitud] numeric(19,7) NULL;
ALTER TABLE dbo.[PR_mapping2] ADD [distancia] numeric(19,4) NULL;

ALTER TABLE dbo.[PR_mapping2] ADD [firma_x] int NULL;
ALTER TABLE dbo.[PR_mapping2] ADD [firma_y] int NULL;
ALTER TABLE dbo.[PR_mapping2] ADD [firma_w] int NULL;
ALTER TABLE dbo.[PR_mapping2] ADD [firma_h] int NULL;

ALTER TABLE dbo.[PR_mapping2] ADD [logo5ta_x] int NULL;
ALTER TABLE dbo.[PR_mapping2] ADD [logo5ta_y] int NULL;
ALTER TABLE dbo.[PR_mapping2] ADD [logo5ta_w] int NULL;
ALTER TABLE dbo.[PR_mapping2] ADD [logo5ta_h] int NULL;

ALTER TABLE dbo.[PR_mapping2] ADD [firmaliq_x] int NULL;
ALTER TABLE dbo.[PR_mapping2] ADD [firmaliq_y] int NULL;
ALTER TABLE dbo.[PR_mapping2] ADD [firmaliq_w] int NULL;
ALTER TABLE dbo.[PR_mapping2] ADD [firmaliq_h] int NULL;

ALTER TABLE dbo.[PR_mapping2] ADD [RutaComprobantesWeb] varchar(255) NULL;
ALTER TABLE dbo.[PR_mapping2] ADD [diasvacaciones] int NULL;
ALTER TABLE dbo.[PR_mapping2] ADD [logoweb] varchar(255) NULL;
ALTER TABLE dbo.[PR_mapping2] ADD [FlagEssaludVida] char(1) NULL;
ALTER TABLE dbo.[PR_mapping2] ADD [flagloan] char(1) NULL;
GO
