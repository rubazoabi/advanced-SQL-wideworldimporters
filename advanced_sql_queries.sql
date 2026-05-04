
--Q1

GO 

WITH T1
AS
(
SELECT  DISTINCT YEAR,IncomePerYear,
COUNT(MONTHS) OVER(PARTITION BY Year) as NumberOfDistinctMonths,
ROUND(IncomePerYear/COUNT(MONTHS)OVER (PARTITION BY Year)*12,2) as YearlyLinearIncome
FROM

( SELECT 
DISTINCT MONTH(I.invoiceDate) AS MONTHS,
YEAR(I.invoiceDate) AS YEAR ,
SUM(il.ExtendedPrice- IL.TaxAmount) OVER (PARTITION BY YEAR(I.invoiceDate)) AS IncomePerYear
from SALES.invoiceLines IL join SALES.Invoices I
ON il.invoiceID=I.invoiceID
) T
) 
SELECT*,
CAST ((YearlyLinearIncome- LAG(YearlyLinearIncome) OVER ( ORDER BY YEAR))/YearlyLinearIncome*100 as DECIMAL(10,2))AS GrowthRate
FROM T1


--Q2

GO 

WITH q 
AS (
SELECT
YEAR(I.InvoiceDate) AS TheYear,
DATEPART(QUARTER, I.InvoiceDate) AS TheQuarter,
c.CustomerName,
SUM(IL.UnitPrice * IL.Quantity) AS IncomePerQuarterYear
FROM Sales.Invoices I JOIN Sales.InvoiceLines IL
ON IL.InvoiceID = I.InvoiceID
join sales.Customers C
on c.CustomerID=i.CustomerID
GROUP BY YEAR(I.InvoiceDate),DATEPART(QUARTER, I.InvoiceDate), c.CustomerName
),
r AS 
(SELECT*,
DENSE_RANK() OVER (PARTITION BY TheYear, TheQuarter ORDER BY IncomePerQuarterYear DESC) AS DNR
FROM q
)
SELECT 
TheYear,
TheQuarter,
customername,
IncomePerQuarterYear,
DNR
FROM r
WHERE DNR <= 5
ORDER BY TheYear,TheQuarter, IncomePerQuarterYear DESC

--Q3

go

select DISTINCT top 10 SI.StockItemID, SI.StockItemName,
       SUM (IL.ExtendedPrice-IL.TaxAmount) OVER( PARTITION BY IL.StockItemID) AS TotalProfit
from sales.InvoiceLines IL join Warehouse.StockItems SI
ON IL.StockItemID=SI.StockItemID
order by TotalProfit desc


--Q4

go 


select ROW_NUMBER() OVER(Order by s.UnitPrice desc) AS RN,
s.StockItemID, s.StockItemName, s.UnitPrice, s.RecommendedRetailPrice,
s.RecommendedRetailPrice-s.UnitPrice as NominalProductProfit ,
DENSE_RANK()OVER( ORDER BY s.UnitPrice DESC) AS DNR
from Warehouse.StockItems S
where s.ValidTo= '9999-12-31 23:59:59.9999999' -- still valid till today
order by NominalProductProfit desc 


--Q5


go 

with Tabl
as 
(
select s.SupplierID as ID,s.SupplierName as sName,
STUFF( 
(select Concat(' /, ', ol.StockItemID,' ',ol.Description)
FROM Purchasing.PurchaseOrderLines Ol join Purchasing.PurchaseOrders O
on ol.PurchaseOrderID=o.PurchaseOrderID 
join Warehouse.StockItems St
on st.StockItemID=Ol.StockItemID
where O.SupplierID=s.SupplierID 
FOR XML PATH('')),1,4,'') as ProductsDetails
from purchasing.suppliers s 
)
select  concat (tabl.ID,' - ',tabl.sName)  as SupplierDetails, ProductsDetails
from tabl
where tabl.ProductsDetails is not null
order by tabl.ID


--Q6


go 

with pro
as
(
select distinct top 5 I.CustomerID, sum (il.ExtendedPrice ) over (partition by i.customerId) as TotalExtendedPrice
from sales.InvoiceLines Il join  sales.Invoices I
on il.InvoiceID=i.InvoiceID
order by TotalExtendedPrice desc
),
ad
as
(
select C.CustomerID,CityName, CountryName, Region, Continent
from Sales.Customers C join Application.Cities city
on c.DeliveryCityID=city.CityID
join Application.StateProvinces SP
on sp.StateProvinceID=city.StateProvinceID
join Application.Countries country
on sp.CountryID=country.CountryID
)
select pro.CustomerID,CityName,CountryName,Continent,Region,TotalExtendedPrice
from pro join ad
on pro.customerid=ad.CustomerID


