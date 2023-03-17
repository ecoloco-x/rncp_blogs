# This script consists of two parts, first part used to construct the data base, second part to generate insights


###################################################################
###################### DATABASE CONSTRUCTION ######################
###################################################################

CREATE DATABASE authorblog;
USE authorblog;

# create an empty table to load cleaned data 
CREATE TABLE IF NOT EXISTS blog_authorship_raw (
author_id INT NOT NULL,
gender VARCHAR(255) NOT NULL,
age INT NOT NULL,
occupation VARCHAR(255) NOT NULL,
sign VARCHAR(255) NOT NULL,
blog_id VARCHAR(255),
date DATE,
text MEDIUMTEXT,
word_count INT NOT NULL
);

SHOW VARIABLES LIKE "secure_file_priv";

# load data into table
LOAD DATA INFILE "C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/blog_author_clean.csv"
INTO TABLE blog_authorship_raw 
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


# create author table containing all author infomation
DROP TABLE IF EXISTS authors;
CREATE TABLE IF NOT EXISTS authors
SELECT DISTINCT author_id,
	   gender,
       age,
       occupation,
       sign
FROM blog_authorship_raw ;


# create blog table containing all blog infomation
DROP TABLE IF EXISTS blogs;
CREATE TABLE IF NOT EXISTS blogs
SELECT blog_id ,
	   text,
	   author_id,
	   date,
	   word_count
FROM blog_authorship_raw ;


# create author_blog table with aggregated information about each author
DROP TABLE IF EXISTS blogs_per_au;
CREATE TABLE IF NOT EXISTS blogs_per_au
SELECT author_id,
	   COUNT(blog_id) AS nb_posts,
       SUM(word_count) AS nb_words,
       MIN(date) AS start_at,
       MAX(date) AS last_at,
	   ROUND((SUM(word_count)/ COUNT(blog_id)),4) AS avg_len,
	   MAX(word_count) AS longest_blog,
	   MIN(word_count) AS shortest_blog
FROM blog_authorship_raw
GROUP BY author_id;


# create a calendar table for further analysis
# first check the time span we need
-- SELECT MIN(date), MAX(date) FROM blog_authorship_raw;


DROP TABLE IF EXISTS dates;
CREATE TABLE dates (
idDate INTEGER NOT NULL, -- year10000+month100+day
fulldate DATE PRIMARY KEY,
year INTEGER NOT NULL,
month INTEGER NOT NULL, -- 1 to 12
day INTEGER NOT NULL, -- 1 to 31
quarter INTEGER NOT NULL, -- 1 to 4
week INTEGER NOT NULL, -- 1 to 52/53
dayOfWeek INTEGER NOT NULL, -- 1 to 7
weekend INTEGER NOT NULL,
UNIQUE td_ymd_idx (year,month,day),
UNIQUE td_dbdate_idx (fulldate)

) Engine=innoDB;

DROP PROCEDURE IF EXISTS fill_date_dimension;
DELIMITER //
CREATE PROCEDURE fill_date_dimension(IN startdate DATE,IN stopdate DATE)
BEGIN
DECLARE currentdate DATE;
SET currentdate = startdate;
WHILE currentdate < stopdate DO
INSERT INTO dates VALUES (
YEAR(currentdate)*10000+MONTH(currentdate)*100 + DAY(currentdate),
currentdate,
YEAR(currentdate),
MONTH(currentdate),
DAY(currentdate),
QUARTER(currentdate),
WEEKOFYEAR(currentdate),

CASE DAYOFWEEK(currentdate)-1 WHEN 0 THEN 7 ELSE DAYOFWEEK(currentdate)-1 END ,
CASE DAYOFWEEK(currentdate)-1 WHEN 0 THEN 1 WHEN 6 then 1 ELSE 0 END);
SET currentdate = ADDDATE(currentdate,INTERVAL 1 DAY);
END WHILE;
END
//
DELIMITER ;

TRUNCATE TABLE dates;

CALL fill_date_dimension('1999-01-01','2005-01-01');
OPTIMIZE TABLE dates;

# add foreign key constraints
ALTER TABLE blogs ADD CONSTRAINT fk_constraint_name FOREIGN KEY (author_id) REFERENCES authors (author_id);
ALTER TABLE authors ADD INDEX au_ind (author_id);
ALTER TABLE blogs ADD CONSTRAINT fk_constraint_date FOREIGN KEY (date) REFERENCES dates (fulldate);

###################################################################
#################### DATABASE CONSTRUCTION END ####################
###################################################################




###################################################################
########################## DATA ANALYSIS ##########################
###################################################################

# 1 Average number of blogs and blog length by zodiac sign
WITH authors AS (
SELECT author_id, sign FROM authors),
blog_au AS (
SELECT author_id, nb_posts, nb_words, avg_len
FROM blogs_per_au)
SELECT sign,
COUNT(bau.author_id) AS nb_bloggers,
SUM(nb_posts) AS total_posts, 
(SUM(nb_posts) / COUNT(bau.author_id)) AS avg_posts, 
AVG(avg_len) AS avg_words
FROM blog_au bau
LEFT JOIN authors a
	ON bau.author_id = a.author_id
GROUP BY sign
ORDER BY total_posts;



# 2 Gender difference in posting

WITH authors AS (
SELECT author_id, gender FROM authors),
blog_au AS (
SELECT author_id, nb_posts, nb_words, avg_len
FROM blogs_per_au)
SELECT gender,
COUNT(bau.author_id) AS nb_bloggers,
SUM(nb_posts) AS total_posts, 
(SUM(nb_posts) / COUNT(bau.author_id)) AS avg_posts, 
AVG(avg_len) AS avg_words
FROM blog_au bau
LEFT JOIN authors a
	ON bau.author_id = a.author_id
GROUP BY gender
ORDER BY total_posts;


# 3 Blog posts across the year

WITH blogs AS (
SELECT blog_id, date, word_count
FROM blogs)
SELECT month,
COUNT(blog_id) AS blog_posted,
SUM(word_count) AS words_posted,
SUM(word_count)/COUNT(blog_id) AS blog_len
FROM dates
LEFT JOIN blogs
	ON dates.fulldate = blogs.date
GROUP BY 1
ORDER BY 1;



# 4 Blog posts across the week 1/

WITH blogs AS (
SELECT blog_id, date, word_count
FROM blogs)
SELECT dayOfWeek,
COUNT(blog_id) AS blog_posted,
SUM(word_count) AS words_posted,
SUM(word_count)/COUNT(blog_id) AS blog_len
FROM dates
LEFT JOIN blogs
	ON dates.fulldate = blogs.date
GROUP BY 1
ORDER BY 1;

# 5 Blog posts across the 2/

WITH blogs AS (
SELECT blog_id, date, word_count
FROM blogs)
SELECT weekend,
COUNT(blog_id) AS blog_posted,
CASE WHEN weekend = 0 THEN COUNT(blog_id) / 5 ELSE COUNT(blog_id) /2 END AS daily_blog_posted,
SUM(word_count)/COUNT(blog_id) AS blog_len
FROM dates
LEFT JOIN blogs
	ON dates.fulldate = blogs.date
GROUP BY 1
ORDER BY 1;

###################################################################
####################### DATA ANALYSIS END #########################
###################################################################
