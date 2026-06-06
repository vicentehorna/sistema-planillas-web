/*
    Promedio de liquidaciones por trabajador (últimos 6 meses).
    Usado por: POST /api/reportes/promedio-liquidaciones (reporte_liquidaciones.html).

    Requiere liquidación calculada en el periodo indicado (PR_ProcessType.ShortName = 'LIQUIDACION').
    Usa funciones: f_getSumaConceptoPromedio, f_getSumaConceptoPromedioVAC, f_getMesesDividir.

    Parámetros:
      @cia, @payrolltype, @period, @person — todos obligatorios.

    Salida: 6 filas (meses) con conceptos promedio para vacaciones, CTS y gratificación,
    más meses divisorios (vaccant, ctsCant, gratiCant), nombre y fechas.
*/
CREATE OR ALTER PROCEDURE [dbo].[SP_PR_ReportePromedioLiquidacion]
    @cia          VARCHAR(20),
    @payrolltype  VARCHAR(20),
    @period       VARCHAR(20),
    @person       VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ceasedate    DATETIME;
    DECLARE @fechaingreso DATETIME;
    DECLARE @extras       VARCHAR(50) = 'C_HORASEXTRAS';
    DECLARE @bono         VARCHAR(50) = 'SOBRETASA_NOCHE';
    DECLARE @feriado      VARCHAR(50) = 'FERIADOS';
    DECLARE @comision     VARCHAR(50) = 'COMISION';
    DECLARE @faltas       VARCHAR(50) = 'CANT_DIAS_AUSENCIA';
    DECLARE @lsg          VARCHAR(50) = 'DIASLICSGOCE';
    DECLARE @susp         VARCHAR(50) = 'DIASUSPENSION';
    DECLARE @mes          INT = 0;

    CREATE TABLE #temp_reporte (
        periodo       VARCHAR(20),
        he_vac        NUMERIC(19, 4),
        bono_vac      NUMERIC(19, 4),
        feriado_vac   NUMERIC(19, 4),
        comision_vac  NUMERIC(19, 4),
        faltas_vac    NUMERIC(19, 4),
        he_cts        NUMERIC(19, 4),
        bono_cts      NUMERIC(19, 4),
        feriado_cts   NUMERIC(19, 4),
        comision_cts  NUMERIC(19, 4),
        faltas_cts    NUMERIC(19, 4),
        he_gra        NUMERIC(19, 4),
        bono_gra      NUMERIC(19, 4),
        feriado_gra   NUMERIC(19, 4),
        comision_gra  NUMERIC(19, 4),
        faltas_gra    NUMERIC(19, 4),
        ctsCant       NUMERIC(19, 4),
        gratiCant     NUMERIC(19, 4),
        person        VARCHAR(20)
    );

    SELECT
        @ceasedate = CeaseDate,
        @fechaingreso = EntryDate
    FROM PR_EmployeePayRoll
    WHERE Company = @cia
      AND PRPeriod = @period
      AND Person = @person
      AND EXISTS (
            SELECT 1
            FROM PR_ProcessType
            WHERE ProcessType = PR_EmployeePayRoll.ProcessType
              AND ShortName = 'LIQUIDACION'
      );

    /* Últimos 6 meses respecto al periodo de liquidación. */
    WHILE @mes <= 5
    BEGIN
        INSERT INTO #temp_reporte
        SELECT
            CONVERT(VARCHAR(6), DATEADD(MONTH, -@mes, CONVERT(DATETIME, @period)), 112),
            0, 0, 0, 0, 0,
            0, 0, 0, 0, 0,
            0, 0, 0, 0, 0,
            0, 0,
            Person
        FROM PR_EmployeePayRoll
        WHERE Company = @cia
          AND PRPeriod = @period
          AND Person = @person
          AND EXISTS (
                SELECT 1
                FROM PR_ProcessType
                WHERE ProcessType = PR_EmployeePayRoll.ProcessType
                  AND ShortName = 'LIQUIDACION'
          );

        SET @mes = @mes + 1;
    END;

    UPDATE #temp_reporte
    SET periodo = periodo + SUBSTRING(periodo, 5, 2);

    UPDATE #temp_reporte
    SET
        he_cts = CASE
            WHEN @ceasedate >= CONVERT(DATETIME, LEFT(@period, 4) + '0501')
             AND @ceasedate <= CONVERT(DATETIME, LEFT(@period, 4) + '1031') THEN
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) >= CONVERT(DATE, LEFT(@period, 4) + '0501')
                     AND CONVERT(DATE, @fechaingreso) <= CONVERT(DATE, LEFT(@period, 4) + '1031')
                        THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @extras, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0501'), CONVERT(DATE, @ceasedate), @cia, @person, @extras, periodo)
                END
            ELSE
                CASE
                    WHEN @ceasedate > CONVERT(DATETIME, LEFT(@period, 4) + '1031') THEN
                        CASE
                            WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATETIME, LEFT(@period, 4) + '1031')
                                THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @extras, periodo)
                            ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '1101'), CONVERT(DATE, @ceasedate), @cia, @person, @extras, periodo)
                        END
                    ELSE
                        CASE
                            WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATETIME, CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '1031')
                                THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @extras, periodo)
                            ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '1101'), CONVERT(DATE, @ceasedate), @cia, @person, @extras, periodo)
                        END
                END
        END,
        bono_cts = CASE
            WHEN @ceasedate >= CONVERT(DATETIME, LEFT(@period, 4) + '0501')
             AND @ceasedate <= CONVERT(DATETIME, LEFT(@period, 4) + '1031') THEN
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) >= CONVERT(DATE, LEFT(@period, 4) + '0501')
                     AND CONVERT(DATE, @fechaingreso) <= CONVERT(DATE, LEFT(@period, 4) + '1031')
                        THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @bono, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0501'), CONVERT(DATE, @ceasedate), @cia, @person, @bono, periodo)
                END
            ELSE
                CASE
                    WHEN @ceasedate > CONVERT(DATETIME, LEFT(@period, 4) + '1031') THEN
                        CASE
                            WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATETIME, LEFT(@period, 4) + '1031')
                                THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @bono, periodo)
                            ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '1101'), CONVERT(DATE, @ceasedate), @cia, @person, @bono, periodo)
                        END
                    ELSE
                        CASE
                            WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATETIME, CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '1031')
                                THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @bono, periodo)
                            ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '1101'), CONVERT(DATE, @ceasedate), @cia, @person, @bono, periodo)
                        END
                END
        END,
        comision_cts = CASE
            WHEN @ceasedate >= CONVERT(DATETIME, LEFT(@period, 4) + '0501')
             AND @ceasedate <= CONVERT(DATETIME, LEFT(@period, 4) + '1031') THEN
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) >= CONVERT(DATE, LEFT(@period, 4) + '0501')
                     AND CONVERT(DATE, @fechaingreso) <= CONVERT(DATE, LEFT(@period, 4) + '1031')
                        THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @comision, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0501'), CONVERT(DATE, @ceasedate), @cia, @person, @comision, periodo)
                END
            ELSE
                CASE
                    WHEN @ceasedate > CONVERT(DATETIME, LEFT(@period, 4) + '1031') THEN
                        CASE
                            WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATETIME, LEFT(@period, 4) + '1031')
                                THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @comision, periodo)
                            ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '1101'), CONVERT(DATE, @ceasedate), @cia, @person, @comision, periodo)
                        END
                    ELSE
                        CASE
                            WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATETIME, CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '1031')
                                THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @comision, periodo)
                            ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '1101'), CONVERT(DATE, @ceasedate), @cia, @person, @comision, periodo)
                        END
                END
        END,
        feriado_cts = CASE
            WHEN @ceasedate >= CONVERT(DATETIME, LEFT(@period, 4) + '0501')
             AND @ceasedate <= CONVERT(DATETIME, LEFT(@period, 4) + '1031') THEN
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) >= CONVERT(DATE, LEFT(@period, 4) + '0501')
                     AND CONVERT(DATE, @fechaingreso) <= CONVERT(DATE, LEFT(@period, 4) + '1031')
                        THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @feriado, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0501'), CONVERT(DATE, @ceasedate), @cia, @person, @feriado, periodo)
                END
            ELSE
                CASE
                    WHEN @ceasedate > CONVERT(DATETIME, LEFT(@period, 4) + '1031') THEN
                        CASE
                            WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATETIME, LEFT(@period, 4) + '1031')
                                THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @feriado, periodo)
                            ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '1101'), CONVERT(DATE, @ceasedate), @cia, @person, @feriado, periodo)
                        END
                    ELSE
                        CASE
                            WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATETIME, CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '1031')
                                THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @feriado, periodo)
                            ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '1101'), CONVERT(DATE, @ceasedate), @cia, @person, @feriado, periodo)
                        END
                END
        END,
        faltas_cts =
            CASE
                WHEN @ceasedate >= CONVERT(DATETIME, LEFT(@period, 4) + '0501')
                 AND @ceasedate <= CONVERT(DATETIME, LEFT(@period, 4) + '1031') THEN
                    CASE
                        WHEN CONVERT(DATE, @fechaingreso) >= CONVERT(DATE, LEFT(@period, 4) + '0501')
                         AND CONVERT(DATE, @fechaingreso) <= CONVERT(DATE, LEFT(@period, 4) + '1031')
                            THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @faltas, periodo)
                        ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0501'), CONVERT(DATE, @ceasedate), @cia, @person, @faltas, periodo)
                    END
                ELSE
                    CASE
                        WHEN @ceasedate > CONVERT(DATETIME, LEFT(@period, 4) + '1031') THEN
                            CASE
                                WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATETIME, LEFT(@period, 4) + '1031')
                                    THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @faltas, periodo)
                                ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '1101'), CONVERT(DATE, @ceasedate), @cia, @person, @faltas, periodo)
                            END
                        ELSE
                            CASE
                                WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATETIME, CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '1031')
                                    THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @faltas, periodo)
                                ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '1101'), CONVERT(DATE, @ceasedate), @cia, @person, @faltas, periodo)
                            END
                    END
            END
            + CASE
                WHEN @ceasedate >= CONVERT(DATETIME, LEFT(@period, 4) + '0501')
                 AND @ceasedate <= CONVERT(DATETIME, LEFT(@period, 4) + '1031') THEN
                    CASE
                        WHEN CONVERT(DATE, @fechaingreso) >= CONVERT(DATE, LEFT(@period, 4) + '0501')
                         AND CONVERT(DATE, @fechaingreso) <= CONVERT(DATE, LEFT(@period, 4) + '1031')
                            THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @lsg, periodo)
                        ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0501'), CONVERT(DATE, @ceasedate), @cia, @person, @lsg, periodo)
                    END
                ELSE
                    CASE
                        WHEN @ceasedate > CONVERT(DATETIME, LEFT(@period, 4) + '1031') THEN
                            CASE
                                WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATETIME, LEFT(@period, 4) + '1031')
                                    THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @lsg, periodo)
                                ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '1101'), CONVERT(DATE, @ceasedate), @cia, @person, @lsg, periodo)
                            END
                        ELSE
                            CASE
                                WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATETIME, CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '1031')
                                    THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @lsg, periodo)
                                ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '1101'), CONVERT(DATE, @ceasedate), @cia, @person, @lsg, periodo)
                            END
                    END
            END
            + CASE
                WHEN @ceasedate >= CONVERT(DATETIME, LEFT(@period, 4) + '0501')
                 AND @ceasedate <= CONVERT(DATETIME, LEFT(@period, 4) + '1031') THEN
                    CASE
                        WHEN CONVERT(DATE, @fechaingreso) >= CONVERT(DATE, LEFT(@period, 4) + '0501')
                         AND CONVERT(DATE, @fechaingreso) <= CONVERT(DATE, LEFT(@period, 4) + '1031')
                            THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @susp, periodo)
                        ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0501'), CONVERT(DATE, @ceasedate), @cia, @person, @susp, periodo)
                    END
                ELSE
                    CASE
                        WHEN @ceasedate > CONVERT(DATETIME, LEFT(@period, 4) + '1031') THEN
                            CASE
                                WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATETIME, LEFT(@period, 4) + '1031')
                                    THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @susp, periodo)
                                ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '1101'), CONVERT(DATE, @ceasedate), @cia, @person, @susp, periodo)
                            END
                        ELSE
                            CASE
                                WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATETIME, CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '1031')
                                    THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @susp, periodo)
                                ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '1101'), CONVERT(DATE, @ceasedate), @cia, @person, @susp, periodo)
                            END
                    END
            END,
        he_gra = CASE
            WHEN MONTH(@ceasedate) < 7 THEN
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATE, LEFT(@period, 4) + '0101')
                        THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @extras, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0101'), CONVERT(DATE, @ceasedate), @cia, @person, @extras, periodo)
                END
            ELSE
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATE, LEFT(@period, 4) + '0701')
                        THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @extras, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0701'), CONVERT(DATE, @ceasedate), @cia, @person, @extras, periodo)
                END
        END,
        bono_gra = CASE
            WHEN MONTH(@ceasedate) < 7 THEN
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATE, LEFT(@period, 4) + '0101')
                        THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @bono, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0101'), CONVERT(DATE, @ceasedate), @cia, @person, @bono, periodo)
                END
            ELSE
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATE, LEFT(@period, 4) + '0701')
                        THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @bono, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0701'), CONVERT(DATE, @ceasedate), @cia, @person, @bono, periodo)
                END
        END,
        comision_gra = CASE
            WHEN MONTH(@ceasedate) < 7 THEN
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATE, LEFT(@period, 4) + '0101')
                        THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @comision, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0101'), CONVERT(DATE, @ceasedate), @cia, @person, @comision, periodo)
                END
            ELSE
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATE, LEFT(@period, 4) + '0701')
                        THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @comision, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0701'), CONVERT(DATE, @ceasedate), @cia, @person, @comision, periodo)
                END
        END,
        feriado_gra = CASE
            WHEN MONTH(@ceasedate) < 7 THEN
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATE, LEFT(@period, 4) + '0101')
                        THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @feriado, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0101'), CONVERT(DATE, @ceasedate), @cia, @person, @feriado, periodo)
                END
            ELSE
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATE, LEFT(@period, 4) + '0701')
                        THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @feriado, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0701'), CONVERT(DATE, @ceasedate), @cia, @person, @feriado, periodo)
                END
        END,
        faltas_gra = CASE
            WHEN MONTH(@ceasedate) < 7 THEN
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATE, LEFT(@period, 4) + '0101')
                        THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @faltas, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0101'), CONVERT(DATE, @ceasedate), @cia, @person, @faltas, periodo)
                END
            ELSE
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATE, LEFT(@period, 4) + '0701')
                        THEN dbo.f_getSumaConceptoPromedio(
                            CONVERT(DATE, @fechaingreso),
                            CASE
                                WHEN CONVERT(VARCHAR(8), @ceasedate, 112) > LEFT(@period, 6) + '29'
                                    THEN CONVERT(DATE, @ceasedate)
                                ELSE DATEADD(DAY, -1, CONVERT(DATE, LEFT(@period, 6) + '01'))
                            END,
                            @cia, @person, @faltas, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(
                            CONVERT(DATE, LEFT(@period, 4) + '0701'),
                            CASE
                                WHEN CONVERT(VARCHAR(8), @ceasedate, 112) > LEFT(@period, 6) + '29'
                                    THEN CONVERT(DATE, @ceasedate)
                                ELSE DATEADD(DAY, -1, CONVERT(DATE, LEFT(@period, 6) + '01'))
                            END,
                            @cia, @person, @faltas, periodo)
                END
        END
        + CASE
            WHEN MONTH(@ceasedate) < 7 THEN
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATE, LEFT(@period, 4) + '0101')
                        THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @lsg, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0101'), CONVERT(DATE, @ceasedate), @cia, @person, @lsg, periodo)
                END
            ELSE
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATE, LEFT(@period, 4) + '0701')
                        THEN dbo.f_getSumaConceptoPromedio(
                            CONVERT(DATE, @fechaingreso),
                            CASE
                                WHEN CONVERT(VARCHAR(8), @ceasedate, 112) > LEFT(@period, 6) + '29'
                                    THEN CONVERT(DATE, @ceasedate)
                                ELSE DATEADD(DAY, -1, CONVERT(DATE, LEFT(@period, 6) + '01'))
                            END,
                            @cia, @person, @lsg, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(
                            CONVERT(DATE, LEFT(@period, 4) + '0701'),
                            CASE
                                WHEN CONVERT(VARCHAR(8), @ceasedate, 112) > LEFT(@period, 6) + '29'
                                    THEN CONVERT(DATE, @ceasedate)
                                ELSE DATEADD(DAY, -1, CONVERT(DATE, LEFT(@period, 6) + '01'))
                            END,
                            @cia, @person, @lsg, periodo)
                END
        END
        + CASE
            WHEN MONTH(@ceasedate) < 7 THEN
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATE, LEFT(@period, 4) + '0101')
                        THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @susp, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0101'), CONVERT(DATE, @ceasedate), @cia, @person, @susp, periodo)
                END
            ELSE
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATE, LEFT(@period, 4) + '0701')
                        THEN dbo.f_getSumaConceptoPromedio(
                            CONVERT(DATE, @fechaingreso),
                            CASE
                                WHEN CONVERT(VARCHAR(8), @ceasedate, 112) > LEFT(@period, 6) + '29'
                                    THEN CONVERT(DATE, @ceasedate)
                                ELSE DATEADD(DAY, -1, CONVERT(DATE, LEFT(@period, 6) + '01'))
                            END,
                            @cia, @person, @susp, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(
                            CONVERT(DATE, LEFT(@period, 4) + '0701'),
                            CASE
                                WHEN CONVERT(VARCHAR(8), @ceasedate, 112) > LEFT(@period, 6) + '29'
                                    THEN CONVERT(DATE, @ceasedate)
                                ELSE DATEADD(DAY, -1, CONVERT(DATE, LEFT(@period, 6) + '01'))
                            END,
                            @cia, @person, @susp, periodo)
                END
        END,
        he_vac = dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @extras, periodo),
        bono_vac = dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @bono, periodo),
        comision_vac = dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @comision, periodo),
        feriado_vac = dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @feriado, periodo),
        faltas_vac =
            dbo.f_getSumaConceptoPromedioVAC(
                CASE
                    WHEN DATEDIFF(YEAR, @fechaingreso, @ceasedate) <= 1 THEN CONVERT(DATE, @fechaingreso)
                    ELSE CONVERT(DATE, CONVERT(VARCHAR(4), YEAR(@ceasedate) - 1) + RIGHT(CONVERT(VARCHAR(8), @fechaingreso, 112), 4))
                END,
                CONVERT(DATE, @ceasedate), @cia, @person, @faltas, periodo)
            + dbo.f_getSumaConceptoPromedioVAC(
                CASE
                    WHEN DATEDIFF(YEAR, @fechaingreso, @ceasedate) <= 1 THEN CONVERT(DATE, @fechaingreso)
                    ELSE CONVERT(DATE, CONVERT(VARCHAR(4), YEAR(@ceasedate) - 1) + RIGHT(CONVERT(VARCHAR(8), @fechaingreso, 112), 4))
                END,
                CONVERT(DATE, @ceasedate), @cia, @person, @lsg, periodo)
            + dbo.f_getSumaConceptoPromedioVAC(
                CASE
                    WHEN DATEDIFF(YEAR, @fechaingreso, @ceasedate) <= 1 THEN CONVERT(DATE, @fechaingreso)
                    ELSE CONVERT(DATE, CONVERT(VARCHAR(4), YEAR(@ceasedate) - 1) + RIGHT(CONVERT(VARCHAR(8), @fechaingreso, 112), 4))
                END,
                CONVERT(DATE, @ceasedate), @cia, @person, @susp, periodo);

    SELECT
        LEFT(periodo, 4) + '-' + SUBSTRING(periodo, 5, 2) AS periodo_fmt,
        he_vac,
        bono_vac,
        feriado_vac,
        comision_vac,
        faltas_vac,
        he_cts,
        bono_cts,
        feriado_cts,
        comision_cts,
        faltas_cts,
        he_gra,
        bono_gra,
        feriado_gra,
        comision_gra,
        faltas_gra,
        CASE
            WHEN @ceasedate >= CONVERT(DATETIME, LEFT(@period, 4) + '0501')
             AND @ceasedate <= CONVERT(DATETIME, LEFT(@period, 4) + '1031') THEN
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) >= CONVERT(DATE, LEFT(@period, 4) + '0501')
                     AND CONVERT(DATE, @fechaingreso) <= CONVERT(DATE, LEFT(@period, 4) + '1031')
                        THEN dbo.f_getMesesDividir(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate))
                    ELSE dbo.f_getMesesDividir(CONVERT(DATE, LEFT(@period, 4) + '0501'), CONVERT(DATE, @ceasedate))
                END
            ELSE
                CASE
                    WHEN @ceasedate > CONVERT(DATETIME, LEFT(@period, 4) + '1031') THEN
                        CASE
                            WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATETIME, LEFT(@period, 4) + '1031')
                                THEN dbo.f_getMesesDividir(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate))
                            ELSE dbo.f_getMesesDividir(CONVERT(DATE, LEFT(@period, 4) + '1101'), CONVERT(DATE, @ceasedate))
                        END
                    ELSE
                        CASE
                            WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATETIME, CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '1031')
                                THEN dbo.f_getMesesDividir(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate))
                            ELSE dbo.f_getMesesDividir(CONVERT(DATE, CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '1101'), CONVERT(DATE, @ceasedate))
                        END
                END
        END AS ctsCant,
        CASE
            WHEN MONTH(@ceasedate) < 7 THEN
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATE, LEFT(@period, 4) + '0101')
                        THEN dbo.f_getMesesDividir(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate))
                    ELSE dbo.f_getMesesDividir(CONVERT(DATE, LEFT(@period, 4) + '0101'), CONVERT(DATE, @ceasedate))
                END
            ELSE
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATE, LEFT(@period, 4) + '0701')
                        THEN dbo.f_getMesesDividir(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate))
                    ELSE dbo.f_getMesesDividir(CONVERT(DATE, LEFT(@period, 4) + '0701'), CONVERT(DATE, @ceasedate))
                END
        END AS gratiCant,
        SY_Person.Name,
        CONVERT(VARCHAR(20), @ceasedate, 103) AS fechacese,
        CONVERT(VARCHAR(20), @fechaingreso, 103) AS fechaingreso,
        dbo.f_getMesesDividir(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate)) AS vaccant
    FROM #temp_reporte
        INNER JOIN SY_Person
            ON #temp_reporte.person = SY_Person.Person;
END
GO
