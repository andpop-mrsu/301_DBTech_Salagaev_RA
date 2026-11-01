#!/bin/bash
chcp 65001

sqlite3 movies_rating.db < db_init.sql

echo "1. Пары пользователей, оценивших один и тот же фильм"
echo --------------------------------------------------
sqlite3 movies_rating.db -box -echo "SELECT u1.first_name || ' ' || u1.last_name AS user1, u2.first_name || ' ' || u2.last_name AS user2, m.title FROM ratings r1 JOIN ratings r2 ON r1.movie_id = r2.movie_id AND r1.user_id < r2.user_id JOIN users u1 ON r1.user_id = u1.id JOIN users u2 ON r2.user_id = u2.id JOIN movies m ON r1.movie_id = m.id LIMIT 100;"
echo " "

echo "2. 10 самых старых оценок"
echo --------------------------------------------------
sqlite3 movies_rating.db -box -echo "SELECT m.title, u.first_name || ' ' || u.last_name AS user_name, r.rating, DATE(r.timestamp, 'unixepoch') AS rating_date FROM ratings r JOIN users u ON r.user_id = u.id JOIN movies m ON r.movie_id = m.id ORDER BY r.timestamp ASC LIMIT 10;"
echo " "

echo "3. Фильмы с максимальным и минимальным средним рейтингом"
echo --------------------------------------------------
sqlite3 movies_rating.db -box -echo "WITH movie_avg AS (SELECT movie_id, AVG(rating) AS avg_score FROM ratings GROUP BY movie_id) SELECT m.title, m.year, ma.avg_score, CASE WHEN ma.avg_score = (SELECT MAX(avg_score) FROM movie_avg) THEN 'Да' ELSE 'Нет' END AS 'Рекомендуем' FROM movie_avg ma JOIN movies m ON ma.movie_id = m.id WHERE ma.avg_score = (SELECT MAX(avg_score) FROM movie_avg) OR ma.avg_score = (SELECT MIN(avg_score) FROM movie_avg) ORDER BY m.year, m.title;"
echo " "

echo "4. Оценки мужчин за 2011-2014 гг."
echo --------------------------------------------------
sqlite3 movies_rating.db -box -echo "SELECT COUNT(*) AS total_ratings, ROUND(AVG(r.rating), 2) AS avg_rating FROM ratings r JOIN users u ON r.user_id = u.id WHERE u.gender = 'M' AND STRFTIME('%Y', r.timestamp, 'unixepoch') BETWEEN '2011' AND '2014';"
echo " "

echo "5. Фильмы со средней оценкой и количеством пользователей"
echo --------------------------------------------------
sqlite3 movies_rating.db -box -echo "SELECT m.title, m.year, ROUND(AVG(r.rating), 2) AS avg_rating, COUNT(DISTINCT r.user_id) AS user_count FROM movies m JOIN ratings r ON m.id = r.movie_id GROUP BY m.id ORDER BY m.year, m.title LIMIT 20;"
echo " "

echo "6. Самый распространенный жанр"
echo --------------------------------------------------
sqlite3 movies_rating.db -box -echo "WITH RECURSIVE split_genres(genre, rest) AS (SELECT NULL, genres || '|' FROM movies UNION ALL SELECT SUBSTR(rest, 1, INSTR(rest, '|') - 1), SUBSTR(rest, INSTR(rest, '|') + 1) FROM split_genres WHERE rest != '') SELECT genre, COUNT(*) AS movie_count FROM split_genres WHERE genre IS NOT NULL AND genre != '' GROUP BY genre ORDER BY movie_count DESC LIMIT 1;"
echo " "

echo "7. 10 последних зарегистрированных пользователей"
echo --------------------------------------------------
sqlite3 movies_rating.db -box -echo "SELECT u.last_name || ' ' || u.first_name || '|' || DATE(u.registration_date) AS 'Пользователь' FROM users u ORDER BY u.registration_date DESC LIMIT 10;"
echo " "

echo "8. Дни недели дня рождения по годам"
echo --------------------------------------------------
sqlite3 movies_rating.db -box -echo "WITH RECURSIVE birthday_years(b_year, b_date) AS (SELECT 2000, '2000-04-15' UNION ALL SELECT b_year + 1, DATE(b_date, '+1 year') FROM birthday_years WHERE b_year < 2026) SELECT b_year AS 'Год', b_date AS 'Дата', CASE STRFTIME('%w', b_date) WHEN '0' THEN 'Воскресенье' WHEN '1' THEN 'Понедельник' WHEN '2' THEN 'Вторник' WHEN '3' THEN 'Среда' WHEN '4' THEN 'Четверг' WHEN '5' THEN 'Пятница' WHEN '6' THEN 'Суббота' END AS 'День недели' FROM birthday_years;"