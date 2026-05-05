WITH GenZ_Events AS (
    SELECT 
        u.country,
        a.ad_type,
        e.event_type
    FROM ad_events e
    JOIN ads a ON e.ad_id = a.ad_id
    JOIN users u ON e.user_id = u.user_id
    WHERE u.age_group = '18-24'
),

Metrics_Per_Country AS (
    -- total Impression, Click dan Purchase per Negara dan Format Iklan
    SELECT 
        country,
        ad_type,
        COUNT(CASE WHEN event_type = 'Impression' THEN 1 END) AS total_impressions,
        COUNT(CASE WHEN event_type = 'Click' THEN 1 END) AS total_clicks,
        COUNT(CASE WHEN event_type = 'Purchase' THEN 1 END) AS total_purchases
    FROM GenZ_Events
    GROUP BY country, ad_type
),

Ranked_Ad_Types AS (
    -- Hitung Conversion Rate dan buat ranking berdasarkan jumlah Purchase terbanyak
    SELECT 
        country,
        ad_type,
        total_impressions,
        total_clicks,
        total_purchases,
        -- Mencegah error pembagian dengan nol pakai NULLIF
        ROUND((total_purchases::numeric / NULLIF(total_clicks, 0)) * 100, 2) AS conversion_rate_pct,
        ROW_NUMBER() OVER(PARTITION BY country ORDER BY total_purchases DESC) AS rank
    FROM Metrics_Per_Country
)

-- Menampilkan hanya format iklan TERBAIK di setiap negara
SELECT 
    country,
    ad_type AS top_performing_ad_format,
    total_impressions,
    total_clicks,
    total_purchases,
    conversion_rate_pct
FROM Ranked_Ad_Types
WHERE rank = 1
ORDER BY total_purchases DESC;

-- 2. ANALISIS TREN WAKTU AKTIF 
SELECT 
    day_of_week,
    time_of_day,
    COUNT(CASE WHEN event_type = 'Impression' THEN 1 END) AS total_impressions,
    COUNT(CASE WHEN event_type = 'Click' THEN 1 END) AS total_clicks,
    COUNT(CASE WHEN event_type = 'Purchase' THEN 1 END) AS total_purchases,
    ROUND((COUNT(CASE WHEN event_type = 'Purchase' THEN 1 END)::numeric / 
           NULLIF(COUNT(CASE WHEN event_type = 'Click' THEN 1 END), 0)) * 100, 2) AS conversion_rate_pct
FROM ad_events
GROUP BY day_of_week, time_of_day
ORDER BY 
    CASE day_of_week
        WHEN 'Monday' THEN 1 WHEN 'Tuesday' THEN 2 WHEN 'Wednesday' THEN 3
        WHEN 'Thursday' THEN 4 WHEN 'Friday' THEN 5 WHEN 'Saturday' THEN 6 WHEN 'Sunday' THEN 7
    END,
    CASE time_of_day
        WHEN 'Morning' THEN 1 WHEN 'Afternoon' THEN 2 WHEN 'Evening' THEN 3 WHEN 'Night' THEN 4
    END;

-- 3. ANALISIS EFISIENSI KAMPANYE
WITH Campaign_Performance AS (
    SELECT 
        c.campaign_id,
        c.name AS campaign_name,
        c.total_budget,
        COUNT(CASE WHEN e.event_type = 'Impression' THEN 1 END) AS total_impressions,
        COUNT(CASE WHEN e.event_type = 'Click' THEN 1 END) AS total_clicks,
        COUNT(CASE WHEN e.event_type = 'Purchase' THEN 1 END) AS total_purchases
    FROM campaigns c
    LEFT JOIN ads a ON c.campaign_id = a.campaign_id
    LEFT JOIN ad_events e ON a.ad_id = e.ad_id
    GROUP BY c.campaign_id, c.name, c.total_budget
)

SELECT 
    campaign_name,
    total_budget,
    total_impressions,
    total_clicks,
    total_purchases,
    ROUND(total_budget::numeric / NULLIF(total_purchases, 0), 2) AS cost_per_acquisition_usd,
    ROUND((total_purchases::numeric / NULLIF(total_clicks, 0)) * 100, 2) AS conversion_rate_pct
FROM Campaign_Performance
ORDER BY total_purchases DESC;

-- 4. Untuk SCORECARD nanti
SELECT 
    COUNT(CASE WHEN event_type = 'Impression' THEN 1 END) AS total_impressions,
    COUNT(CASE WHEN event_type = 'Click' THEN 1 END) AS total_clicks,
    COUNT(CASE WHEN event_type = 'Purchase' THEN 1 END) AS total_purchases,
    ROUND((COUNT(CASE WHEN event_type = 'Click' THEN 1 END)::numeric / 
           NULLIF(COUNT(CASE WHEN event_type = 'Impression' THEN 1 END), 0)) * 100, 2) AS avg_ctr_pct,
    ROUND((COUNT(CASE WHEN event_type = 'Purchase' THEN 1 END)::numeric / 
           NULLIF(COUNT(CASE WHEN event_type = 'Click' THEN 1 END), 0)) * 100, 2) AS avg_conversion_rate_pct
FROM ad_events;	

-- 5. ANALISIS PERMASALAHN KLIK LINK / LANDING PAGE
WITH Funnel_Data AS (
    SELECT 
        event_type,
        COUNT(event_id) AS total_events
    FROM ad_events
    WHERE event_type IN ('Impression', 'Click', 'Purchase')
    GROUP BY event_type
)
SELECT '1. Impression' AS event_step, total_events FROM Funnel_Data WHERE event_type = 'Impression'
UNION ALL
SELECT '2. Click' AS event_step, total_events FROM Funnel_Data WHERE event_type = 'Click'
UNION ALL
SELECT '3. Purchase' AS event_step, total_events FROM Funnel_Data WHERE event_type = 'Purchase'
ORDER BY event_step ASC;

-- 6. PEMBELIAN PALING BANYAK
SELECT 
    u.country,
    u.age_group,
    u.user_gender,
    a.ad_platform,
    a.ad_type,
    COUNT(e.event_id) AS total_purchases
FROM ad_events e
JOIN users u ON e.user_id = u.user_id
JOIN ads a ON e.ad_id = a.ad_id
WHERE e.event_type = 'Purchase'
GROUP BY 
    u.country, 
    u.age_group, 
    u.user_gender, 
    a.ad_platform, 
    a.ad_type
ORDER BY total_purchases DESC;

-- 7. ANALISIS AD FATIGUE
SELECT 
    CAST(e.timestamp AS DATE) AS event_date,
    a.ad_type,
    COUNT(CASE WHEN e.event_type = 'Impression' THEN 1 END) AS daily_impressions,
    COUNT(CASE WHEN e.event_type = 'Click' THEN 1 END) AS daily_clicks,
    COUNT(CASE WHEN e.event_type = 'Purchase' THEN 1 END) AS daily_purchases
FROM ad_events e
JOIN ads a ON e.ad_id = a.ad_id
GROUP BY CAST(e.timestamp AS DATE), a.ad_type
ORDER BY event_date ASC;