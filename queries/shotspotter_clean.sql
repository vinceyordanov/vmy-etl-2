---------------------------------------------- ## Pre operations ## ----------------------------------------------

-- Set batch date window by taking the difference between previous most recent date from chicago homicide data
-- and the current most recent date from chicago homicide data -- 

DECLARE start_date DATE;
DECLARE end_date DATE;


--  If the run_log table is empty, assume this is the first iteration and set it to earliest shotspotter date 

IF (SELECT COUNT(1) FROM `r-server-326920.chicago_raw.run_log`) = 0 THEN SET start_date = "2017-01-13";
ELSE SET start_date = (SELECT MAX(last_cutoff) FROM `r-server-326920.chicago_raw.run_log`);
END IF;

SET end_date = (SELECT MAX(DATE(date)) FROM `bigquery-public-data.chicago_crime.crime`);


-- Update the run log table so next run can select only recent data

INSERT INTO chicago_raw.run_log(last_run, last_cutoff) 
VALUES(CURRENT_DATE(), end_date);


-- Create temporary table containing homicide data to be used to join with shotspotter data 

CREATE TEMP TABLE chicago_crime AS (
  SELECT 
    DATE(date) AS date,
    CASE WHEN primary_type = "HOMICIDE" THEN EXTRACT(hour FROM date) ELSE NULL END AS event_hour,
    CASE WHEN primary_type = "HOMICIDE" THEN LTRIM(SUBSTR(block,6)) ELSE NULL END AS block,
    CASE WHEN primary_type = "HOMICIDE" THEN district ELSE NULL END AS district,
    CASE WHEN primary_type = "HOMICIDE" THEN ward ELSE NULL END AS ward,
    SUM(CASE WHEN primary_type = "HOMICIDE" THEN 1 ELSE 0 END) AS homicides
  FROM 
    `bigquery-public-data.chicago_crime.crime`
  WHERE 
    DATE(date) >= start_date
  GROUP BY 
    1,2,3,4,5
);


---------------------------------------------- ## Main query ## ----------------------------------------------

MERGE `r-server-326920.chicago_raw.shotspotter_clean` T 
USING (
  WITH main AS (
    SELECT 
      unique_id AS event_id,
      timestamp AS event_time,
      event_date,
      EXTRACT(year FROM event_date) AS event_year,
      month AS event_month,
      EXTRACT(day FROM event_date) AS event_day_of_month,
      day_of_week AS event_day_of_week,
      CASE WHEN day_of_week IN (1,2,3,4,5) THEN "weekday" ELSE "weekend" END AS day_type,
      hour AS hour_of_day,
      CASE 
        WHEN hour IN (4,5,6,7) THEN "early morning" 
        WHEN hour IN (8,9,19,11) THEN "morning"
        WHEN hour IN (12,13,14,15) THEN "afternoon"
        WHEN hour IN (16,17,18,19) THEN "late afternoon"
        WHEN hour IN (20,21,22,23) THEN "evening"
        ELSE "late night"
      END AS hour_category, 
      incident_type_description AS event_type,
      rounds AS rounds_fired,
      community_area AS neighbourhood,
      area,
      block,
      SUBSTR(block, 6) AS block_name,
      ward,
      district,
      illinois_house_district,
      illinois_senate_district,
      zip_code,
      latitude,
      longitude,
      ST_GEOGPOINT(longitude, latitude) AS location
    FROM `r-server-326920.chicago_raw.shotspotter`
    WHERE event_date BETWEEN start_date AND end_date
  ),


  -- Left join filtered shotspotter data with temporary table from pre_operations

  GROSS AS (
      SELECT 
          event_id,
          event_time,
          event_date,
          event_year,
          event_month,
          event_day_of_month,
          event_day_of_week,
          day_type,
          hour_of_day,
          m.hour_category AS hour_category,
          event_type,
          rounds_fired,
          neighbourhood,
          CASE WHEN t.block IS NULL THEN m.block ELSE t.block END AS block,
          m.block_name,
          m.ward AS ward,
          m.district AS district,
          illinois_house_district,
          illinois_senate_district,
          zip_code,
          latitude,
          longitude,
          CASE WHEN MIN(t.homicides) IS NULL THEN 0 ELSE MAX(t.homicides) END AS homicides,
      FROM main m
      LEFT JOIN chicago_crime t
      ON m.event_date = t.date
      AND m.block_name = t.block 
      AND m.district = t.district
      AND m.ward = t.ward
      GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22
  ),


  -- Remove any duplicates that pass through when data is collected by R script 

  DEDUPLICATED_DATA AS (
      SELECT 
        k.*
      FROM (
        SELECT ARRAY_AGG(original_data LIMIT 1)[OFFSET(0)] k 
        FROM GROSS AS original_data
        GROUP BY event_id
      )
  )


  --- Final selection, excluding unnecessary field ---

  SELECT 
      * EXCEPT (block_name),
      CASE WHEN homicides > 0 THEN TRUE ELSE FALSE END AS is_homicide
  FROM 
      DEDUPLICATED_DATA 
  GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22

) S 
ON T.event_id = S.event_id
AND T.event_date BETWEEN start_date AND end_date
WHEN MATCHED THEN 
  UPDATE 
    SET 
      `event_id` = S.event_id,
      `event_time` = S.event_time,
      `event_date` = S.event_date,
      `event_year` = S.event_year,
      `event_month` = S.event_month,
      `event_day_of_month` = S.event_day_of_month,
      `event_day_of_week` = S.event_day_of_week,
      `day_type` = S.day_type,
      `hour_of_day` = S.hour_of_day,
      `hour_category` = S.hour_category,
      `event_type` = S.event_type,
      `rounds_fired` = S.rounds_fired,
      `neighbourhood` = S.neighbourhood,
      `block` = S.block,
      `ward` = S.ward,
      `district` = S.district,
      `illinois_house_district` = S.illinois_house_district,
      `illinois_senate_district` = S.illinois_senate_district,
      `zip_code` = S.zip_code,
      `latitude` = S.latitude,
      `longitude` = S.longitude,
      `homicides` = S.homicides,
      `is_homicide` = S.is_homicide
WHEN NOT MATCHED THEN 
  INSERT (
    `event_id`,
    `event_time`,
    `event_date`,
    `event_year`,
    `event_month`,
    `event_day_of_month`,
    `event_day_of_week`,
    `day_type`,
    `hour_of_day`,
    `hour_category`,
    `event_type`,
    `rounds_fired`,
    `neighbourhood`,
    `block`,
    `ward`,
    `district`,
    `illinois_house_district`,
    `illinois_senate_district`,
    `zip_code`,
    `latitude`,
    `longitude`,
    `homicides`,
    `is_homicide`
  )
  VALUES (T.event_id,T.event_time,T.event_date,T.event_year,T.event_month,T.event_day_of_month,T.event_day_of_week,T.day_type,T.hour_of_day,T.hour_category,T.event_type,T.rounds_fired,T.neighbourhood,T.block,T.ward,T.district,T.illinois_house_district,T.illinois_senate_district,T.zip_code,T.latitude,T.longitude,T.homicides,T.is_homicide)
;



