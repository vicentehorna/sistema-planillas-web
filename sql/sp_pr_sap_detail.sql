/*
    Detalle SAP (Interfaz Asientos / DET_*.xls) — hm_divisa.

    Fix: líneas de cuentas 9xxxxx prorrateadas por PR_DistribucionVoucher
    sin persona/distribución dejaban Debit/Credit en NULL (Amount * NULL),
    descuadrando el Excel mientras el voucher y el reporte sí cuadraban.
    Se usa ISNULL(valor, 100) igual que sp_pr_reporte_asiento_contable_web.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_sap_detail]
@voucher varchar(20)
as
begin
	declare @fecha varchar(8), @glosa varchar(255), @titulo varchar(255), @cia char(4), @period varchar(8)
	

	select @fecha = RIGHT(Title,6), @titulo = Title, @cia = Company, @period = Period from AC_Voucher where Voucher = @voucher
	
	if CHARINDEX('LIQUIDA',@titulo) > 0
	begin
		if RIGHT(@fecha,2) = '01' set @glosa = 'LIQUIDACION - ' + 'ENERO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '02' set @glosa = 'LIQUIDACION - ' + 'FEBRERO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '03' set @glosa = 'LIQUIDACION - ' + 'MARZO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '04' set @glosa = 'LIQUIDACION - ' + 'ABRIL ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '05' set @glosa = 'LIQUIDACION - ' + 'MAYO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '06' set @glosa = 'LIQUIDACION - ' + 'JUNIO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '07' set @glosa = 'LIQUIDACION - ' + 'JULIO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '08' set @glosa = 'LIQUIDACION - ' + 'AGOSTO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '09' set @glosa = 'LIQUIDACION - ' + 'SETIEMBRE ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '10' set @glosa = 'LIQUIDACION - ' + 'OCTUBRE ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '11' set @glosa = 'LIQUIDACION - ' + 'NOVIEMBRE ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '12' set @glosa = 'LIQUIDACION - ' + 'DICIEMBRE ' + LEFT(@fecha,4)
	end
	
	if CHARINDEX('MENSUAL',@titulo) > 0
	begin
		if RIGHT(@fecha,2) = '01' set @glosa = 'PLANILLA DE SUELDOS - ' + 'ENERO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '02' set @glosa = 'PLANILLA DE SUELDOS - ' + 'FEBRERO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '03' set @glosa = 'PLANILLA DE SUELDOS - ' + 'MARZO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '04' set @glosa = 'PLANILLA DE SUELDOS - ' + 'ABRIL ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '05' set @glosa = 'PLANILLA DE SUELDOS - ' + 'MAYO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '06' set @glosa = 'PLANILLA DE SUELDOS - ' + 'JUNIO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '07' set @glosa = 'PLANILLA DE SUELDOS - ' + 'JULIO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '08' set @glosa = 'PLANILLA DE SUELDOS - ' + 'AGOSTO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '09' set @glosa = 'PLANILLA DE SUELDOS - ' + 'SETIEMBRE ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '10' set @glosa = 'PLANILLA DE SUELDOS - ' + 'OCTUBRE ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '11' set @glosa = 'PLANILLA DE SUELDOS - ' + 'NOVIEMBRE ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '12' set @glosa = 'PLANILLA DE SUELDOS - ' + 'DICIEMBRE ' + LEFT(@fecha,4)
	end
	
	if CHARINDEX('PROVISION CTS',@titulo) > 0
	begin
		if RIGHT(@fecha,2) = '01' set @glosa = 'PROVISION DE CTS - ' + 'ENERO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '02' set @glosa = 'PROVISION DE CTS - ' + 'FEBRERO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '03' set @glosa = 'PROVISION DE CTS - ' + 'MARZO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '04' set @glosa = 'PROVISION DE CTS - ' + 'ABRIL ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '05' set @glosa = 'PROVISION DE CTS - ' + 'MAYO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '06' set @glosa = 'PROVISION DE CTS - ' + 'JUNIO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '07' set @glosa = 'PROVISION DE CTS - ' + 'JULIO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '08' set @glosa = 'PROVISION DE CTS - ' + 'AGOSTO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '09' set @glosa = 'PROVISION DE CTS - ' + 'SETIEMBRE ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '10' set @glosa = 'PROVISION DE CTS - ' + 'OCTUBRE ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '11' set @glosa = 'PROVISION DE CTS - ' + 'NOVIEMBRE ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '12' set @glosa = 'PROVISION DE CTS - ' + 'DICIEMBRE ' + LEFT(@fecha,4)
	end
	
	if CHARINDEX('PROVISION GRATIFICACION',@titulo) > 0
	begin
		if RIGHT(@fecha,2) = '01' set @glosa = 'PROVISION DE GRATIFICACION - ' + 'ENERO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '02' set @glosa = 'PROVISION DE GRATIFICACION - ' + 'FEBRERO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '03' set @glosa = 'PROVISION DE GRATIFICACION - ' + 'MARZO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '04' set @glosa = 'PROVISION DE GRATIFICACION - ' + 'ABRIL ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '05' set @glosa = 'PROVISION DE GRATIFICACION - ' + 'MAYO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '06' set @glosa = 'PROVISION DE GRATIFICACION - ' + 'JUNIO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '07' set @glosa = 'PROVISION DE GRATIFICACION - ' + 'JULIO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '08' set @glosa = 'PROVISION DE GRATIFICACION - ' + 'AGOSTO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '09' set @glosa = 'PROVISION DE GRATIFICACION - ' + 'SETIEMBRE ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '10' set @glosa = 'PROVISION DE GRATIFICACION - ' + 'OCTUBRE ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '11' set @glosa = 'PROVISION DE GRATIFICACION - ' + 'NOVIEMBRE ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '12' set @glosa = 'PROVISION DE GRATIFICACION - ' + 'DICIEMBRE ' + LEFT(@fecha,4)
	end
	
	if CHARINDEX('PROVISION VACACIONES',@titulo) > 0
	begin
		if RIGHT(@fecha,2) = '01' set @glosa = 'PROVISION DE VACACIONES - ' + 'ENERO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '02' set @glosa = 'PROVISION DE VACACIONES - ' + 'FEBRERO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '03' set @glosa = 'PROVISION DE VACACIONES - ' + 'MARZO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '04' set @glosa = 'PROVISION DE VACACIONES - ' + 'ABRIL ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '05' set @glosa = 'PROVISION DE VACACIONES - ' + 'MAYO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '06' set @glosa = 'PROVISION DE VACACIONES - ' + 'JUNIO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '07' set @glosa = 'PROVISION DE VACACIONES - ' + 'JULIO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '08' set @glosa = 'PROVISION DE VACACIONES - ' + 'AGOSTO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '09' set @glosa = 'PROVISION DE VACACIONES - ' + 'SETIEMBRE ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '10' set @glosa = 'PROVISION DE VACACIONES - ' + 'OCTUBRE ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '11' set @glosa = 'PROVISION DE VACACIONES - ' + 'NOVIEMBRE ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '12' set @glosa = 'PROVISION DE VACACIONES - ' + 'DICIEMBRE ' + LEFT(@fecha,4)
	end

	if CHARINDEX('EMPLEADOS-VACACIONES',@titulo) > 0
	begin
		if RIGHT(@fecha,2) = '01' set @glosa = 'VACACIONES - ' + 'ENERO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '02' set @glosa = 'VACACIONES - ' + 'FEBRERO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '03' set @glosa = 'VACACIONES - ' + 'MARZO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '04' set @glosa = 'VACACIONES - ' + 'ABRIL ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '05' set @glosa = 'VACACIONES - ' + 'MAYO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '06' set @glosa = 'VACACIONES - ' + 'JUNIO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '07' set @glosa = 'VACACIONES - ' + 'JULIO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '08' set @glosa = 'VACACIONES - ' + 'AGOSTO ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '09' set @glosa = 'VACACIONES - ' + 'SETIEMBRE ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '10' set @glosa = 'VACACIONES - ' + 'OCTUBRE ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '11' set @glosa = 'VACACIONES - ' + 'NOVIEMBRE ' + LEFT(@fecha,4)
		if RIGHT(@fecha,2) = '12' set @glosa = 'VACACIONES - ' + 'DICIEMBRE ' + LEFT(@fecha,4)
	end
	
	if CHARINDEX('EMPLEADOS-VACACIONES',@titulo) > 0 
	begin
		select 1
	end
	else
	begin
		
	select 
		 ParentKey,
		 convert(char(4),row_number() over (order by AccountCode ) - 1) as linenum, 
		 '' as lineid,
		 AccountCode,
		 convert(numeric(19,2),Debit) as debit,convert(numeric(19,2),Credit) as Credit,
		 FCDebit,FCCredit,FCCurrency,DueDate,
		 ShortName,
		 '' as ContraAccount,LineMemo,
		 DueDate as refdate,
		 '' as ref2date,Reference1,reference2,
		 '' as ProjectCode ,
		 case when left(AccountCode,1) <> '9' then '' else 'SIN VM' end as CostingCode, 
		 TaxDate,
		 '' as basesum, '' as VatGroup, '' as SYSDeb, '' as SYSCred, '' as VatDate, '' as VatLine, '' as SYSBaseSum, '' as VatAmount, '' as SYSVatSum, '' as GrossValue, '' as Ref3Line,
		 case when left(AccountCode,1) <> '9' then '' else CostingCode2 end as CostingCode2, case when left(AccountCode,1) <> '9' then '' else ProjectCode end as CostingCode3,CostingCode4,
		 '' as taxcode,'' as TaxPostAcc, CostingCode5,				
		 '' as Location, '' as Account, '' as WTLiable, '' as WTLine, '' as PayBlock, '' as PayBlckRef
		 
		from (
		select 
		'1' as ParentKey,
		CONVERT(varchar(4), line - 1) as linenum,
		AC_VoucherDetail.AccountCode as AccountCode,
		case when AC_VoucherDetail.AccountCode IN ( '41510001','14120001', '41110001', '41510001', '41140001', '41310001', '14130001', '14190001', '12120001') then ('E' + REPLICATE('0', 11 - len(SY_Person.DocumentNumber)) + SY_Person.DocumentNumber) else  '' end as ShortName,
		case when AC_VoucherDetail.AccountCode IN ( '91629101','94629101','95629101', '91621102', '94621101', '94621501','91627101', '94627101', '95627101', '91621501', '94621501', '95621501', '94621401', '95621401', '91621401') then
			convert(varchar(15), (case when AC_VoucherDetail.AmountLo >= 0 then convert(numeric(19,2),round(AC_VoucherDetail.AmountLo,2)) *(ISNULL(PR_DistribucionVoucher.valor, 100)/100.00) else 0.00 end)) 
		else
			convert(varchar(15), (case when AC_VoucherDetail.AmountLo >= 0 then convert(numeric(19,2),round(AC_VoucherDetail.AmountLo,2))  else 0.00 end)) 
		end as Debit,
		case when AC_VoucherDetail.AccountCode IN ( '91629101','94629101','95629101', '91621102', '94621101', '94621501','91627101', '94627101', '95627101', '91621501', '94621501', '95621501','94621401', '95621401', '91621401') then
			convert(varchar(15), (case when AC_VoucherDetail.AmountLo >= 0 then 0.00 else abs(convert(numeric(19,2),round(AC_VoucherDetail.AmountLo,2)))*(ISNULL(PR_DistribucionVoucher.valor, 100)/100.00) end)) 
		else
			convert(varchar(15), (case when AC_VoucherDetail.AmountLo >= 0 then 0.00 else abs(convert(numeric(19,2),round(AC_VoucherDetail.AmountLo,2))) end)) 
		end as Credit,

		'' as FCDebit,
		'' as FCCredit,
		'' as FCCurrency,
		convert(varchar(15), (case when AC_VoucherDetail.AmountLo >= 0 then convert(numeric(19,2),round(AC_VoucherDetail.AmountLo/(AC_Voucher.ExchangeRate*1.000),2)) else 0.00 end)  ) as sysDebit,
		convert(varchar(15), (case when AC_VoucherDetail.AmountLo >= 0 then 0.00 else abs(convert(numeric(19,2),round(AC_VoucherDetail.AmountLo/(AC_Voucher.ExchangeRate*1.000),2)))  end)) as sysCredit,
		'' as DueDate,
		convert(varchar,dateadd(dd,(datediff(dd,dateadd(month,1,convert(datetime,ac_voucher.period+'01')),convert(datetime,ac_voucher.period+'01'))*-1)-1,convert(datetime,ac_voucher.period+'01')),112) as TaxDate,
		ISNULL(PR_DistribucionVoucher.codigo, '') as ProjectCode,
		isnull(AC_VoucherDetail.Comments,'') as LineMemo,
		''   as Reference1,
		@glosa as reference2,
		'' as CostingCode,
		'' as Account,
		'SIN VNM' as CostingCode2,
		isnull(SY_Person.MilitarDocument,'') as CostingCode3,
		'' as CostingCode4,
		'' as CostingCode5
		
		from AC_Voucher inner join AC_VoucherDetail on (AC_Voucher.Voucher = AC_VoucherDetail.Voucher) left join SY_Person on (AC_VoucherDetail.Person = SY_Person.Person)
		left join AC_CostCenter on (AC_VoucherDetail.CostCenter = AC_CostCenter.CostCenter)
		left join PR_DistribucionVoucher on (AC_VoucherDetail.Person = PR_DistribucionVoucher.dni 
		and left(PR_DistribucionVoucher.period,6) = left(@period,6) and PR_DistribucionVoucher.company = @cia
		and LTRIM(RTRIM(ISNULL(PR_DistribucionVoucher.tipo, 'CC'))) = 'CC')

		where 
		ac_voucher.Voucher = @voucher 
		and AC_VoucherDetail.AccountCode IN ( '91629101','94629101','95629101','94621101', '91621102', '94621501', '91627101', '94627101', '95627101', '91621501', '94621501', '95621501','94621401', '95621401', '91621401')
		
		union all

		select 
		'1' as ParentKey,
		CONVERT(varchar(4), line - 1) as linenum,
		AC_VoucherDetail.AccountCode as AccountCode,
		case when AC_VoucherDetail.AccountCode IN ( '41510001','14120001', '41110001', '41510001', '41140001', '41310001', '14130001', '14190001', '12120001') then ('E' + REPLICATE('0', 11 - len(SY_Person.DocumentNumber)) + SY_Person.DocumentNumber) else  '' end as ShortName,
		case when AC_VoucherDetail.AccountCode IN ( '41510001','14120001', '41110001', '41510001', '41140001', '41310001', '14130001', '14190001', '12120001') then
			convert(varchar(15), (case when AC_VoucherDetail.AmountLo >= 0 then convert(numeric(19,2),round(AC_VoucherDetail.AmountLo,2))  else 0.00 end)) 
		else
			convert(varchar(15), (case when AC_VoucherDetail.AmountLo >= 0 then convert(numeric(19,2),round(AC_VoucherDetail.AmountLo,2))  else 0.00 end)) 
		end as Debit,
		case when AC_VoucherDetail.AccountCode IN ( '41510001','14120001', '41110001', '41510001', '41140001', '41310001', '14130001', '14190001', '12120001') then
			convert(varchar(15), (case when AC_VoucherDetail.AmountLo >= 0 then 0.00 else abs(convert(numeric(19,2),round(AC_VoucherDetail.AmountLo,2))) end)) 
		else
			convert(varchar(15), (case when AC_VoucherDetail.AmountLo >= 0 then 0.00 else abs(convert(numeric(19,2),round(AC_VoucherDetail.AmountLo,2))) end)) 
		end as Credit,

		'' as FCDebit,
		'' as FCCredit,
		'' as FCCurrency,
		convert(varchar(15), (case when AC_VoucherDetail.AmountLo >= 0 then convert(numeric(19,2),round(AC_VoucherDetail.AmountLo/(AC_Voucher.ExchangeRate*1.000),2)) else 0.00 end)  ) as sysDebit,
		convert(varchar(15), (case when AC_VoucherDetail.AmountLo >= 0 then 0.00 else abs(convert(numeric(19,2),round(AC_VoucherDetail.AmountLo/(AC_Voucher.ExchangeRate*1.000),2)))  end)) as sysCredit,
		'' as DueDate,
		convert(varchar,dateadd(dd,(datediff(dd,dateadd(month,1,convert(datetime,ac_voucher.period+'01')),convert(datetime,ac_voucher.period+'01'))*-1)-1,convert(datetime,ac_voucher.period+'01')),112) as TaxDate,
		(select Abbrev from AC_CostCenter where CostCenter = AC_VoucherDetail.CostCenter) as ProjectCode,
		isnull(AC_VoucherDetail.Comments,'') as LineMemo,
		''   as Reference1,
		@glosa as reference2,
		'' as CostingCode,
		'' as Account,
		'SIN VNM' as CostingCode2,
		isnull(SY_Person.MilitarDocument,'') as CostingCode3,
		'' as CostingCode4,
		'' as CostingCode5
		
		from AC_Voucher inner join AC_VoucherDetail on (AC_Voucher.Voucher = AC_VoucherDetail.Voucher) left join SY_Person on (AC_VoucherDetail.Person = SY_Person.Person)
		left join AC_CostCenter on (AC_VoucherDetail.CostCenter = AC_CostCenter.CostCenter)
		where 
		ac_voucher.Voucher = @voucher 
		and AC_VoucherDetail.AccountCode NOT IN ( '91629101','94629101','95629101', '94621101', '91621102', '94621501', '91627101', '94627101', '95627101', '91621501', '94621501', '95621501', '94621401', '95621401', '91621401')

		 )X
	end
end
