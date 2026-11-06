-- hm_zilicom: TXT Softland clásico para Interfaz Asientos.
-- Fecha documento = último día del mes del Periodo (YYYYMM / YYYYMMDD).
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_asientozilicom]
@Voucher		varchar(20)
AS
BEGIN

declare @codigo varchar(4), @titulo varchar(100)
declare @periodo_ym varchar(6)
declare @fecha_fin_mes date
declare @fechadoc varchar(10)

select @titulo = Title, @periodo_ym = LEFT(LTRIM(RTRIM(Period)), 6)
from AC_Voucher where Voucher = @Voucher

-- Periodo planilla YYYYMM… → último día de ese mes (antes: year-01-month → enero).
set @fecha_fin_mes = EOMONTH(CONVERT(date, @periodo_ym + '01', 112))
set @fechadoc =
	CONVERT(varchar(4), YEAR(@fecha_fin_mes)) + '/'
	+ RIGHT('00' + CONVERT(varchar(2), MONTH(@fecha_fin_mes)), 2) + '/'
	+ RIGHT('00' + CONVERT(varchar(2), DAY(@fecha_fin_mes)), 2)

CREATE TABLE #temporal(
indicador         varchar(2) null,
fechadoc varchar(20) null,
nroperiodo  varchar(10) null,
nrooperacion  varchar(20) null,
DocNumInterno varchar(20) null,
DocDetLinea varchar(20) null,
CtaCodigo varchar(20) null,
MonCodigo varchar(20) null,
CreCodigo varchar(20) null,
CdiCodigo varchar(20) null,
TprId varchar(20) null,
PryNumero varchar(20) null,
Rut varchar(20) null,
SucNumero varchar(20) null,
DocGlosa varchar(100) null,
DocTipoDocCalce varchar(20) null,
DocNumDocCalce varchar(25) null,
DocNumCuotaCalce varchar(20) null,
DocFechaVenc varchar(10) null,
DocMontoImpuDebe varchar(18) null,
DocMontoImpuHaber varchar(18) null,
DocMontoLocalDebe varchar(18) null,
DocMontoLocalHaber varchar(18) null,
InstId varchar(3) null,
PlaId varchar(3) null,
GlosaBenef varchar(60) null,
ProPagFormaId  varchar(3) null,
CfiCodigo varchar(9) null,
UniCodigoExt varchar(4) null,
LineaProducto varchar(9) null,
ClcId  varchar(3) null
)


insert into  #temporal
SELECT
'01',
@fechadoc,
'0000',
'019',
'000000000',
replicate('0', 9 - len(convert(varchar(4), AC_VoucherDetail.Line))) + convert(varchar(4), AC_VoucherDetail.Line),
replicate('0',9 - len(AC_VoucherDetail.AccountCode)) + AC_VoucherDetail.AccountCode,
'01',
case when left(isnull(AC_VoucherDetail.AccountCode,''),1) = '9' then '00000'  + case when isnull(AC_VoucherDetail.CostCenterCode,'') = '' then '00000' else   replicate('0',4 - len(isnull(AC_VoucherDetail.CostCenterCode,''))) +  isnull(AC_VoucherDetail.CostCenterCode,'') +'0'  end else '0000000000' end,
'00000001',
'000',
'000000000',
isnull(AC_VoucherDetail.person,'') + replicate(' ',12 - len(isnull(AC_VoucherDetail.person,''))),
'0001',
right(isnull(AC_Voucher.Title,''),60)+replicate(' ', 60 - len(isnull(AC_Voucher.Title,''))),
'090',
'0000000000000000000000000',
'0000',
@fechadoc,
case when ISNULL(AC_VoucherDetail.AmountLo,0.0000) > 0 then replicate('0',18 - len(replace(convert(varchar(20),convert(decimal(18,4),ISNULL(AC_VoucherDetail.AmountLo,0.0000))),'.',''))) + replace(convert(varchar(20),convert(decimal(18,4),ISNULL(AC_VoucherDetail.AmountLo,0.0000))),'.','') else replicate('0',18) end,
case when ISNULL(AC_VoucherDetail.AmountLo,0.0000) < 0 then replicate('0',18 - len(replace(convert(varchar(20),convert(decimal(18,4),abs(ISNULL(AC_VoucherDetail.AmountLo,0.0000)))),'.',''))) + replace(convert(varchar(20),convert(decimal(18,4),abs(ISNULL(AC_VoucherDetail.AmountLo,0.0000)))),'.','') else replicate('0',18) end,
case when ISNULL(AC_VoucherDetail.AmountLo,0.0000) > 0 then replicate('0',18 - len(replace(convert(varchar(20),convert(decimal(18,4),ISNULL(AC_VoucherDetail.AmountLo,0.0000))),'.',''))) + replace(convert(varchar(20),convert(decimal(18,4),ISNULL(AC_VoucherDetail.AmountLo,0.0000))),'.','') else replicate('0',18) end,
case when ISNULL(AC_VoucherDetail.AmountLo,0.0000) < 0 then replicate('0',18 - len(replace(convert(varchar(20),convert(decimal(18,4),abs(ISNULL(AC_VoucherDetail.AmountLo,0.0000)))),'.',''))) + replace(convert(varchar(20),convert(decimal(18,4),abs(ISNULL(AC_VoucherDetail.AmountLo,0.0000)))),'.','') else replicate('0',18) end,
'000',
'000',
replicate(' ',60),
'000',
'000000000',
'0000',
'000000000',
'000'
FROM   AC_Account  inner join  AC_VoucherDetail  ON  AC_Account.Account  =
       AC_VoucherDetail.Account INNER JOIN  AC_Voucher ON  AC_Voucher.Voucher =  AC_VoucherDetail.Voucher  LEFT JOIN  SY_Person  ON  SY_Person.Person  =
       AC_VoucherDetail.Person
WHERE         (AC_VoucherDetail.Voucher  = @Voucher)


select
indicador,
fechadoc,
nroperiodo,
nrooperacion,
DocNumInterno,
DocDetLinea,
CtaCodigo,
MonCodigo,
CreCodigo,
CdiCodigo,
TprId,
PryNumero,
Rut,
SucNumero,
DocGlosa,
DocTipoDocCalce,
DocNumDocCalce,
DocNumCuotaCalce,
DocFechaVenc,
DocMontoImpuDebe,
DocMontoImpuHaber,
DocMontoLocalDebe,
DocMontoLocalHaber,
InstId,
PlaId,
GlosaBenef,
ProPagFormaId,
CfiCodigo,
UniCodigoExt,
LineaProducto,
ClcId
from #temporal


END
GO
