#!/bin/bash
chcp 65001

sqlite3 movies_rating.db < db_init.sql

echo "1. Топ-10 фильмов по среднему рейтингу"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "SELECT title, year, AVG(r.rating) AS avg_rating, RANK() OVER (ORDER BY AVG(r.rating) DESC) AS rank_by_avg_rating FROM movies m JOIN ratings r ON m.id = r.movie_id GROUP BY m.id ORDER BY rank_by_avg_rating ASC LIMIT 10;"
echo " "

echo "2. Средний рейтинг по жанрам (рекурсивное CTE)"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "WITH RECURSIVE split_genres(movie_id, genre, rest) AS (SELECT id, TRIM(SUBSTR(genres, 1, CASE WHEN INSTR(genres, ',') = 0 THEN LENGTH(genres) ELSE INSTR(genres, ',') - 1 END)), CASE WHEN INSTR(genres, ',') = 0 THEN '' ELSE SUBSTR(genres, INSTR(genres, ',') + 1) END FROM movies WHERE genres IS NOT NULL AND genres != '' UNION ALL SELECT movie_id, TRIM(SUBSTR(rest, 1, CASE WHEN INSTR(rest, ',') = 0 THEN LENGTH(rest) ELSE INSTR(rest, ',') - 1 END)), CASE WHEN INSTR(rest, ',') = 0 THEN '' ELSE SUBSTR(rest, INSTR(rest, ',') + 1) END FROM split_genres WHERE rest != '') SELECT genre, ROUND(AVG(r.rating), 2) AS avg_rating, RANK() OVER (ORDER BY AVG(r.rating) DESC) AS rank FROM split_genres sg JOIN ratings r ON sg.movie_id = r.movie_id GROUP BY genre ORDER BY avg_rating DESC;"
echo " "

echo "3. Количество фильмов в каждом жанре"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "WITH RECURSIVE split_genres(movie_id, genre, rest) AS (SELECT id, TRIM(SUBSTR(genres, 1, CASE WHEN INSTR(genres, ',') = 0 THEN LENGTH(genres) ELSE INSTR(genres, ',') - 1 END)), CASE WHEN INSTR(genres, ',') = 0 THEN '' ELSE SUBSTR(genres, INSTR(genres, ',') + 1) END FROM movies WHERE genres IS NOT NULL AND genres != '' UNION ALL SELECT movie_id, TRIM(SUBSTR(rest, 1, CASE WHEN INSTR(rest, ',') = 0 THEN LENGTH(rest) ELSE INSTR(rest, ',') - 1 END)), CASE WHEN INSTR(rest, ',') = 0 THEN '' ELSE SUBSTR(rest, INSTR(rest, ',') + 1) END FROM split_genres WHERE rest != '') SELECT genre, COUNT(DISTINCT movie_id) AS movie_count FROM split_genres GROUP BY genre ORDER BY movie_count DESC;"
echo " "

echo "4. Жанры по частоте оставления тегов и их доля"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "WITH RECURSIVE split_genres(movie_id, genre, rest) AS (SELECT id, TRIM(SUBSTR(genres, 1, CASE WHEN INSTR(genres, ',') = 0 THEN LENGTH(genres) ELSE INSTR(genres, ',') - 1 END)), CASE WHEN INSTR(genres, ',') = 0 THEN '' ELSE SUBSTR(genres, INSTR(genres, ',') + 1) END FROM movies WHERE genres IS NOT NULL AND genres != '' UNION ALL SELECT movie_id, TRIM(SUBSTR(rest, 1, CASE WHEN INSTR(rest, ',') = 0 THEN LENGTH(rest) ELSE INSTR(rest, ',') - 1 END)), CASE WHEN INSTR(rest, ',') = 0 THEN '' ELSE SUBSTR(rest, INSTR(rest, ',') + 1) END FROM split_genres WHERE rest != ''), genre_tags AS (SELECT sg.genre, COUNT(t.id) AS tag_count FROM split_genres sg JOIN tags t ON sg.movie_id = t.movie_id GROUP BY sg.genre), total_tags AS (SELECT COUNT(*) AS total FROM tags) SELECT gt.genre, gt.tag_count, ROUND(CAST(gt.tag_count AS REAL) * 100 / tt.total, 2) AS tag_share FROM genre_tags gt, total_tags tt ORDER BY gt.tag_count DESC;"
echo " "

echo "5. Статистика оценок по пользователям"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "SELECT user_id, COUNT(rating) AS rating_count, ROUND(AVG(rating), 2) AS avg_rating, MIN(timestamp) AS first_rating_date, MAX(timestamp) AS last_rating_date FROM ratings GROUP BY user_id ORDER BY rating_count DESC LIMIT 10;"
echo " "

echo "6. Сегментация пользователей по типам поведения"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "WITH user_stats AS (SELECT u.id AS user_id, COALESCE(r_cnt.cnt, 0) AS rating_count, COALESCE(t_cnt.cnt, 0) AS tag_count FROM users u LEFT JOIN (SELECT user_id, COUNT(*) AS cnt FROM ratings GROUP BY user_id) r_cnt ON u.id = r_cnt.user_id LEFT JOIN (SELECT user_id, COUNT(*) AS cnt FROM tags GROUP BY user_id) t_cnt ON u.id = t_cnt.user_id) SELECT user_id, rating_count, tag_count, CASE WHEN tag_count > rating_count THEN 'Комментаторы' WHEN rating_count > tag_count THEN 'Оценщики' WHEN rating_count >= 10 AND tag_count >= 10 THEN 'Активные' WHEN rating_count < 5 AND tag_count < 5 THEN 'Пассивные' ELSE 'Прочие' END AS behavior_category FROM user_stats;"
echo " "

echo "7. Последний оцененный фильм каждого пользователя"
echo "--------------------------------------------------"
sqlite3 movies_rating.db -box -echo "WITH ranked_ratings AS (SELECT r.user_id, r.movie_id, r.timestamp, ROW_NUMBER() OVER(PARTITION BY r.user_id ORDER BY r.timestamp DESC) AS rn FROM ratings r) SELECT u.id AS user_id, u.name, m.title AS last_rated_movie_title, rr.timestamp AS last_rating_timestamp FROM users u LEFT JOIN ranked_ratings rr ON u.id = rr.user_id AND rr.rn = 1 LEFT JOIN movies m ON rr.movie_id = m.id;"