--Q7

GO

WITH monthly 
As
(
SELECT YEAR(I.InvoiceDate)  AS yy, MONTH(I.InvoiceDate) AS mm,
SUM(IL.UnitPrice * IL.Quantity) AS total
FROM Sales.InvoiceLines IL
JOIN Sales.Invoices I ON IL.InvoiceID = I.InvoiceID
GROUP BY YEAR(I.InvoiceDate), MONTH(I.InvoiceDate)
),
roll AS
(
SELECT yy,mm, SUM(total) AS total
FROM monthly
GROUP BY ROLLUP (yy, mm)
),
finaldata 
AS (
SELECT yy,mm, total,
SUM(CASE WHEN mm IS NOT NULL THEN total END) OVER ( PARTITION BY yy ORDER BY mm
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS CumulativeTotal
FROM roll
)
SELECT
CAST(yy AS varchar(10)) AS InvoiceYear,
CASE
    WHEN mm IS NULL THEN 'Grandtotal'
    ELSE CAST(mm AS varchar(2))   
    END AS InvoiceMonth,
    total AS TotalAmount,
    CASE
        WHEN mm IS NULL THEN MAX(CumulativeTotal) OVER (PARTITION BY yy)
        ELSE CumulativeTotal
    END AS CumulativeTotal
FROM finaldata
WHERE yy IS NOT NULL                  -- to remove the grand total for all years 
ORDER BY yy, 
    CASE 
        WHEN mm IS NULL THEN 1 ELSE 0 END 
        , mm
--Q8


GO

SELECT DISTINCT MM ,[2013],[2014],[2015], [2016]
FROM (SELECT YEAR(o.OrderDate) AS YY,MONTH(o.OrderDate) AS MM, 
COUNT (O.OrderID) OVER(PARTITION BY MONTH(o.OrderDate)) AS ORDERS
			FROM SALES.Orders o
			) T
PIVOT(COUNT(ORDERS) FOR YY IN ([2013],[2014],[2015], [2016])) AS PVT



--Q9

go

with t1
as
(
select C.CustomerID,C.CustomerName, O.OrderDate,
LAG(O.ORDERDATE,1) OVER(PARTITION BY c.customerid ORDER BY O.orderdate desc) AS PreviousOrderDate,
max(O.orderdate) over(partition by c.customerId order by o.orderdate desc) as LastCustOrderDate,
max(O.orderdate) over() as LastOrderDateAll
FROM SALES.Orders O JOIN SALES.Customers C
ON O.CustomerID=C.CustomerID
),
t3
as
(
select*, avg( datediff(DD,orderdate,previousOrderDate)) over( PARTITION BY customerid) as AvgDaysBetweenOrders,
datediff(DD,LastCustOrderDate,LastOrderDateAll) as DaysSinceLastOrder
from t1
)
select CustomerID,CustomerName,OrderDate,PreviousOrderDate, AvgDaysBetweenOrders,
LastCustOrderDate,LastOrderDateAll,DaysSinceLastOrder,
CASE
    WHEN DaysSinceLastOrder< 2*AvgDaysBetweenOrders 
    THEN   'active'
    ELSE 'Potential Churn'
END AS CustomerStatus
from t3

--Q10


go

with t1
as 
(
select distinct
c.customerName, cat.CustomerCategoryName,cat.CustomerCategoryID,
CASE
    WHEN PATINDEX('% (%', CustomerName) >5 
    THEN    STUFF(
            CustomerName,
            PATINDEX('% (%', CustomerName),
           len(CustomerName),
            '.')
	when PATINDEX('% %', CustomerName) > 0
	THEN    STUFF(
            CustomerName,
            PATINDEX('% %', CustomerName),
            1,
            '.')
    ELSE CustomerName
END AS splittedname
from sales.Customers C join  sales.CustomerCategories cat
on c.CustomerCategoryID=cat.CustomerCategoryID
)
, t4
as
(
select customerName,CustomerCategoryName,CustomerCategoryID,
case WHEN PATINDEX('%.%', splittedname) < len(splittedname)-1
then ParseName(splittedname,2)+' '+ ParseName(splittedname,1) 
else splittedname
end as full_name
from t1
), 
t2
as 
( select distinct full_name as op, CustomerCategoryName
from t4 ),
t5 as
(
select distinct CustomerCategoryName,
convert (float ,count(op) over(partition by CustomerCategoryName))as CustomerCount,
convert (float ,count (op) over()) as TotalCustCount
from t2
) 
select*,
concat (ROUND(convert(float,CustomerCount/TotalCustCount*100),2),'%') as DistributionFactor
from t5


