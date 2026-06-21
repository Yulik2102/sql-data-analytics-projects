CREATE OR REPLACE VIEW `data-analytics-mate.Students.v_metrics_yulii` AS
WITH
 calculated_send_date AS (
   -- Розрахунок дати відправки листа
   SELECT
     es.id_account AS id_account,
     es.id_message AS id_message,
     acs.ga_session_id AS ga_session_id,
     DATE_ADD(s.date, INTERVAL es.sent_date DAY) AS send_date
   FROM `data-analytics-mate.DA.email_sent` es
   JOIN `data-analytics-mate.DA.account_session` acs
     ON es.id_account = acs.account_id
   JOIN `data-analytics-mate.DA.session` s
     ON acs.ga_session_id = s.ga_session_id
 ),
 account_metrics AS (
   -- Метрики реєстрацій
   -- Вважаємо датою створення акаунта день перед першою відправкою листа
   SELECT
     s.date AS date,
     sp.country AS country,
     a.send_interval AS send_interval,
     a.is_verified AS is_verified,
     a.is_unsubscribed AS is_unsubscribed,
     COUNT(DISTINCT a.id) AS account_cnt,
     0 AS sent_msg,
     0 AS open_msg,
     0 AS visit_msg
   FROM `data-analytics-mate.DA.account` a
   JOIN `data-analytics-mate.DA.account_session` acs
     ON a.id = acs.account_id
   JOIN `data-analytics-mate.DA.session` s
     ON acs.ga_session_id = s.ga_session_id
   JOIN `data-analytics-mate.DA.session_params` sp
     ON acs.ga_session_id = sp.ga_session_id
   GROUP BY 1, 2, 3, 4, 5
 ),
 email_metrics AS (
   -- Метрики імейлів
   -- Рахуємо унікальні повідомлення для відправок, відкриттів та візитів
   SELECT
     csd.send_date AS date,
     sp.country AS country,
     a.send_interval AS send_interval,
     a.is_verified AS is_verified,
     a.is_unsubscribed AS is_unsubscribed,
     0 AS account_cnt,
     COUNT(DISTINCT csd.id_message) AS sent_msg,
     COUNT(DISTINCT eo.id_message) AS open_msg,
     COUNT(DISTINCT ev.id_message) AS visit_msg
   FROM calculated_send_date csd
   LEFT JOIN `data-analytics-mate.DA.email_open` eo
     ON csd.id_message = eo.id_message
   LEFT JOIN `data-analytics-mate.DA.email_visit` ev
     ON csd.id_message = ev.id_message
   JOIN `data-analytics-mate.DA.account` a
     ON csd.id_account = a.id
   JOIN `data-analytics-mate.DA.session_params` sp
     ON csd.ga_session_id = sp.ga_session_id
   GROUP BY 1, 2, 3, 4, 5
 ),
 union_data AS (
   -- Об'єднання двох типів метрик в один потік даних
   SELECT * FROM account_metrics
   UNION ALL
   SELECT * FROM email_metrics
 ),
 grouped AS (
   -- агрегація, обьєнюємо данні
   SELECT
     date,
     country,
     send_interval,
     is_verified,
     is_unsubscribed,
     SUM(account_cnt) AS account_cnt,
     SUM(sent_msg) AS sent_msg,
     SUM(open_msg) AS open_msg,
     SUM(visit_msg) AS visit_msg
   FROM union_data
   GROUP BY 1, 2, 3, 4, 5
 ),
 with_totals AS (
   -- рахуємо total_country_account_cnt, total_country_sent_cnt щоб порахувати топ 10, тільки по країнам
   SELECT
     country,
     sum(account_cnt) AS total_country_account_cnt,
     sum(sent_msg) AS total_country_sent_cnt
   FROM grouped
   GROUP BY 1
 ),
 with_ranks AS (
   -- робимо топ 10, з допомогою RANK, щоб без пропуску
   SELECT
     country,
     total_country_account_cnt,
     total_country_sent_cnt,
     dense_rank()
       OVER (ORDER BY total_country_account_cnt DESC)
       AS rank_total_country_account_cnt,
     dense_rank()
       OVER (ORDER BY total_country_sent_cnt DESC)
       AS rank_total_country_sent_cnt
   FROM with_totals
 )
SELECT
 -- виводимо всі данні, та фільтруємо по топ 10 країнах , з двух CTE grouped, with_ranks, тому що ми рахували total тільки по country
 g.*,
 wr.total_country_account_cnt,
 wr.total_country_sent_cnt,
 wr.rank_total_country_account_cnt,
 wr.rank_total_country_sent_cnt
FROM grouped g
JOIN with_ranks wr
 ON g.country = wr.country
WHERE
 wr.rank_total_country_account_cnt <= 10
 OR wr.rank_total_country_sent_cnt <= 10
ORDER BY country, date
