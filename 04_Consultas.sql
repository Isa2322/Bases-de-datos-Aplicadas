-- =============================================
USE [Com5600G11]; 
GO

/*
    REPORTE 1: 
    Se desea analizar el flujo de caja en forma semanal. 
    Debe presentar la recaudación por pagos ordinarios y extraordinarios de cada semana, el promedio en el periodo, y el acumulado progresivo. 
*/

IF OBJECT_ID('Operaciones.sp_Reporte1_FlujoSemanal', 'P') IS NOT NULL
    DROP PROCEDURE Operaciones.sp_Reporte1_FlujoSemanal
GO

CREATE PROCEDURE Operaciones.sp_Reporte1_FlujoSemanal
(
    @NombreConsorcio VARCHAR(100),
    @PeriodoAnio INT,
    @PeriodoMes INT
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdConsorcio INT;
    DECLARE @IdExpensa INT;

    -- 1. Buscar la Expensa y el ID del Consorcio usando los tres par�metros
    SELECT 
        @IdConsorcio = C.id,
        @IdExpensa = E.id
    FROM Consorcio.Consorcio AS C
    INNER JOIN Negocio.Expensa AS E ON E.consorcio_id = C.id
    WHERE C.nombre = @NombreConsorcio 
      AND E.fechaPeriodoAnio = @PeriodoAnio 
      AND E.fechaPeriodoMes = @PeriodoMes;

    -- 2. Validar si la Expensa fue encontrada
    IF @IdExpensa IS NULL
    BEGIN
        IF @IdConsorcio IS NULL
        BEGIN
             RAISERROR('El Consorcio con nombre "%s" no fue encontrado.', 16, 1, @NombreConsorcio);
        END
        ELSE
        BEGIN
             RAISERROR('La Expensa para el Consorcio "%s" en el periodo %d/%d no fue encontrada.', 16, 1, @NombreConsorcio, @PeriodoMes, @PeriodoAnio);
        END
        RETURN;
    END;

    -- 3. Inicia la l�gica de CTE
    ; WITH EgresosCombinados AS ( 
        -- Ordinarios
        SELECT
            fechaEmision,
            importeTotal AS Gasto_Ordinario,
            0.00 AS Gasto_Extraordinario,
            importeTotal AS Gasto_Total
        FROM Negocio.GastoOrdinario
        WHERE idExpensa = @IdExpensa 
        
        UNION ALL
        
        -- Extraordinarios
        SELECT
            fechaEmision,
            0.00 AS Gasto_Ordinario,
            importeTotal AS Gasto_Extraordinario,
            importeTotal AS Gasto_Total
        FROM Negocio.GastoExtraordinario
        WHERE idExpensa = @IdExpensa
    ),
    EgresosSemanal AS ( 
        -- Agrupar los egresos por semana de todos los meses
        SELECT
            YEAR(fechaEmision) AS Anio,
            MONTH(fechaEmision) AS Mes,
            DATEPART(wk, fechaEmision) AS Semana, -- obtiene la semana 
            SUM(Gasto_Ordinario) AS Gasto_Ordinario_Semanal,
            SUM(Gasto_Extraordinario) AS Gasto_Extraordinario_Semanal,
            SUM(Gasto_Total) AS Gasto_Semanal_Total
        FROM EgresosCombinados
        GROUP BY YEAR(fechaEmision), MONTH(fechaEmision), DATEPART(wk, fechaEmision)
    )
    
    -- 4. SELECT final
    SELECT
        @NombreConsorcio AS Nombre_Consorcio, 
        @IdConsorcio AS ID_Consorcio,
        @IdExpensa AS ID_Expensa,
        FORMAT(CAST(CAST(@PeriodoAnio AS VARCHAR) + '-' + CAST(@PeriodoMes AS VARCHAR) + '-01' AS DATE), 'yyyy-MM') AS Periodo,
        ES.Anio,
        ES.Mes,
        ES.Semana,

        -- N2 : Numero 2 Digitos decimales
        FORMAT(ES.Gasto_Ordinario_Semanal, 'N2') AS Egreso_Ordinario,
        FORMAT(ES.Gasto_Extraordinario_Semanal, 'N2') AS Egreso_Extraordinario,
        FORMAT(ES.Gasto_Semanal_Total, 'N2') AS Egreso_Semanal_Total,
        
         -- Acumulado Progresivo
        FORMAT(SUM(ES.Gasto_Semanal_Total) OVER (
         ORDER BY ES.Anio, ES.Semana
        ROWS UNBOUNDED PRECEDING
        ), 'N2') AS Acumulado_Progresivo,
        
        -- Promedio en el Periodo
    FORMAT(AVG(ES.Gasto_Semanal_Total) OVER (), 'N2') AS Promedio_Periodo
        
    FROM EgresosSemanal AS ES
    where  @PeriodoAnio= ES.Anio AND @PeriodoMes =  ES.Mes
    ORDER BY ES.Anio, ES.Semana;
END
GO
--=========================================================================================================
/*
    REPORTE 2:
    Presente el total de recaudación por mes y departamento en formato de tabla cruzada.  

*/

IF OBJECT_ID('Operaciones.sp_Reporte2_RecaudacionMesDepto', 'P') IS NOT NULL
    DROP PROCEDURE Operaciones.sp_Reporte2_RecaudacionMesDepto
GO

CREATE OR ALTER PROCEDURE Operaciones.sp_Reporte2_RecaudacionMesDepto
    @idConsorcio INT,   
    @anio INT,    
    @incluirSinPagos BIT = 0 
AS
BEGIN
    SET NOCOUNT ON
    /* 
       Base: pagos aplicados a detalles de expensa.
       Camino: PagoAplicado -> Pago(fecha) -> DetalleExpensa -> UF(departamento) -> Consorcio.
       Tomamos solo los pagos del año solicitado (@anio).
    */
    WITH Recaudacion AS
    (
        SELECT 
            uf.departamento,
            MONTH(p.fecha) AS mes,
            SUM(pa.importeAplicado) AS importe
        FROM Pago.PagoAplicado AS pa
        INNER JOIN Pago.Pago            AS p  ON p.id = pa.idPago
        INNER JOIN Negocio.DetalleExpensa AS de ON de.id = pa.idDetalleExpensa
        INNER JOIN Consorcio.UnidadFuncional AS uf ON uf.id = de.idUnidadFuncional
        INNER JOIN Consorcio.Consorcio       AS c  ON c.id = uf.consorcioId
        WHERE c.id = @idConsorcio
          AND YEAR(p.fecha) = @anio
        GROUP BY uf.departamento, MONTH(p.fecha)
    ),
    -- Si se pide incluir UFs sin pagos, generamos todas las combinaciones depto x mes con 0
    DeptoMes AS
    (
        SELECT DISTINCT uf.departamento
        FROM Consorcio.UnidadFuncional uf
        WHERE uf.consorcioId = @idConsorcio
    ),
    CalendarioMes AS
    (
        SELECT 1 AS mes UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
        UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8
        UNION ALL SELECT 9 UNION ALL SELECT 10 UNION ALL SELECT 11 UNION ALL SELECT 12
    ),
    Base AS
    (
        SELECT 
            COALESCE(r.departamento, d.departamento) AS departamento,
            m.mes,
            COALESCE(r.importe, 0) AS importe
        FROM (
            SELECT * FROM Recaudacion
            UNION ALL
            SELECT NULL, NULL, NULL  -- si @incluirSinPagos=0, ignoraremos esta rama
        ) r
        RIGHT JOIN (SELECT * FROM DeptoMes CROSS JOIN CalendarioMes) x
            ON (@incluirSinPagos = 1) 
           AND r.departamento = x.departamento 
           AND r.mes = x.mes
        RIGHT JOIN DeptoMes d ON d.departamento = COALESCE(x.departamento, r.departamento)
        RIGHT JOIN CalendarioMes m ON m.mes = COALESCE(x.mes, r.mes)
        WHERE (@incluirSinPagos = 1) OR (r.departamento IS NOT NULL)
    )
    SELECT 
        departamento,
        SUM(CASE WHEN mes = 1  THEN importe ELSE 0 END) AS Ene,
        SUM(CASE WHEN mes = 2  THEN importe ELSE 0 END) AS Feb,
        SUM(CASE WHEN mes = 3  THEN importe ELSE 0 END) AS Mar,
        SUM(CASE WHEN mes = 4  THEN importe ELSE 0 END) AS Abr,
        SUM(CASE WHEN mes = 5  THEN importe ELSE 0 END) AS May,
        SUM(CASE WHEN mes = 6  THEN importe ELSE 0 END) AS Jun,
        SUM(CASE WHEN mes = 7  THEN importe ELSE 0 END) AS Jul,
        SUM(CASE WHEN mes = 8  THEN importe ELSE 0 END) AS Ago,
        SUM(CASE WHEN mes = 9  THEN importe ELSE 0 END) AS Sep,
        SUM(CASE WHEN mes = 10 THEN importe ELSE 0 END) AS Oct,
        SUM(CASE WHEN mes = 11 THEN importe ELSE 0 END) AS Nov,
        SUM(CASE WHEN mes = 12 THEN importe ELSE 0 END) AS Dic,
        SUM(importe) AS Total
    FROM Base
    GROUP BY departamento
    ORDER BY departamento;
END
GO

--=========================================================================================================
/*
    REPORTE 3:
    Presente un cuadro cruzado con la recaudación total desagregada según su procedencia (ordinario, extraordinario, etc.) según el periodo. 
*/

CREATE OR ALTER PROCEDURE Operaciones.sp_Reporte3_RecaudacionPorProcedencia_Crosstab
    @idConsorcio INT = NULL, 
    @fechaDesde  DATE = NULL, 
    @fechaHasta  DATE = NULL 
AS
BEGIN
    SET NOCOUNT ON;
    IF @fechaHasta IS NULL SET @fechaHasta = CAST(GETDATE() AS DATE)

    /*
       Base: pagos aplicados a DetalleExpensa.
       Para cada detalle calculamos pesos (ordinario, extraordinario, mora) y
       distribuimos proporcionalmente cada pago aplicado según esos pesos.
       Luego agregamos por Año-Mes (de la fecha del pago).
    */
    WITH Pagos AS
    (
        SELECT 
            pa.idPago,
            CAST(p.fecha AS DATE) AS fechaPago,
            YEAR(p.fecha) AS anio,
            MONTH(p.fecha) AS mes,
            pa.importeAplicado,
            de.prorrateoOrdinario,
            de.prorrateoExtraordinario,
            de.interesMora,
            uf.consorcioId
        FROM Pago.PagoAplicado AS pa
        INNER JOIN Pago.Pago           AS p  ON p.id = pa.idPago
        INNER JOIN Negocio.DetalleExpensa AS de ON de.id = pa.idDetalleExpensa
        INNER JOIN Consorcio.UnidadFuncional AS uf ON uf.id = de.idUnidadFuncional
        WHERE (@idConsorcio IS NULL OR uf.consorcioId = @idConsorcio)
          AND (@fechaDesde  IS NULL OR CAST(p.fecha AS DATE) >= @fechaDesde)
          AND (@fechaHasta  IS NULL OR CAST(p.fecha AS DATE) <= @fechaHasta)
    ),
    Distribuido AS
    (
        SELECT
            anio, mes,
            -- pesos no negativos
            CAST(ISNULL(prorrateoOrdinario,0)     AS DECIMAL(18,6)) AS wOrd,
            CAST(ISNULL(prorrateoExtraordinario,0)AS DECIMAL(18,6)) AS wExt,
            CAST(ISNULL(interesMora,0)            AS DECIMAL(18,6)) AS wMora,
            importeAplicado
        FROM Pagos
    ),
    Partes AS
    (
        SELECT
            anio, mes,
            CASE WHEN (wOrd + wExt + wMora) > 0 
                 THEN importeAplicado * (wOrd / (wOrd + wExt + wMora))
                 ELSE 0 END AS rec_Ordinario,
            CASE WHEN (wOrd + wExt + wMora) > 0 
                 THEN importeAplicado * (wExt / (wOrd + wExt + wMora))
                 ELSE 0 END AS rec_Extraordinario,
            CASE WHEN (wOrd + wExt + wMora) > 0 
                 THEN importeAplicado * (wMora / (wOrd + wExt + wMora))
                 ELSE 0 END AS rec_Mora
        FROM Distribuido
    )
    SELECT 
        CONCAT(anio, '-', RIGHT('00'+CAST(mes AS VARCHAR(2)),2)) AS Periodo,
        SUM(rec_Ordinario)     AS Ordinario,
        SUM(rec_Extraordinario)AS Extraordinario,
        SUM(rec_Mora)          AS Mora,
        SUM(rec_Ordinario + rec_Extraordinario + rec_Mora) AS Total
    FROM Partes
    GROUP BY anio, mes
    ORDER BY anio, mes;
END
GO

--=========================================================================================================
/*
    REPORTE 4:
    Obtenga los 5 (cinco) meses de mayores gastos y los 5 (cinco) de mayores ingresos.  
*/

IF OBJECT_ID('Operaciones.sp_Reporte4_MayoresGI', 'P') IS NOT NULL
    DROP PROCEDURE Operaciones.sp_Reporte4_MayoresGI
GO

CREATE PROCEDURE Operaciones.sp_Reporte4_MayoresGI
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Top 5 meses con mayores gastos
    WITH GastosPorMes AS (
        SELECT 
            YEAR(e.fechaEmision) AS Anio,
            MONTH(e.fechaEmision) AS Mes,
            SUM(e.importeTotal) AS TotalGastos
        FROM (
            -- Junto los gastos ordinarios y extraordinarios, capaz que hay una forma mas prolija
            -- Lo dejo asi por ahora pq anda
            SELECT 
                idExpensa,
                fechaEmision,
                importeTotal
            FROM Negocio.GastoOrdinario
            WHERE fechaEmision IS NOT NULL
            
            UNION ALL
            
            SELECT 
                idExpensa,
                fechaEmision,
                importeTotal
            FROM Negocio.GastoExtraordinario
            WHERE fechaEmision IS NOT NULL
        ) e
        GROUP BY YEAR(e.fechaEmision), MONTH(e.fechaEmision)
    ),
    Top5Gastos AS (
        SELECT TOP 5
            Anio,
            Mes,
            DATENAME(MONTH, DATEFROMPARTS(Anio, Mes, 1)) AS NombreMes,
            TotalGastos,
            'Gasto' AS Tipo
        FROM GastosPorMes
        ORDER BY TotalGastos DESC
    ),
    
    -- Top 5 meses con mayores ingresos
    -- Tomo los de detalle expensa en vez de los de expensa pq ahi estan los pagos que si se recibieron (creo)
    IngresosPorMes AS (
        SELECT 
            YEAR(de.primerVencimiento) AS Anio,
            MONTH(de.primerVencimiento) AS Mes,
            SUM(de.pagosRecibidos) AS TotalIngresos
        FROM Negocio.DetalleExpensa de
        WHERE de.primerVencimiento IS NOT NULL
            AND de.pagosRecibidos > 0
        GROUP BY YEAR(de.primerVencimiento), MONTH(de.primerVencimiento)
    ),
    Top5Ingresos AS (
        SELECT TOP 5
            Anio,
            Mes,
            DATENAME(MONTH, DATEFROMPARTS(Anio, Mes, 1)) AS NombreMes,
            TotalIngresos AS Monto,
            'Ingreso' AS Tipo
        FROM IngresosPorMes
        ORDER BY TotalIngresos DESC
    )
    
    -- Resultados combinados
    SELECT 
        Tipo,
        Anio,
        Mes,
        NombreMes,
        TotalGastos AS Monto
    FROM Top5Gastos
    
    UNION ALL
    
    SELECT 
        Tipo,
        Anio,
        Mes,
        NombreMes,
        Monto
    FROM Top5Ingresos
    
    ORDER BY Tipo DESC, Monto DESC;
    
END
GO

-- ======================================================================================================================

/*
    REPORTE 5:
    Obtenga los 3 (tres) propietarios con mayor morosidad. 
    Presente información de contacto y DNI de los propietarios para que la administración los pueda 
    contactar o remitir el trámite al estudio jurídico.
    CON XML
*/
IF OBJECT_ID('Operaciones.sp_Reporte5_MayoresMorosos_XML', 'P') IS NOT NULL
    DROP PROCEDURE Operaciones.sp_Reporte5_MayoresMorosos_XML
GO

CREATE OR ALTER PROCEDURE Operaciones.sp_Reporte5_MayoresMorosos_XML
    @idConsorcio INT,
    @fechaDesde  DATE,
    @fechaHasta  DATE = NULL
    --solo admito q la fecha limite venga vacia
AS
BEGIN
    SET NOCOUNT ON;
    IF @fechaHasta IS NULL SET @fechaHasta = CAST(GETDATE() AS DATE);

    WITH DeudaPorDetalle AS 
    (
        SELECT 
            de.expensaId,
            de.idUnidadFuncional,
            de.primerVencimiento,
            CASE 
                WHEN de.totalaPagar - ISNULL(de.pagosRecibidos,0) > 0 
                THEN de.totalaPagar - ISNULL(de.pagosRecibidos,0)
                ELSE 0 
            END AS Deuda
        FROM Negocio.DetalleExpensa AS de
        WHERE (@fechaDesde IS NULL OR de.primerVencimiento >= @fechaDesde)
          AND (@fechaHasta IS NULL OR de.primerVencimiento <= @fechaHasta)
    ),
    DeudaPorPersona AS 
    (
        SELECT
            p.dni,
            p.nombre,
            p.apellido,
            p.email,
            p.telefono,
            SUM(d.Deuda) AS MorosidadTotal
        FROM DeudaPorDetalle d
        INNER JOIN Consorcio.UnidadFuncional uf ON uf.id = d.idUnidadFuncional
        INNER JOIN Negocio.Expensa e            ON e.id = d.expensaId
        INNER JOIN Consorcio.Consorcio c        ON c.id = uf.consorcioId
        -- titular por CBU/CVU registrado en la UF
        INNER JOIN Consorcio.Persona p
            ON (p.cbu = uf.CVU_CBU OR p.cvu = uf.CVU_CBU)
        WHERE (@idConsorcio IS NULL OR c.id = @idConsorcio)
        GROUP BY p.dni, p.nombre, p.apellido, p.email, p.telefono
        HAVING SUM(d.Deuda) > 0.01
    )
    SELECT
        (
            SELECT TOP (3)
                p.dni              AS [@dni],
                p.nombre           AS [nombre],
                p.apellido         AS [apellido],
                p.email            AS [email],
                p.telefono         AS [telefono],
                p.MorosidadTotal   AS [morosidad]
            FROM DeudaPorPersona p
            ORDER BY p.MorosidadTotal DESC
            FOR XML PATH('propietario'), ROOT('mayoresMorosos'), TYPE
        ) AS XML_Reporte5;
END
GO

-- =============================================================================================================
/*
    REPORTE 6:
    Muestre las fechas de pagos de expensas ordinarias de cada UF y la cantidad de días que pasan entre un pago y el siguiente, 
    para el conjunto examinado. 
    CON XML
*/
IF OBJECT_ID('Operaciones.sp_Reporte6_PagosOrdinarios_XML', 'P') IS NOT NULL
    DROP PROCEDURE Operaciones.sp_Reporte6_PagosOrdinarios_XML
GO

CREATE OR ALTER PROCEDURE Operaciones.sp_Reporte6_PagosOrdinarios_XML
    @idConsorcio INT      = NULL,   -- filtra por consorcio si viene
    @idUF        INT      = NULL,   -- filtra por unidad funcional si viene
    @fechaDesde  DATE     = NULL,   -- incluye pagos desde esta fecha (por fecha de Pago)
    @fechaHasta  DATE     = NULL    -- incluye pagos hasta esta fecha (default hoy)
AS
BEGIN
    SET NOCOUNT ON;

    IF @fechaHasta IS NULL SET @fechaHasta = CAST(GETDATE() AS DATE);

    /* 
       Tomo SOLO pagos aplicados a detalles que tengan componente ORDINARIO (>0).
       Camino: PagoAplicado -> DetalleExpensa -> UnidadFuncional -> (Consorcio) y Pago(fecha).
       NOTA: Pago.Pago tiene 'fecha' (datetime2) y cbuCuentaOrigen; no se usa el CBU acá
             porque la asociación se hace por el aplicado del pago al detalle (ya resuelto). 
    */

    ;WITH PagosOrdinarios AS
    (
        SELECT 
            uf.id               AS idUF,
            uf.consorcioId      AS idConsorcio,
            CAST(p.fecha AS DATE) AS fechaPago
        FROM Pago.PagoAplicado     AS pa
        INNER JOIN Pago.Pago       AS p  ON p.id = pa.idPago               -- fecha del pago
        INNER JOIN Negocio.DetalleExpensa AS de ON de.id = pa.idDetalleExpensa
        INNER JOIN Consorcio.UnidadFuncional AS uf ON uf.id = de.idUnidadFuncional
        INNER JOIN Negocio.Expensa AS e ON e.id = de.expensaId
        WHERE 
            -- componente ordinario presente
            ISNULL(de.prorrateoOrdinario, 0) > 0
            -- filtros por consorcio / UF (opcionales)
            AND (@idConsorcio IS NULL OR uf.consorcioId = @idConsorcio)
            AND (@idUF        IS NULL OR uf.id = @idUF)
            -- filtros de rango por FECHA DE PAGO
            AND (@fechaDesde IS NULL OR CAST(p.fecha AS DATE) >= @fechaDesde)
            AND (@fechaHasta IS NULL OR CAST(p.fecha AS DATE) <= @fechaHasta)
    ),
    PagosOrdenados AS
    (
        -- Ordeno por UF y fecha, y calculo días desde el pago anterior (LAG).
        SELECT
            idUF,
            idConsorcio,
            fechaPago,
            DATEDIFF(DAY, LAG(fechaPago) OVER (PARTITION BY idUF ORDER BY fechaPago), fechaPago) AS diasDesdeAnterior
        FROM PagosOrdinarios
    )

    -- Salida en XML agrupada por UF, con los pagos y el intervalo en días
    SELECT
        (
            SELECT 
                U.idUF      AS [@id]
              , (
                    SELECT 
                        po.fechaPago         AS [@fecha]
                      , po.diasDesdeAnterior AS [@diasDesdeAnterior]
                    FROM PagosOrdenados AS po
                    WHERE po.idUF = U.idUF
                    ORDER BY po.fechaPago
                    FOR XML PATH('pago'), TYPE
                )
            FROM (SELECT DISTINCT idUF FROM PagosOrdenados) AS U
            ORDER BY U.idUF
            FOR XML PATH('unidadFuncional'), ROOT('pagosOrdinarios'), TYPE
        ) AS XML_Reporte6;
END;
GO
