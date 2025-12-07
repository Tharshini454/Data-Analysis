select * from customer_churn;
SET SQL_SAFE_UPDATES = 0;

-- Impute mean for the following columns, and round off to the nearest integer if required: WarehouseToHome, HourSpendOnApp, OrderAmountHikeFromlastYear, DaySinceLastOrder --
SET @Warehouse = (select round(avg(WarehouseToHome)) from customer_churn);
update customer_churn
set WarehouseToHome = @Warehouse
where WarehouseToHome is null;

SET @HourSpend = (select round(avg(HourSpendOnApp)) from customer_churn);
update customer_churn
set HourSpendOnApp = @HourSpend
where HourSpendOnApp is null;

SET @DaySince = (select round(avg(DaySinceLastOrder)) from customer_churn);
update customer_churn
set DaySinceLastOrder = @DaySince
where DaySinceLastOrder is null;

SET @OrderAmountHike = (select round(avg(OrderAmountHikeFromlastYear)) from customer_churn);
update customer_churn
set OrderAmountHikeFromlastYear = @OrderAmountHike
where OrderAmountHikeFromlastYear is null;

-- Impute mode for the following columns: Tenure, CouponUsed, OrderCount --
SET @tenure = (select Tenure from customer_churn group by tenure order by count(*) desc limit 1);
update customer_churn
set tenure = @tenure
where tenure is null;

SET @Coupon = (select CouponUsed from customer_churn group by CouponUsed order by count(*) desc limit 1);
update customer_churn
set CouponUsed = @Coupon
where CouponUsed is null;

SET @OrderCount = (select OrderCount from customer_churn group by OrderCount order by count(*) desc limit 1);
update customer_churn
set OrderCount = @OrderCount
where OrderCount is null;

-- Handle outliers in the 'WarehouseToHome' column by deleting rows where the values are greater than 100 --
SELECT * FROM customer_churn WHERE WarehouseToHome > 100;
DELETE FROM customer_churn WHERE WarehouseToHome > 100;

-- Replace occurrences of “Phone” in the 'PreferredLoginDevice' column and “Mobile” in the 'PreferedOrderCat' column with “Mobile Phone” to ensure uniformity --
UPDATE customer_churn
SET PreferredLoginDevice = 'Mobile Phone'
WHERE PreferredLoginDevice = 'Phone';

UPDATE customer_churn
SET PreferedOrderCat = 'Mobile Phone'
WHERE PreferedOrderCat = 'Mobile';

-- Standardize payment mode values: Replace "COD" with "Cash on Delivery" and "CC" with "Credit Card" in the PreferredPaymentMode column --
UPDATE customer_churn
SET PreferredPaymentMode = CASE
    WHEN PreferredPaymentMode = 'COD' THEN 'Cash on Delivery'
    WHEN PreferredPaymentMode = 'CC'  THEN 'Credit Card'
    ELSE PreferredPaymentMode
END;

-- Column Renaming --
ALTER TABLE customer_churn
RENAME COLUMN PreferedOrderCat TO PreferredOrderCat;
ALTER TABLE customer_churn
RENAME COLUMN HourSpendOnApp TO HoursSpentOnApp;

-- Creating New Columns --
ALTER TABLE customer_churn 
ADD COLUMN ComplaintReceived VARCHAR(3),
ADD COLUMN ChurnStatus varchar(20);

UPDATE customer_churn
SET 
    ComplaintReceived = CASE 
        WHEN Complain = 1 THEN 'Yes'
        ELSE 'No'
    END,
    ChurnStatus = CASE
        WHEN Churn = 1 THEN 'Churned'
        ELSE 'Active'
    END;
    
-- Column Dropping --
ALTER TABLE customer_churn
DROP COLUMN Churn,
DROP COLUMN Complain;

-- Data Exploration and Analysis --
-- 1. Retrieve the count of churned and active customers from the dataset --
SELECT ChurnStatus, COUNT(*) AS CustomerCount
FROM customer_churn
GROUP BY ChurnStatus;

-- 2. Display the average tenure and total cashback amount of customers who churned --
SELECT AVG(Tenure) AS AvgTenureOfChurned, SUM(CashbackAmount) AS TotalCashbackOfChurned
FROM customer_churn
WHERE ChurnStatus = 'Churned';

-- 3. Determine the percentage of churned customers who complained --
SELECT (COUNT(CASE WHEN ComplaintReceived = 'Yes' THEN 1 END) * 100.0 / COUNT(*)) AS PercentChurnedWithComplaints
FROM customer_churn
WHERE ChurnStatus = 'Churned';

