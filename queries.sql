-- Queries to answer predetermined questions from a business stakeholder

-- Question 1: What are the top 5 brands by receipts scanned for most recent month?
-- Get most recent month
with most_recent_month as (
select max(substring(dateScanned, 1, 7)) as recent_year_month
from receipts
)

-- brand code-wise aggregation - count of distinct receipts based on every brand code
select br.name, count(distinct re.receipt_id) as tot_receipts, rank() over (order by count(distinct re.receipt_id) desc) as rank_most_recent_month
from 
  receipts as re -- joined receipt with receiptItemList for brand code-wise aggregation
  join 
  receiptItemList as item on re.user_id = item.user_id and re.receipt_id = item.receipt_id
  join
  brands as br on item.barcode = br.barcode -- joined with brands using barcode considering it is unique
where True
  and substring(re.dateScanned, 1, 7) = (select * from most_recent_month) -- condition to get receipts from most recent month
group by 1
order by 2 desc
limit 5
-- Assuming the aggregate will be unique for all brands else we can use rank or dense_rank



-- Questions 2: How does the ranking of the top 5 brands by receipts scanned for the recent month compare to the ranking for the previous month?
-- Get year month in recency order
with year_month_rank as (
select year_month, rank() over (order by year_month desc) rank
from 
  (select distinct substring(dateScanned, 1, 7) year_month
  from receipts
  order by 1 DESC)
)

-- brand code-wise aggregation - most recent month
, recent_month_rank as (
select br.name, count(distinct re.receipt_id) as tot_receipts, rank() over (order by count(distinct re.receipt_id) desc) as rank_most_recent_month
from 
  receipts as re -- joined receipt with receiptItemList for brand code-wise aggregation
  join 
  receiptItemList as item on re.user_id = item.user_id and re.receipt_id = item.receipt_id
  join
  brands as br on item.barcode = br.barcode -- joined with brands using barcode considering it is unique
where True
  and substring(dateScanned, 1, 7) = (select * from year_month_rank where rank = 1) -- condition to get receipts from most recent month
group by 1
order by 2 desc
)

-- brand code-wise aggregation - previous month
, previous_month_rank as (
select br.name, count(distinct re.receipt_id) as tot_receipts, rank() over (order by count(distinct re.receipt_id) desc) as rank_previous_month
from 
  receipts as re -- joined receipt with receiptItemList for brand code-wise aggregation
  join 
  receiptItemList as item on re.user_id = item.user_id and re.receipt_id = item.receipt_id
  join
  brands as br on item.barcode = br.barcode -- joined with brands using barcode considering it is unique
where True
  and substring(dateScanned, 1, 7) = (select year_month from year_month_rank where rank = 2) -- condition to get receipts from previous month
group by 1
order by 2 desc
)

-- this query will show the ranking of the top 5 brands for the recent month and show their previous month's ranking
-- this way it is easy to compare how the brand performed in the recent month compared to the previous month
select recent_month_rank.brandCode, rank_most_recent_month, rank_previous_month
from recent_month_rank left join previous_month_rank on recent_month_rank.brandCode = previous_month_rank.brandCode
where True 
      and rank_most_recent_month <= 5



-- Question 3: When considering average spend from receipts with 'rewardsReceiptStatus’ of ‘Accepted’ or ‘Rejected’, which is greater?
-- CTE to get average spent by status
with cte as (
select rewardsReceiptStatus, avg(totalSpent) as avg_spent
from receipts
where True 
      and rewardsReceiptStatus in ('FINISHED', 'REJECTED') -- Infering 'FINISHED' as 'Accepted' based on pointsAwardedDate column values
group by 1
)

-- query to get the status with the highest average spent
select rewardsReceiptStatus, avg_spent as highest_avg
from cte
where True
  and avg_spent = (select max(avg_spent) from cte)



-- Question 4: When considering total number of items purchased from receipts with 'rewardsReceiptStatus’ of ‘Accepted’ or ‘Rejected’, which is greater?
-- CTE to get total item purchased by status
with cte as (
select rewardsReceiptStatus, sum(purchasedItemCount) as total_itemsPurchased
from receipts
where True
      and rewardsReceiptStatus in ('FINISHED', 'REJECTED') -- Assuming 'FINISHED' is equivalent to 'Accepted'
group by 1
)

-- query to get the status with the highest number of items purchaseed
select rewardsReceiptStatus, total_itemsPurchased as highest_item
from cte
where True
  and avg_spent = (select max(total_itemsPurchased) from cte)



-- Question 5: Which brand has the most spend among users who were created within the past 6 months?
-- users created within the past 6 months
with recent_users as (
select distinct user_id
from users
where True 
      and createdDate >= DATEADD(month, -6, CURRENT_DATE))

-- Top 1 brand with the most spend
select br.name, sum(re.totalSpent) as tot_spent
from 
  receipts as re -- joined receipt with receiptItemList for brand code-wise aggregation
  join 
  receiptItemList as item on re.user_id = item.user_id and re.receipt_id = item.receipt_id
  join
  brands as br on item.barcode = br.barcode -- joined with brands to get brand name
  join 
  recent_users on re.user_id = users.user_id -- filter to last 6 months
group by 1
order by 2 desc
limit 1



-- Question 6: Which brand has the most transactions among users who were created within the past 6 months?
-- users created within the past 6 months
with recent_users as (
select distinct user_id
from users
where True 
      and createdDate >= DATEADD(month, -6, CURRENT_DATE))

-- Every receipt is a transaction by a user
select br.name, count(distinct receipt_id) as total_transactions
from 
  receipts as re -- joined receipt with receiptItemList for brand code-wise aggregation
  join 
  receiptItemList as item on re.user_id = item.user_id and re.receipt_id = item.receipt_id
  join
  brands as br on item.barcode = br.barcode -- joined with brands to get brand name
  join 
  recent_users on re.user_id = users.user_id -- filter to last 6 months
group by 1
order by 2 desc
limit 1
