WITH filtered_accounts AS (
  -- Step 1: Filter out unsubscribed users immediately to optimize query performance
  SELECT 
    id
  FROM `data-analytics-mate.DA.account`
  WHERE is_unsubscribed = 0
),

email_message_flags AS (
  -- Step 2: Track if each sent email was opened or led to a website visit
  -- Using MAX(IF(...)) to handle potential duplicate events and create binary flags (1 or 0)
  SELECT 
    es.id_account,
    es.id_message,
    MAX(IF(eo.id_message IS NOT NULL, 1, 0)) AS has_opened,
    MAX(IF(ev.id_message IS NOT NULL, 1, 0)) AS has_visited
  FROM `data-analytics-mate.DA.email_sent` AS es
  INNER JOIN filtered_accounts AS fa
    ON es.id_account = fa.id
  LEFT JOIN `data-analytics-mate.DA.email_open` AS eo
    ON es.id_message = eo.id_message
  LEFT JOIN `data-analytics-mate.DA.email_visit` AS ev
    ON es.id_message = ev.id_message
  GROUP BY 1, 2
),

account_email_metrics AS (
  -- Step 3: Aggregate email engagement metrics to the account level
  SELECT
    id_account,
    COUNT(1) AS emails_sent_count,
    SUM(has_opened) AS emails_opened_count,
    SUM(has_visited) AS emails_visited_count
  FROM email_message_flags
  GROUP BY 1
),

account_operating_systems AS (
  -- Step 4: Map each active account to their operating system(s) using session data
  SELECT DISTINCT
    acs.account_id AS id_account,
    sp.operating_system AS operating_system
  FROM `data-analytics-mate.DA.account_session` AS acs
  INNER JOIN filtered_accounts AS fa
    ON acs.account_id = fa.id
  INNER JOIN `data-analytics-mate.DA.session_params` AS sp
    ON acs.ga_session_id = sp.ga_session_id
)

-- Final Step: Calculate global marketing performance metrics (OR, CR, CTOR) grouped by Operating System
SELECT
  aos.operating_system,
  SUM(aem.emails_sent_count) AS total_emails_sent,
  SUM(aem.emails_opened_count) AS total_emails_opened,
  SUM(aem.emails_visited_count) AS total_emails_visited,
  
  -- Open Rate (OR): Percentage of sent emails that were opened
  ROUND(SUM(aem.emails_opened_count) / SUM(aem.emails_sent_count) * 100, 2) AS open_rate,
  
  -- Click Rate (CR) / Visit Rate: Percentage of sent emails that led to a website visit
  ROUND(SUM(aem.emails_visited_count) / SUM(aem.emails_sent_count) * 100, 2) AS click_rate,
  
  -- Click-to-Open Rate (CTOR): Percentage of opened emails that led to a website visit
  ROUND(SUM(aem.emails_visited_count) / SUM(aem.emails_opened_count) * 100, 2) AS click_to_open_rate

FROM account_email_metrics AS aem
INNER JOIN account_operating_systems AS aos
  ON aem.id_account = aos.id_account
GROUP BY 1
ORDER BY total_emails_sent DESC;