--  4. Identify the city tier with the highest number of churned customers whose preferred order category is Laptop & Accessory --
select CityTier from customer_churn where ChurnStatus = "Churned" AND PreferredOrderCat = "Laptop & Accessory"
group by CityTier order by count(*) desc limit 1;

-- 5. Identify the most preferred payment mode among active customers --
Select PreferredPaymentMode from customer_churn where ChurnStatus = "Active" 
group by PreferredPaymentMode order by count(*) desc limit 1;

-- 6. Calculate the total order amount hike from last year for customers who are single and prefer mobile phones for ordering --
SELECT SUM(OrderAmountHikeFromLastYear) 'TotalHike'
FROM customer_churn
WHERE MaritalStatus = 'Single' AND PreferredOrderCat = 'Mobile Phone';

-- 7. Find the average number of devices registered among customers who used UPI as their preferred payment mode --
select avg(NumberOfDeviceRegistered) as avgdevicesregistered
from customer_churn where PreferredPaymentMode = 'UPI';

-- 8. Determine the city tier with the highest number of customers --
select citytier, count(*) as customer_count from customer_churn
group by citytier
order by customer_count desc limit 1;

-- 9. Identify the gender that utilized the highest number of coupons --
select gender, sum(couponused) as total_coupons_used
from customer_churn
group by gender
order by total_coupons_used desc
limit 1;

-- 10. List the number of customers and the maximum hours spent on the app in each preferred order category --
select preferredordercat, count(*) as customer_count, max(hoursspentonapp) as max_hours_spent
from customer_churn
group by preferredordercat;

-- 11. Calculate the total order count for customers who prefer using credit cards and have the maximum satisfaction score --
select sum(ordercount) as total_order_count
from customer_churn
where preferredpaymentmode = 'Credit Card' 
and satisfactionscore = (select max(satisfactionscore) from customer_churn);

-- 12. What is the average satisfaction score of customers who have complained --
select avg(satisfactionscore) as avg_of_complained
from customer_churn
where complaintreceived = 'Yes';

-- 13. List the preferred order category among customers who used more than 5 coupons --
select preferredordercat, count(*) as countofcustomer
from customer_churn
where couponused > 5
group by preferredordercat
order by count(*) desc;

-- 14. List the top 3 preferred order categories with the highest average cashback amount --
select preferredordercat, avg(cashbackamount) as avgcashback
from customer_churn
group by preferredordercat
order by avgcashback desc
limit 3;

-- 15. Find the preferred payment modes of customers whose average tenure is 10 months and have placed more than 500 orders --
select preferredpaymentmode, count(*) as customer_count
from customer_churn
group by preferredpaymentmode
having avg(tenure) = 10 and sum(ordercount) > 500
order by customer_count desc;

-- 16. Categorize customers based on their distance from the warehouse to home such as 'Very Close Distance' for distances <=5km, 'Close Distance' for <=10km,
-- 'Moderate Distance' for <=15km, and 'Far Distance' for >15km. Then, display the
-- churn status breakdown for each distance category --
select case 
        when warehousetohome <= 5 then 'Very Close Distance'
        when warehousetohome <= 10 then 'Close Distance'
        when warehousetohome <= 15 then 'Moderate Distance'
        else 'Far Distance'
    end as distance_category,
    churnstatus,
    count(*) as customer_count
from customer_churn
group by distance_category, churnstatus;

-- 17. List the customer’s order details who are married, live in City Tier-1, and their order counts are more than the average number of orders placed by all customers --
select * from customer_churn
where maritalstatus = 'Married' and citytier = '1'
and ordercount > (select avg(ordercount) from customer_churn);


-- a) Create the customer_returns table and insert data --
-- create table
create table customer_returns (
    ReturnID int primary key,
    CustomerID int,
    ReturnDate date,
    RefundAmount int
);

-- insert data
insert into ecomm.customer_returns (ReturnID, CustomerID, ReturnDate, RefundAmount) values
(1001, 50022, '2023-01-01', 2130),
(1002, 50316, '2023-01-23', 2000),
(1003, 51099, '2023-02-14', 2290),
(1004, 52321, '2023-03-08', 2510),
(1005, 52928, '2023-03-20', 3000),
(1006, 53749, '2023-04-17', 1740),
(1007, 54206, '2023-04-21', 3250),
(1008, 54838, '2023-04-30', 1990);

-- b) Display return details with customer details for those who churned and complained --
select cr.*, cc.*
from customer_returns cr
join customer_churn cc
on cr.CustomerID = cc.CustomerID
where cc.ChurnStatus = 'Churned'
and cc.ComplaintReceived = 'Yes';






 





























