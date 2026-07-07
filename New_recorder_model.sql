SELECT
    Category,
    ROUND(AVG(Demand_Forecast_N), 2) AS avg_forecast,
    ROUND(STDDEV(Units_Sold), 2) AS stddev_units_sold,
    ROUND(AVG(Demand_Forecast_N) + 1.28 * STDDEV(Units_Sold), 1) AS reorder_qty_90,
    ROUND(AVG(Demand_Forecast_N) + 1.65 * STDDEV(Units_Sold), 1) AS reorder_qty_95,
    ROUND(AVG(Demand_Forecast_N) + 2.33 * STDDEV(Units_Sold), 1) AS reorder_qty_99
FROM retail_store_inventory
GROUP BY Category;
-- From Safety_Stock = Z × STDDEV(demand) × √(lead time) assuming lead time =1 (this formula gives a lot of inventory like 3x which is not suitable ) 

-- now first will calculat the (Optimal Service Level = Cost of Stockout / (Cost of Stockout + Cost of Overstock))
SELECT
    year(Date),
    ROUND(AVG(Price), 2) AS avg_price,
    ROUND(AVG(Price)*0.25, 2) AS cost_of_Stockout,  -- assuming the margin of 25% accros all the product 
    ROUND(AVG(Price)*0.20, 2) AS Cost_of_Overstock,  -- assuming the 20% annual cost 
    round(100*ROUND(AVG(Price)*0.25, 2)/(ROUND(AVG(Price)*0.25, 2) +ROUND(AVG(Price)*0.20, 2)),2) as Optimal_Service_Level
FROM retail_store_inventory
GROUP BY 1

-- From this we got that Z-Score is 0.14 for service level 55.55 % 

SELECT
    Category,
    ROUND(AVG(Demand_Forecast_N), 2) AS avg_forecast,
	ROUND(AVG(Units_Sold), 2) AS avg_U_solds,
    ROUND(AVG(Units_Ordered), 2) AS avg_ordered,
    ROUND(AVG(Demand_Forecast_N) + 0.14 * STDDEV(Units_Sold), 1) AS reorder_qty
FROM retail_store_inventory
GROUP BY Category;

-- Cu & Co columns are added 
ALTER TABLE retail_store_inventory
ADD COLUMN Cu DECIMAL(10,2),
ADD COLUMN Co DECIMAL(10,2);

UPDATE retail_store_inventory
SET Cu = ROUND(Price * 0.25, 2),
    Co = ROUND(Price * 0.20, 2);
    
-- rebuild summary query using these new columns
SELECT
    Category,
    ROUND(AVG(Demand_Forecast_N), 2) AS avg_forecast,
    ROUND(STDDEV(Units_Sold), 2) AS stddev_units_sold,
    ROUND(AVG(Cu), 2) AS avg_cu,
    ROUND(AVG(Co), 2) AS avg_co,
    ROUND(100 * AVG(Cu) / (AVG(Cu) + AVG(Co)), 2) AS critical_ratio_pct
FROM retail_store_inventory
GROUP BY 1;

-- Critical Ratio is 55.56 % then Z = 0.14
SELECT
    Category,
    ROUND(AVG(Demand_Forecast_N), 2) AS avg_forecast,
    ROUND(STDDEV(Units_Sold), 2) AS stddev_units_sold,
    ROUND(AVG(Units_Ordered), 2) AS avg_current_ordered,
    ROUND(AVG(Demand_Forecast_N) + 0.14 * STDDEV(Units_Sold), 1) AS reorder_qty
FROM retail_store_inventory
GROUP BY Category;


-- New reorder column to be added 
ALTER TABLE retail_store_inventory
ADD COLUMN New_Reorder_Qty DECIMAL(10,2)


