USE AdventureWorks2025; 
GO


--EXEC dbo.uspDetalleComprasPorCliente 20250102, 20250301
CREATE OR ALTER PROCEDURE dbo.uspDetalleComprasPorCliente
    @FechaInicio INT,
    @FechaFin    INT
AS
BEGIN
    SET NOCOUNT ON;

    
    DECLARE @Desde DATE = TRY_CONVERT(DATE, CONVERT(CHAR(8), @FechaInicio), 112),
            @Hasta DATE = TRY_CONVERT(DATE, CONVERT(CHAR(8), @FechaFin), 112);

    IF @Desde IS NULL
        THROW 50001, N'@FechaInicio no es una fecha válida. Use el formato AAAAMMDD (p. ej. 20250601).', 1;

    IF @Hasta IS NULL
        THROW 50002, N'@FechaFin no es una fecha válida. Use el formato AAAAMMDD (p. ej. 20250630).', 1;

    IF @Desde > @Hasta
        THROW 50003, N'@FechaInicio no puede ser mayor que @FechaFin.', 1;

    WITH ComprasPorDia AS
    (
        
        SELECT
            CAST(soh.OrderDate AS DATE) AS FechaCompra,
            soh.CustomerID,
            soh.ShipToAddressID,
            sod.ProductID,
            SUM(sod.OrderQty)           AS CantidadArticulos
        FROM Sales.SalesOrderHeader AS soh
        INNER JOIN Sales.SalesOrderDetail AS sod
            ON sod.SalesOrderID = soh.SalesOrderID
        WHERE CAST(soh.OrderDate AS DATE) BETWEEN @Desde AND @Hasta
        GROUP BY
            CAST(soh.OrderDate AS DATE),
            soh.CustomerID,
            soh.ShipToAddressID,
            sod.ProductID
    )
    SELECT
        cpd.FechaCompra,
        c.CustomerID                                                        AS ClienteID,
        COALESCE(st.Name, CONCAT_WS(N' ', per.FirstName, per.MiddleName, per.LastName))
                                                                            AS Cliente,
        CASE WHEN c.StoreID IS NULL THEN N'Persona' ELSE N'Tienda' END      AS TipoCliente,
        pr.ProductNumber                                                    AS CodigoArticulo,
        pr.Name                                                             AS Articulo,
        cpd.CantidadArticulos,
        CONCAT_WS(N', ', a.AddressLine1, a.AddressLine2)                    AS DireccionEntrega,
        a.City                                                              AS Ciudad,
        sp.Name                                                             AS EstadoProvincia,
        a.PostalCode                                                        AS CodigoPostal,
        cr.Name                                                             AS Pais
    FROM ComprasPorDia AS cpd
    INNER JOIN Sales.Customer AS c
        ON c.CustomerID = cpd.CustomerID
    LEFT JOIN Sales.Store AS st             -- Clientes tienda
        ON st.BusinessEntityID = c.StoreID
    LEFT JOIN Person.Person AS per          -- Clientes persona
        ON per.BusinessEntityID = c.PersonID
    INNER JOIN Production.Product AS pr
        ON pr.ProductID = cpd.ProductID
    INNER JOIN Person.Address AS a
        ON a.AddressID = cpd.ShipToAddressID
    INNER JOIN Person.StateProvince AS sp
        ON sp.StateProvinceID = a.StateProvinceID
    INNER JOIN Person.CountryRegion AS cr
        ON cr.CountryRegionCode = sp.CountryRegionCode
    ORDER BY
        cpd.FechaCompra,
        Cliente,
        c.CustomerID,
        cpd.ShipToAddressID,
        pr.Name
    OPTION (RECOMPILE); 
END;
GO