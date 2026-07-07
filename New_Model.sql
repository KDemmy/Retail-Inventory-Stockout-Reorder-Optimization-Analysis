-- See where most of New_reorder formula needed 
SELECT
    Category,
    Region,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN stockout = 'Stock Out' THEN 1 ELSE 0 END) AS stockout_count,
    ROUND(100 * SUM(CASE WHEN stockout = 'Stock Out' THEN 1 ELSE 0 END) / COUNT(*), 2) AS stockout_pct
FROM retail_store_inventory
GROUP BY Category, Region
having stockout_pct > 0.55
ORDER BY stockout_pct DESC

-- Add a flag column where stockout_per is abpve 0.55 %
ALTER TABLE retail_store_inventory
ADD COLUMN High_Risk_Segment TINYINT;

UPDATE retail_store_inventory
SET High_Risk_Segment = CASE
    WHEN (Category = 'Toys' AND Region = 'West') THEN 1
    WHEN (Category = 'Electronics' AND Region = 'West') THEN 1
    WHEN (Category = 'Furniture' AND Region = 'West') THEN 1
    WHEN (Category = 'Toys' AND Region = 'East') THEN 1
    WHEN (Category = 'Clothing' AND Region = 'North') THEN 1
    WHEN (Category = 'Toys' AND Region = 'South') THEN 1
    ELSE 0
END;

-- Rebuild New_Reorder_Qty — only change it for high-risk rows
UPDATE retail_store_inventory
SET New_Reorder_Qty = CASE
    WHEN High_Risk_Segment = 1
         AND Demand_Forecast_N > (
             CASE Category
                 WHEN 'Groceries'   THEN 141.90 + 109.25
                 WHEN 'Toys'        THEN 141.05 + 108.43
                 WHEN 'Electronics' THEN 140.04 + 108.44
                 WHEN 'Furniture'   THEN 142.86 + 110.01
                 WHEN 'Clothing'    THEN 141.78 + 108.42
             END
         )
    THEN GREATEST(
        Demand_Forecast_N + round(0.14 * (
            CASE Category
                WHEN 'Groceries'   THEN 109.25
                WHEN 'Toys'        THEN 108.43
                WHEN 'Electronics' THEN 108.44
                WHEN 'Furniture'   THEN 110.01
                WHEN 'Clothing'    THEN 108.42
            END
        ),2), Units_Ordered)
    ELSE Units_Ordered
END;

UPDATE retail_store_inventory
SET New_Inventory = Inventory_Level + (New_Reorder_Qty - Units_Ordered);

UPDATE retail_store_inventory
SET New_Closing = New_Inventory - Units_Sold;

UPDATE retail_store_inventory
SET New_Stockout = CASE WHEN New_Closing <= 0 THEN 1 ELSE 0 END;

UPDATE retail_store_inventory
SET New_Units_Sold = CASE
    WHEN High_Risk_Segment = 1
         AND stockout = 'Stock Out'
         AND Demand_Forecast_N > (
             CASE Category
                 WHEN 'Groceries'   THEN 141.90 + 109.25
                 WHEN 'Toys'        THEN 141.05 + 108.43
                 WHEN 'Electronics' THEN 140.04 + 108.44
                 WHEN 'Furniture'   THEN 142.86 + 110.01
                 WHEN 'Clothing'    THEN 141.78 + 108.42
             END
         )
    THEN LEAST(New_Inventory, Demand_Forecast_N)
    ELSE Units_Sold
END;


SELECT
    SUM(GREATEST(Demand_Forecast_N - Units_Sold, 0) * Cu) AS profit_lost_actual,
    SUM(GREATEST(Demand_Forecast_N - New_Units_Sold, 0) * Cu) AS profit_lost_simulated,
    SUM((New_Units_Sold - Units_Sold) * Price) AS revenue_increase,
    SUM((New_Units_Sold - Units_Sold) * Cu) AS profit_increase,
    SUM(New_Units_Sold - Units_Sold) AS units_sold_diff,
    SUM((New_Inventory - Inventory_Level) * Co / 365) AS extra_holding_cost_daily
FROM retail_store_inventory;