UPDATE retail_store_inventory
SET New_Reorder_Qty = Demand_Forecast_N + round(0.14 * (
    CASE Category
        WHEN 'Groceries'   THEN 109.25
        WHEN 'Toys'        THEN 108.43
        WHEN 'Electronics' THEN 108.44
        WHEN 'Furniture'   THEN 110.01
        WHEN 'Clothing'    THEN 108.42
    END
),2)
-- As results are very off we have make some changes in formula 
UPDATE retail_store_inventory
SET New_Reorder_Qty = GREATEST(
    Demand_Forecast_N + round(0.14 * (
        CASE Category
            WHEN 'Groceries'   THEN 109.25
            WHEN 'Toys'        THEN 108.43
            WHEN 'Electronics' THEN 108.44
            WHEN 'Furniture'   THEN 110.01
            WHEN 'Clothing'    THEN 108.42
        END
    ),2),
    Units_Ordered
);

-- we have matched the std deviation of reorder with the Forecast 
SELECT Category, stddev(Demand_Forecast_N), stddev(Units_Ordered), stddev(New_Reorder_Qty)
FROM retail_store_inventory
group by 1


-- Now time is to mention that our model is good so we are going to add some colmuns 
ALTER TABLE retail_store_inventory
ADD COLUMN New_Inventory DECIMAL(10,2),
ADD COLUMN New_Closing DECIMAL(10,2),
ADD COLUMN New_Stockout TINYINT;

UPDATE retail_store_inventory
SET New_Inventory = Inventory_Level + (New_Reorder_Qty - Units_Ordered);
UPDATE retail_store_inventory
SET New_Closing = New_Inventory - New_Units_Sold;

UPDATE retail_store_inventory
SET New_Stockout = CASE WHEN New_Closing <= 0 THEN 1 ELSE 0 END;


SELECT
    SUM(CASE WHEN stockout = 'Stock Out' THEN 1 ELSE 0 END) AS actual_stockouts,
    SUM(New_Stockout) AS simulated_stockouts,
    ROUND(100*SUM(CASE WHEN stockout = 'Stock Out' THEN 1 ELSE 0 END)/COUNT(*), 2) AS actual_stockout_pct,
    ROUND(100*SUM(New_Stockout)/COUNT(*), 2) AS simulated_stockout_pct,
    ROUND(AVG(Inventory_Level), 1) AS avg_actual_inventory,
    ROUND(AVG(New_Inventory), 1) AS avg_simulated_inventory
FROM retail_store_inventory;


-- Now let's get how much money we will save or recoverd 

-- let's add a newunit sold column because from old inventory there are some sales are low because of low inventory 

ALTER TABLE retail_store_inventory ADD COLUMN New_Units_Sold DECIMAL(10,2);
UPDATE retail_store_inventory
SET New_Units_Sold = CASE
    WHEN stockout = 'Stock Out' THEN LEAST(New_Inventory, Demand_Forecast_N)
    ELSE Units_Sold
END;

SELECT
    SUM(GREATEST(Demand_Forecast_N - Units_Sold, 0) * Cu/1000000) AS profit_lost_actual,
    SUM(GREATEST(Demand_Forecast_N - New_Units_Sold, 0) * Cu/1000000) AS profit_lost_simulated,
    SUM((New_Inventory - Inventory_Level) * Co/1000000) AS extra_holding_cost
FROM retail_store_inventory;

-- giving previous the wrong number because Co is giving per row day total cost of year not per day 

SELECT
    SUM(GREATEST(Demand_Forecast_N - Units_Sold, 0) * Cu) AS profit_lost_actual,
    SUM(GREATEST(Demand_Forecast_N - New_Units_Sold, 0) * Cu) AS profit_lost_simulated,
    SUM((New_Units_Sold - Units_Sold) * Price) AS revenue_increase,
    SUM((New_Units_Sold - Units_Sold) * Cu) AS profit_increase,
    SUM(New_Units_Sold - Units_Sold) AS units_sold_diff,
    SUM((New_Inventory - Inventory_Level) * Co / 365) AS extra_holding_cost_daily
FROM retail_store_inventory;
