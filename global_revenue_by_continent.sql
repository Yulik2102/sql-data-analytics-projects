WITH continent_sessions AS (
  -- Step 1: Calculate total web sessions for each continent
  SELECT 
    sp.continent AS continent,
    COUNT(1) AS sessions_count
  FROM `DA.session_params` AS sp
  GROUP BY 1
),

continent_revenue AS (
  -- Step 2: Calculate financial metrics including device breakdowns and percentage of total global revenue
  SELECT 
    sp.continent AS continent,
    SUM(p.price) AS total_revenue,
    SUM(CASE WHEN sp.device = 'mobile' THEN p.price ELSE 0 END) AS revenue_from_mobile,
    SUM(CASE WHEN sp.device = 'desktop' THEN p.price ELSE 0 END) AS revenue_from_desktop,
    
    -- Percentage of Total Revenue: Calculates the current continent's share against the entire global revenue
    ROUND(SUM(p.price) * 100.0 / SUM(SUM(p.price)) OVER (), 2) AS pct_revenue_of_total
  FROM `DA.order` AS o
  INNER JOIN `DA.product` AS p
    ON o.item_id = p.item_id
  INNER JOIN `DA.session_params` AS sp
    ON o.ga_session_id = sp.ga_session_id
  GROUP BY 1
),

continent_accounts AS (
  -- Step 3: Analyze user reach by calculating unique accounts and verified users per continent
  SELECT
    sp.continent AS continent,
    COUNT(DISTINCT acs.account_id) AS total_accounts_count,
    COUNT(DISTINCT CASE WHEN ac.is_verified = 1 THEN ac.id END) AS verified_accounts_count
  FROM `DA.session_params` AS sp
  LEFT JOIN `DA.account_session` AS acs
    ON sp.ga_session_id = acs.ga_session_id
  LEFT JOIN `DA.account` AS ac
    ON acs.account_id = ac.id
  GROUP BY 1
)

-- Final Step: Consolidate revenue, traffic (sessions), and user account metrics grouped by Continent
SELECT 
  cr.continent,
  cr.total_revenue,
  cr.revenue_from_mobile,
  cr.revenue_from_desktop,
  cr.pct_revenue_of_total,
  ca.total_accounts_count,
  ca.verified_accounts_count,
  cs.sessions_count
FROM continent_revenue AS cr
LEFT JOIN continent_sessions AS cs
  ON cr.continent = cs.continent
INNER JOIN continent_accounts AS ca
  ON cr.continent = ca.continent
ORDER BY cr.total_revenue DESC;
