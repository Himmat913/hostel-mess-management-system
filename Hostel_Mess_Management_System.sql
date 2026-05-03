/* =========================================================
   HOSTEL MESS MANAGEMENT SYSTEM
   ========================================================= */

/* =========================================================
   SEQUENCES
   ========================================================= */
CREATE SEQUENCE seq_swap_id START WITH 1 INCREMENT BY 1;
/
CREATE SEQUENCE seq_menu_id START WITH 1 INCREMENT BY 1;
/
CREATE SEQUENCE seq_scan_id START WITH 1 INCREMENT BY 1;
/
CREATE SEQUENCE seq_rating_id START WITH 1 INCREMENT BY 1;
/
CREATE SEQUENCE seq_waste_id START WITH 1 INCREMENT BY 1;
/
CREATE SEQUENCE seq_leave_id START WITH 1 INCREMENT BY 1;
/

/* =========================================================
   USERS
   ========================================================= */
CREATE TABLE users(
    user_id NUMBER PRIMARY KEY,
    name VARCHAR2(100) NOT NULL,
    role VARCHAR2(20) NOT NULL,
    CONSTRAINT chk_user_role
    CHECK(role IN ('student','admin','staff'))
);

/* =========================================================
   MEALS 
   ========================================================= */
CREATE TABLE meals(
    meal_id NUMBER PRIMARY KEY,
    meal_name VARCHAR2(100) NOT NULL UNIQUE,
    meal_type VARCHAR2(20) NOT NULL,
    CONSTRAINT chk_meal_type
    CHECK(meal_type IN ('breakfast','lunch','dinner'))
);

/* =========================================================
   MENU 
   ========================================================= */
CREATE TABLE menu(
    menu_id NUMBER PRIMARY KEY,
    serve_date DATE NOT NULL,
    meal_id NUMBER NOT NULL,
    generated_on DATE NOT NULL,

    CONSTRAINT fk_menu_meal
    FOREIGN KEY(meal_id)
    REFERENCES meals(meal_id),

    CONSTRAINT uq_menu_day
    UNIQUE(serve_date, meal_id)
);

/* =========================================================
   SCANS
   ========================================================= */
CREATE TABLE scans(
    scan_id NUMBER PRIMARY KEY,
    user_id NUMBER NOT NULL,
    menu_id NUMBER NOT NULL,
    scan_time TIMESTAMP NOT NULL,

    CONSTRAINT fk_scan_user
    FOREIGN KEY(user_id)
    REFERENCES users(user_id),

    CONSTRAINT fk_scan_menu
    FOREIGN KEY(menu_id)
    REFERENCES menu(menu_id),

    CONSTRAINT uq_single_scan
    UNIQUE(user_id, menu_id)
);

/* =========================================================
   LEAVE APPLICATION
   ========================================================= */
CREATE TABLE leave_application(
    leave_id NUMBER PRIMARY KEY,
    user_id NUMBER NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    applied_on TIMESTAMP NOT NULL,
    status VARCHAR2(20) DEFAULT 'pending',

    CONSTRAINT fk_leave_user
    FOREIGN KEY(user_id)
    REFERENCES users(user_id),

    CONSTRAINT chk_leave_status
    CHECK(status IN ('pending','approved','rejected')),

    CONSTRAINT chk_leave_dates
    CHECK(end_date >= start_date)
);

/* =========================================================
   RATINGS 
   ========================================================= */
CREATE TABLE ratings(
    rating_id NUMBER PRIMARY KEY,
    user_id NUMBER NOT NULL,
    menu_id NUMBER NOT NULL,
    rating NUMBER(2) NOT NULL,

    CONSTRAINT fk_rating_user
    FOREIGN KEY(user_id)
    REFERENCES users(user_id),

    CONSTRAINT fk_rating_menu
    FOREIGN KEY(menu_id)
    REFERENCES menu(menu_id),

    CONSTRAINT chk_rating
    CHECK(rating BETWEEN 1 AND 5),

    CONSTRAINT uq_rating
    UNIQUE(user_id, menu_id)
);

/* =========================================================
   WASTE LOG 
   ========================================================= */
CREATE TABLE waste_log(
    waste_id NUMBER PRIMARY KEY,
    menu_id NUMBER NOT NULL,
    quantity_kg NUMBER(6,2) NOT NULL,
    logged_time TIMESTAMP NOT NULL,

    CONSTRAINT fk_waste_menu
    FOREIGN KEY(menu_id)
    REFERENCES menu(menu_id),

    CONSTRAINT chk_waste
    CHECK(quantity_kg >= 0)
);

/* =========================================================
   MEAL ANALYTICS 
   ========================================================= */
CREATE TABLE meal_analytics(
    menu_id NUMBER PRIMARY KEY,
    avg_rating NUMBER(3,2),
    total_waste NUMBER(6,2),
    attendance_count NUMBER,
    bad_score NUMBER(6,2),
    swap_required NUMBER(1),

    CONSTRAINT fk_analytics_menu
    FOREIGN KEY(menu_id)
    REFERENCES menu(menu_id),

    CONSTRAINT chk_swap_required
    CHECK(swap_required IN (0,1))
);

/* =========================================================
   SWAP HISTORY
   ========================================================= */
CREATE TABLE swap_history(
    swap_id NUMBER PRIMARY KEY,
    old_meal_id NUMBER NOT NULL,
    new_meal_id NUMBER NOT NULL,
    swap_reason VARCHAR2(300),
    bad_score NUMBER(6,2),
    swap_time TIMESTAMP NOT NULL,
    effective_week NUMBER NOT NULL,

    CONSTRAINT fk_old_meal
    FOREIGN KEY(old_meal_id)
    REFERENCES meals(meal_id),

    CONSTRAINT fk_new_meal
    FOREIGN KEY(new_meal_id)
    REFERENCES meals(meal_id)
);

/* =========================================================
   INDEXES
   ========================================================= */
CREATE INDEX idx_scan_user ON scans(user_id);
/
CREATE INDEX idx_rating_menu ON ratings(menu_id);
/
CREATE INDEX idx_menu_date ON menu(serve_date);
/
CREATE INDEX idx_leave_user ON leave_application(user_id);
/
CREATE INDEX idx_menu_meal ON menu(meal_id);
/
CREATE INDEX idx_scans_menu ON scans(menu_id);
/
CREATE INDEX idx_waste_menu ON waste_log(menu_id);
/

/* =========================================================
   TRIGGER
   BLOCK SCAN IF STUDENT ON APPROVED LEAVE
   ========================================================= */

CREATE OR REPLACE TRIGGER trg_block_leave_scan
BEFORE INSERT ON scans
FOR EACH ROW
DECLARE
    v_count NUMBER;
    v_serve_date DATE;
BEGIN

    SELECT serve_date INTO v_serve_date
    FROM menu
    WHERE menu_id = :NEW.menu_id;

    SELECT COUNT(*)
    INTO v_count
    FROM leave_application
    WHERE user_id = :NEW.user_id
    AND status = 'approved'
    AND TRUNC(v_serve_date)
        BETWEEN TRUNC(start_date)
        AND TRUNC(end_date);

    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(
            -20001,
            'Student on approved leave'
        );
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20050, 'Invalid menu_id');

END;
/

/* =========================================================
   TRIGGER
   VALIDATE SCAN TIMINGS
   ========================================================= */

CREATE OR REPLACE TRIGGER trg_validate_scan_time
BEFORE INSERT ON scans
FOR EACH ROW
DECLARE
    v_hour NUMBER;
    v_meal_type VARCHAR2(20);
BEGIN

    v_hour := TO_NUMBER(TO_CHAR(:NEW.scan_time,'HH24'));

    SELECT m.meal_type
    INTO v_meal_type
    FROM menu mn
    JOIN meals m ON mn.meal_id = m.meal_id
    WHERE mn.menu_id = :NEW.menu_id;

    IF v_meal_type = 'breakfast' THEN

        IF v_hour NOT BETWEEN 7 AND 10 THEN
            RAISE_APPLICATION_ERROR(
                -20002,
                'Breakfast scan only between 7AM-10AM'
            );
        END IF;

    ELSIF v_meal_type = 'lunch' THEN

        IF v_hour NOT BETWEEN 12 AND 15 THEN
            RAISE_APPLICATION_ERROR(
                -20003,
                'Lunch scan only between 12PM-3PM'
            );
        END IF;

    ELSIF v_meal_type = 'dinner' THEN

        IF v_hour NOT BETWEEN 19 AND 22 THEN
            RAISE_APPLICATION_ERROR(
                -20004,
                'Dinner scan only between 7PM-10PM'
            );
        END IF;

    END IF;
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20050, 'Invalid menu_id');

END;
/

/* =========================================================
   TRIGGER
   VALIDATE RATING 
   ========================================================= */

CREATE OR REPLACE TRIGGER trg_validate_rating_scan
BEFORE INSERT ON ratings
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN

    SELECT COUNT(*)
    INTO v_count
    FROM scans
    WHERE user_id = :NEW.user_id
    AND menu_id = :NEW.menu_id;

    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(
            -20010,
            'Cannot rate without consuming that meal'
        );
    END IF;

END;
/

/* =========================================================
   TRIGGER
   DETECT OVER-SERVING
   ========================================================= */

CREATE OR REPLACE TRIGGER trg_detect_overserving
AFTER INSERT OR UPDATE ON meal_analytics
FOR EACH ROW
BEGIN

    IF :NEW.total_waste > 20
    AND :NEW.attendance_count > 80 THEN

        DBMS_OUTPUT.PUT_LINE(
            'Over-serving detected for menu_id ' || :NEW.menu_id
        );

    END IF;

END;
/


/* =========================================================
   PROCEDURE TO MAINTAIN ANALYTICS 
   ========================================================= */

CREATE OR REPLACE PROCEDURE refresh_meal_analytics(p_menu_id NUMBER)
IS
    v_avg_rating NUMBER := 0;
    v_total_waste NUMBER := 0;
    v_attendance NUMBER := 0;
    v_bad_score NUMBER := 0;
BEGIN

    SELECT NVL(AVG(rating),0)
    INTO v_avg_rating
    FROM ratings
    WHERE menu_id = p_menu_id;

    SELECT NVL(SUM(quantity_kg),0)
    INTO v_total_waste
    FROM waste_log
    WHERE menu_id = p_menu_id;

    SELECT COUNT(*)
    INTO v_attendance
    FROM scans
    WHERE menu_id = p_menu_id;

    v_bad_score := ((5 - v_avg_rating) * 2) + (v_total_waste / 2);

    MERGE INTO meal_analytics ma
    USING (SELECT p_menu_id AS menu_id FROM dual) x
    ON (ma.menu_id = x.menu_id)

    WHEN MATCHED THEN
        UPDATE SET
            avg_rating = v_avg_rating,
            total_waste = v_total_waste,
            attendance_count = v_attendance,
            bad_score = v_bad_score,
            swap_required = CASE WHEN v_bad_score >= 5 THEN 1 ELSE 0 END

    WHEN NOT MATCHED THEN
        INSERT VALUES(
            p_menu_id,
            v_avg_rating,
            v_total_waste,
            v_attendance,
            v_bad_score,
            CASE WHEN v_bad_score >= 5 THEN 1 ELSE 0 END
        );

END;
/

/* =========================================================
   PROCEDURE: PERFORM WEEKLY SWAPS 
   ========================================================= */

CREATE OR REPLACE PROCEDURE perform_weekly_swaps(
    p_week_no NUMBER
)
IS

    CURSOR bad_meals IS
    SELECT
        m.meal_id,
        m.meal_type,
        m.meal_name,
        ROUND(AVG(ma.bad_score),2) AS avg_bad_score
    FROM meal_analytics ma
    JOIN menu mn 
        ON ma.menu_id = mn.menu_id
    JOIN meals m 
        ON mn.meal_id = m.meal_id
    WHERE ma.swap_required = 1

    AND mn.serve_date >= (
    SELECT MAX(serve_date) - 7 FROM menu
    )

    AND m.meal_id NOT IN (
        SELECT old_meal_id
        FROM swap_history
        WHERE effective_week = p_week_no
    )

    GROUP BY
        m.meal_id,
        m.meal_type,
        m.meal_name;

    v_new_meal_id NUMBER;
    v_reason VARCHAR2(300);

BEGIN

    FOR rec IN bad_meals LOOP

        BEGIN
            SELECT meal_id
            INTO v_new_meal_id
            FROM (
                SELECT
                    m.meal_id,
                    NVL(AVG(ma.avg_rating),0) avg_rating
                FROM meals m
                LEFT JOIN menu mn ON m.meal_id = mn.meal_id
                LEFT JOIN meal_analytics ma ON mn.menu_id = ma.menu_id
                WHERE m.meal_type = rec.meal_type
                AND m.meal_id != rec.meal_id
                GROUP BY m.meal_id
                ORDER BY avg_rating DESC
            )
            WHERE ROWNUM = 1;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                DBMS_OUTPUT.PUT_LINE('No replacement found for meal ' || rec.meal_id);
                CONTINUE;
        END;

        IF rec.avg_bad_score >= 10 THEN
            v_reason := 'Extremely poor performance';
        ELSIF rec.avg_bad_score >= 7 THEN
            v_reason := 'Low student feedback';
        ELSE
            v_reason := 'Moderate performance issues';
        END IF;

        INSERT INTO swap_history(
            swap_id,
            old_meal_id,
            new_meal_id,
            swap_reason,
            bad_score,
            swap_time,
            effective_week
        )
        VALUES(
            seq_swap_id.NEXTVAL,
            rec.meal_id,
            v_new_meal_id,
            v_reason,
            rec.avg_bad_score,
            SYSTIMESTAMP,
            p_week_no + 1
        );

        DBMS_OUTPUT.PUT_LINE(
            'Swapped meal ' || rec.meal_id ||
            ' with ' || v_new_meal_id
        );

    END LOOP;

END;
/

/* =========================================================
   PROCEDURE: GENERATE WEEKLY MENU 
   ========================================================= */

CREATE OR REPLACE PROCEDURE generate_weekly_menu(
    p_start_date DATE,
    p_days NUMBER
)
IS
    v_current_date DATE;
    v_meal_id NUMBER;
BEGIN

    FOR d IN 0 .. p_days - 1 LOOP

        v_current_date := p_start_date + d;

        FOR meal_type_rec IN (
            SELECT DISTINCT meal_type FROM meals
        )
        LOOP

            BEGIN
                SELECT meal_id
                INTO v_meal_id
                FROM (
                    SELECT meal_id
                    FROM meals
                    WHERE meal_type = meal_type_rec.meal_type
                    ORDER BY DBMS_RANDOM.VALUE
                )
                WHERE ROWNUM = 1;

                INSERT INTO menu(
                    menu_id,
                    serve_date,
                    meal_id,
                    generated_on
                )
                VALUES(
                    seq_menu_id.NEXTVAL,
                    v_current_date,
                    v_meal_id,
                    SYSDATE
                );

            EXCEPTION
                WHEN DUP_VAL_ON_INDEX THEN
                    NULL;
            END;

        END LOOP;

    END LOOP;

END;
/

/* =========================================================
   FUNCTION: GENERATE AVERAGE RATING OF MENU 
   ========================================================= */
   
CREATE OR REPLACE FUNCTION get_menu_avg_rating(p_menu_id NUMBER)
RETURN NUMBER
IS
    v_rating NUMBER;
BEGIN
    SELECT NVL(AVG(rating),0)
    INTO v_rating
    FROM ratings
    WHERE menu_id = p_menu_id;

    RETURN v_rating;
END;
/

/* =========================================================
   INSERT USERS
   ========================================================= */

INSERT ALL

INTO users VALUES(1,'Aman','student')
INTO users VALUES(2,'Riya','student')
INTO users VALUES(3,'Karan','student')
INTO users VALUES(4,'Simran','student')
INTO users VALUES(5,'Rahul','student')
INTO users VALUES(6,'Priya','student')
INTO users VALUES(7,'Arjun','student')
INTO users VALUES(8,'Neha','student')
INTO users VALUES(9,'Vikas','student')
INTO users VALUES(10,'Anjali','student')

INTO users VALUES(11,'Rohit','student')
INTO users VALUES(12,'Sneha','student')
INTO users VALUES(13,'Manish','student')
INTO users VALUES(14,'Pooja','student')
INTO users VALUES(15,'Amit','student')
INTO users VALUES(16,'Kavya','student')
INTO users VALUES(17,'Varun','student')
INTO users VALUES(18,'Nisha','student')
INTO users VALUES(19,'Deepak','student')
INTO users VALUES(20,'Meena','student')

INTO users VALUES(21,'Sahil','student')
INTO users VALUES(22,'Tanya','student')
INTO users VALUES(23,'Yash','student')
INTO users VALUES(24,'Isha','student')
INTO users VALUES(25,'Dev','student')
INTO users VALUES(26,'Ritu','student')
INTO users VALUES(27,'Nikhil','student')
INTO users VALUES(28,'Sonam','student')
INTO users VALUES(29,'Harsh','student')
INTO users VALUES(30,'Komal','student')

INTO users VALUES(31,'Abhishek','student')
INTO users VALUES(32,'Payal','student')
INTO users VALUES(33,'Tarun','student')
INTO users VALUES(34,'Ansh','student')
INTO users VALUES(35,'Himmat','student')
INTO users VALUES(36,'Muskan','student')

INTO users VALUES(37,'MessAdmin','admin')
INTO users VALUES(38,'KitchenStaff1','staff')
INTO users VALUES(39,'KitchenStaff2','staff')
INTO users VALUES(40,'AssistantAdmin','admin')

SELECT * FROM dual;

/* =========================================================
   INSERT MEALS
   ========================================================= */

INSERT ALL

-- BREAKFAST
INTO meals VALUES(1,'Aloo Paratha','breakfast')
INTO meals VALUES(2,'Poha','breakfast')
INTO meals VALUES(3,'Idli Sambhar','breakfast')
INTO meals VALUES(4,'Upma','breakfast')
INTO meals VALUES(5,'Bread Omelette','breakfast')
INTO meals VALUES(6,'Masala Dosa','breakfast')
INTO meals VALUES(7,'Poori Sabzi','breakfast')
INTO meals VALUES(8,'Chole Kulche','breakfast')
INTO meals VALUES(9,'Veg Sandwich','breakfast')

-- LUNCH
INTO meals VALUES(10,'Dal Rice','lunch')
INTO meals VALUES(11,'Rajma Rice','lunch')
INTO meals VALUES(12,'Veg Khichdi','lunch')
INTO meals VALUES(13,'Veg Pulao','lunch')
INTO meals VALUES(14,'Fried Rice','lunch')
INTO meals VALUES(15,'Kadhi Chawal','lunch')
INTO meals VALUES(16,'Sambar Rice','lunch')
INTO meals VALUES(17,'Paneer Rice Bowl','lunch')
INTO meals VALUES(18,'Jeera Rice Dal','lunch')

-- DINNER
INTO meals VALUES(19,'Paneer Butter Masala','dinner')
INTO meals VALUES(20,'Roti Sabzi','dinner')
INTO meals VALUES(21,'Veg Biryani','dinner')
INTO meals VALUES(22,'Mix Veg','dinner')
INTO meals VALUES(23,'Egg Curry','dinner')
INTO meals VALUES(24,'Tandoori Paneer','dinner')
INTO meals VALUES(25,'Jeera Rice Combo','dinner')
INTO meals VALUES(26,'Dal Makhani','dinner')
INTO meals VALUES(27,'Malai Kofta','dinner')

-- EXTRA OPTIONS
INTO meals VALUES(28,'Cornflakes Milk','breakfast')
INTO meals VALUES(29,'Boiled Eggs Toast','breakfast')
INTO meals VALUES(30,'Paneer Sandwich','breakfast')

INTO meals VALUES(31,'Lemon Rice','lunch')
INTO meals VALUES(32,'Curd Rice','lunch')
INTO meals VALUES(33,'Pav Bhaji','lunch')

INTO meals VALUES(34,'Dal Tadka','dinner')
INTO meals VALUES(35,'Paneer Bhurji','dinner')
INTO meals VALUES(36,'Chole Bhature','dinner')

SELECT * FROM dual;

/* =========================================================
   ENABLE SERVER OUTPUT
   ========================================================= */
SET SERVEROUTPUT ON;
COMMIT;

/* =========================================================
   FULL 8 WEEK SIMULATION
   ========================================================= */

DECLARE

    v_start_date DATE := DATE '2026-03-01';
    v_current_date DATE;

    v_hour NUMBER;
    v_min NUMBER;
    v_scan_time TIMESTAMP;

    v_rating NUMBER;
    v_waste NUMBER;

    v_meal_type VARCHAR2(20);

BEGIN

    FOR wk IN 1 .. 8 LOOP

        /* =====================================================
           GENERATE WEEKLY MENU
           ===================================================== */
        FOR d IN 0 .. 6 LOOP

            v_current_date := v_start_date + ((wk - 1) * 7) + d;

            EXIT WHEN v_current_date > DATE '2026-04-29';

            FOR meal_type_rec IN (
                SELECT DISTINCT meal_type FROM meals
            )
            LOOP

                DECLARE
                    v_meal_id NUMBER;
                BEGIN
                    SELECT meal_id
                    INTO v_meal_id
                    FROM (
                        SELECT meal_id
                        FROM meals
                        WHERE meal_type = meal_type_rec.meal_type
                        ORDER BY DBMS_RANDOM.VALUE
                    )
                    WHERE ROWNUM = 1;

                    INSERT INTO menu(menu_id, serve_date, meal_id, generated_on)
                    VALUES(
                        seq_menu_id.NEXTVAL,
                        v_current_date,
                        v_meal_id,
                        SYSDATE
                    );

                EXCEPTION
                    WHEN DUP_VAL_ON_INDEX THEN NULL;
                END;

            END LOOP;

        END LOOP;

        COMMIT;

        /* =====================================================
           GENERATE LEAVES
           ===================================================== */
        FOR u IN (
            SELECT user_id FROM users WHERE role = 'student'
        )
        LOOP

            IF DBMS_RANDOM.VALUE(0,1) < 0.15 THEN

                DECLARE
                    v_leave_start DATE;
                    v_leave_end DATE;
                    v_status VARCHAR2(20);
                BEGIN

                    v_leave_start :=
                        v_start_date + ((wk - 1) * 7)
                        + TRUNC(DBMS_RANDOM.VALUE(0,5));

                    v_leave_end :=
                        v_leave_start + TRUNC(DBMS_RANDOM.VALUE(1,3));

                    IF DBMS_RANDOM.VALUE < 0.7 THEN
                        v_status := 'approved';
                    ELSE
                        v_status := 'pending';
                    END IF;

                    INSERT INTO leave_application
                    VALUES(
                        seq_leave_id.NEXTVAL,
                        u.user_id,
                        v_leave_start,
                        v_leave_end,
                        SYSTIMESTAMP,
                        v_status
                    );

                END;

            END IF;

        END LOOP;

        COMMIT;

        /* =====================================================
           GENERATE SCANS
           ===================================================== */
        FOR m IN (
            SELECT menu_id, serve_date, meal_id
            FROM menu
            WHERE serve_date BETWEEN
                v_start_date + ((wk - 1) * 7)
                AND v_start_date + ((wk - 1) * 7) + 6
        )
        LOOP
        
            SAVEPOINT sp_scan_batch;

            SELECT meal_type INTO v_meal_type
            FROM meals
            WHERE meal_id = m.meal_id;

            FOR u IN (
                SELECT user_id FROM users WHERE role = 'student'
            )
            LOOP

                IF DBMS_RANDOM.VALUE(0,1) <= 0.85 THEN

                    IF v_meal_type = 'breakfast' THEN
                        v_hour := TRUNC(DBMS_RANDOM.VALUE(7,10));
                    ELSIF v_meal_type = 'lunch' THEN
                        v_hour := TRUNC(DBMS_RANDOM.VALUE(12,15));
                    ELSE
                        v_hour := TRUNC(DBMS_RANDOM.VALUE(19,22));
                    END IF;

                    v_min := TRUNC(DBMS_RANDOM.VALUE(0,59));

                    v_scan_time :=
                        TO_TIMESTAMP(
                            TO_CHAR(m.serve_date,'YYYY-MM-DD')
                            || ' '
                            || LPAD(v_hour,2,'0')
                            || ':'
                            || LPAD(v_min,2,'0')
                            || ':00',
                            'YYYY-MM-DD HH24:MI:SS'
                        );

                    BEGIN
                        INSERT INTO scans
                        VALUES(
                            seq_scan_id.NEXTVAL,
                            u.user_id,
                            m.menu_id,
                            v_scan_time
                        );
                    EXCEPTION
                        WHEN OTHERS THEN
                            DBMS_OUTPUT.PUT_LINE('SCAN ERROR: ' || SQLERRM);
                            ROLLBACK TO sp_scan_batch;  
                    END;

                END IF;

            END LOOP;

        END LOOP;

        COMMIT;

        /* =====================================================
           GENERATE RATINGS 
           ===================================================== */
        FOR s IN (
            SELECT user_id, menu_id
            FROM scans
            WHERE menu_id IN (
                SELECT menu_id
                FROM menu
                WHERE serve_date BETWEEN
                    v_start_date + ((wk - 1) * 7)
                    AND v_start_date + ((wk - 1) * 7) + 6
            )
        )
        LOOP
            
                    SAVEPOINT sp_before_ratings;
                    
            IF DBMS_RANDOM.VALUE(0,1) < 0.2 THEN
                v_rating := TRUNC(DBMS_RANDOM.VALUE(1,3));
            ELSE
                v_rating := TRUNC(DBMS_RANDOM.VALUE(3,6));
            END IF;

            BEGIN
                INSERT INTO ratings
                VALUES(
                    seq_rating_id.NEXTVAL,
                    s.user_id,
                    s.menu_id,
                    v_rating
                );
            EXCEPTION
                WHEN DUP_VAL_ON_INDEX THEN NULL;
                ROLLBACK TO sp_before_ratings;
            END;

        END LOOP;

        COMMIT;

        /* =====================================================
           GENERATE WASTE
           ===================================================== */
        FOR m IN (
            SELECT menu_id
            FROM menu
            WHERE serve_date BETWEEN
                v_start_date + ((wk - 1) * 7)
                AND v_start_date + ((wk - 1) * 7) + 6
        )
        LOOP

            IF DBMS_RANDOM.VALUE(0,1) < 0.2 THEN
                v_waste := ROUND(DBMS_RANDOM.VALUE(18,35),2);
            ELSE
                v_waste := ROUND(DBMS_RANDOM.VALUE(2,12),2);
            END IF;

            INSERT INTO waste_log
            VALUES(
                seq_waste_id.NEXTVAL,
                m.menu_id,
                v_waste,
                SYSTIMESTAMP
            );

        END LOOP;

        COMMIT;

        /* =====================================================
           REFRESH ANALYTICS
           ===================================================== */
        FOR m IN (
            SELECT menu_id
            FROM menu
            WHERE serve_date BETWEEN
                v_start_date + ((wk - 1) * 7)
                AND v_start_date + ((wk - 1) * 7) + 6
        )
        LOOP
            refresh_meal_analytics(m.menu_id);
        END LOOP;

        COMMIT;

        /* =====================================================
           WEEKLY SWAPS
           ===================================================== */
           
        SAVEPOINT sp_before_swaps;
        
        perform_weekly_swaps(wk);

        COMMIT;

        DBMS_OUTPUT.PUT_LINE('WEEK ' || wk || ' COMPLETED');

    END LOOP;

END;
/

/* =========================================================
QUERY 1: WEEKLY MENU RETRIEVAL
========================================================= */
SELECT
mn.serve_date,
m.meal_type,
m.meal_name
FROM menu mn
JOIN meals m ON mn.meal_id = m.meal_id
WHERE mn.serve_date BETWEEN DATE '2026-03-15' AND DATE '2026-03-21'
ORDER BY mn.serve_date, m.meal_type;

/* =========================================================
QUERY 2: TOP 3 MEALS BASED ON RATING
========================================================= */
SELECT *
FROM (
SELECT
m.meal_name,
ROUND(AVG(r.rating),2) avg_rating
FROM ratings r
JOIN menu mn ON r.menu_id = mn.menu_id
JOIN meals m ON mn.meal_id = m.meal_id
GROUP BY m.meal_name
ORDER BY avg_rating DESC
)
WHERE ROWNUM <= 3;

/* =========================================================
QUERY 3: TOP 3 MOST WASTED MEALS
========================================================= */
SELECT *
FROM (
SELECT
m.meal_name,
ROUND(AVG(w.quantity_kg),2) avg_waste
FROM waste_log w
JOIN menu mn ON w.menu_id = mn.menu_id
JOIN meals m ON mn.meal_id = m.meal_id
GROUP BY m.meal_name
ORDER BY avg_waste DESC
)
WHERE ROWNUM <= 3;

/* =========================================================
QUERY 4: STUDENTS WHO NEVER TOOK LEAVE
========================================================= */
SELECT
u.user_id,
u.name
FROM users u
WHERE u.role = 'student'
AND NOT EXISTS (
SELECT 1
FROM leave_application l
WHERE l.user_id = u.user_id
);

/* =========================================================
QUERY 5: HIGH RATED + HIGH WASTE MEALS
========================================================= */
SELECT
m.meal_name,
ROUND(AVG(r.rating),2) avg_rating,
ROUND(AVG(w.quantity_kg),2) avg_waste
FROM menu mn
JOIN meals m ON mn.meal_id = m.meal_id
JOIN ratings r ON r.menu_id = mn.menu_id
JOIN waste_log w ON w.menu_id = mn.menu_id
GROUP BY m.meal_name
HAVING AVG(r.rating) >= 4
AND AVG(w.quantity_kg) >= 15
ORDER BY avg_waste DESC;

/* =========================================================
QUERY 6: MOST SWAPPED MEAL
========================================================= */
SELECT *
FROM (
SELECT
m.meal_name,
COUNT(*) total_swaps
FROM swap_history sh
JOIN meals m ON sh.old_meal_id = m.meal_id
GROUP BY m.meal_name
ORDER BY total_swaps DESC
)
WHERE ROWNUM = 1;

/* =========================================================
QUERY 7: LEAST SWAPPED MEAL
========================================================= */
SELECT *
FROM (
SELECT
m.meal_name,
COUNT(*) total_swaps
FROM swap_history sh
JOIN meals m ON sh.old_meal_id = m.meal_id
GROUP BY m.meal_name
ORDER BY total_swaps ASC
)
WHERE ROWNUM = 1;

/* =========================================================
QUERY 8: ATTENDANCE BY MEAL TYPE
========================================================= */
SELECT
m.meal_type,
COUNT(*) total_attendance
FROM scans s
JOIN menu mn ON s.menu_id = mn.menu_id
JOIN meals m ON mn.meal_id = m.meal_id
GROUP BY m.meal_type
ORDER BY total_attendance DESC;

/* =========================================================
QUERY 9: WASTE BEFORE VS AFTER SWAP
========================================================= */
SELECT
oldm.meal_name old_meal,
ROUND(AVG(w1.quantity_kg),2) waste_before,
newm.meal_name new_meal,
ROUND(AVG(w2.quantity_kg),2) waste_after
FROM swap_history sh
JOIN meals oldm ON sh.old_meal_id = oldm.meal_id
JOIN meals newm ON sh.new_meal_id = newm.meal_id
LEFT JOIN menu mn1 ON mn1.meal_id = sh.old_meal_id
LEFT JOIN waste_log w1 ON w1.menu_id = mn1.menu_id
LEFT JOIN menu mn2 ON mn2.meal_id = sh.new_meal_id
LEFT JOIN waste_log w2 ON w2.menu_id = mn2.menu_id
GROUP BY oldm.meal_name, newm.meal_name;

/* =========================================================
QUERY 10: WEEKLY WASTE ANALYSIS (DINNER)
========================================================= */
SELECT
TO_CHAR(mn.serve_date, 'IW') week_no,
m.meal_type,
ROUND(AVG(w.quantity_kg),2) avg_waste
FROM menu mn
JOIN meals m ON mn.meal_id = m.meal_id
JOIN waste_log w ON w.menu_id = mn.menu_id
WHERE m.meal_type = 'dinner'
GROUP BY TO_CHAR(mn.serve_date, 'IW'), m.meal_type
ORDER BY week_no;

/* =========================================================
QUERY 11: MOST LOVED MEAL PER TYPE
========================================================= */
SELECT *
FROM (
SELECT
m.meal_type,
m.meal_name,
ROUND(AVG(r.rating),2) avg_rating,
RANK() OVER(
PARTITION BY m.meal_type
ORDER BY AVG(r.rating) DESC
) rnk
FROM ratings r
JOIN menu mn ON r.menu_id = mn.menu_id
JOIN meals m ON mn.meal_id = m.meal_id
GROUP BY m.meal_type, m.meal_name
)
WHERE rnk = 1;

/* =========================================================
QUERY 12: MEALS NEVER SWAPPED BUT FREQUENTLY SERVED
========================================================= */
SELECT
m.meal_name,
COUNT(mn.menu_id) times_served
FROM meals m
JOIN menu mn ON m.meal_id = mn.meal_id
WHERE m.meal_id NOT IN (
SELECT old_meal_id FROM swap_history
)
GROUP BY m.meal_name
HAVING COUNT(mn.menu_id) >= 5
ORDER BY times_served DESC;

/* =========================================================
QUERY 13: PEAK HOURS ANALYSIS
========================================================= */
SELECT
m.meal_type,
EXTRACT(HOUR FROM s.scan_time) hour,
COUNT(*) total_scans
FROM scans s
JOIN menu mn ON s.menu_id = mn.menu_id
JOIN meals m ON mn.meal_id = m.meal_id
GROUP BY m.meal_type, EXTRACT(HOUR FROM s.scan_time)
ORDER BY m.meal_type, total_scans DESC;

/* =========================================================
QUERY 14: MOST ENGAGED STUDENTS (ALL 3 MEALS/DAY)
========================================================= */
SELECT
u.name,
COUNT(*) full_meal_days
FROM (
SELECT
s.user_id,
mn.serve_date
FROM scans s
JOIN menu mn ON s.menu_id = mn.menu_id
GROUP BY s.user_id, mn.serve_date
HAVING COUNT(DISTINCT mn.menu_id) = 3
) x
JOIN users u ON x.user_id = u.user_id
GROUP BY u.name
ORDER BY full_meal_days DESC;

/* =========================================================
QUERY 15: BEST SWAP (MAX WASTE REDUCTION)
========================================================= */

SELECT *
FROM (
SELECT
oldm.meal_name AS replaced_meal,
newm.meal_name AS new_meal,


    ROUND(AVG(w_before.quantity_kg), 2) AS waste_before,
    ROUND(AVG(w_after.quantity_kg), 2) AS waste_after,

    ROUND(AVG(w_before.quantity_kg) - AVG(w_after.quantity_kg), 2) 
        AS waste_reduction

FROM swap_history sh

JOIN meals oldm ON sh.old_meal_id = oldm.meal_id
JOIN meals newm ON sh.new_meal_id = newm.meal_id

LEFT JOIN menu mn1 ON mn1.meal_id = sh.old_meal_id
LEFT JOIN waste_log w_before ON w_before.menu_id = mn1.menu_id

LEFT JOIN menu mn2 ON mn2.meal_id = sh.new_meal_id
LEFT JOIN waste_log w_after ON w_after.menu_id = mn2.menu_id

GROUP BY oldm.meal_name, newm.meal_name

ORDER BY waste_reduction DESC


)
WHERE ROWNUM = 1;

/* =========================================================
QUERY 16: WORST SWAP (MAX WASTE INCREASE)
========================================================= */

SELECT *
FROM (
SELECT
oldm.meal_name AS replaced_meal,
newm.meal_name AS new_meal,


    ROUND(AVG(w_before.quantity_kg), 2) AS waste_before,
    ROUND(AVG(w_after.quantity_kg), 2) AS waste_after,

    ROUND(AVG(w_after.quantity_kg) - AVG(w_before.quantity_kg), 2) 
        AS waste_increase

FROM swap_history sh

JOIN meals oldm ON sh.old_meal_id = oldm.meal_id
JOIN meals newm ON sh.new_meal_id = newm.meal_id

LEFT JOIN menu mn1 ON mn1.meal_id = sh.old_meal_id
LEFT JOIN waste_log w_before ON w_before.menu_id = mn1.menu_id

LEFT JOIN menu mn2 ON mn2.meal_id = sh.new_meal_id
LEFT JOIN waste_log w_after ON w_after.menu_id = mn2.menu_id

GROUP BY oldm.meal_name, newm.meal_name

ORDER BY waste_increase DESC


)
WHERE ROWNUM = 1;

/* =========================================================================
QUERY 17 : IMPACT OF MEALS ON NEXT-DAY LEAVE BEHAVIOR (ABSENTEEISM ANALYSIS)
============================================================================ */
SELECT *
FROM (
    SELECT 
        m.meal_name,
        COUNT(DISTINCT la.user_id) AS leave_count
    FROM menu mn
    JOIN meals m 
        ON mn.meal_id = m.meal_id
    JOIN leave_application la
        ON la.status = 'approved'
        AND TRUNC(mn.serve_date + 1) 
            BETWEEN TRUNC(la.start_date) AND TRUNC(la.end_date)
    GROUP BY m.meal_name
    ORDER BY leave_count DESC
)
WHERE ROWNUM = 1;

SELECT *
FROM (
    SELECT 
        m.meal_name,
        COUNT(DISTINCT la.user_id) AS leave_count
    FROM menu mn
    JOIN meals m 
        ON mn.meal_id = m.meal_id
    JOIN leave_application la
        ON la.status = 'approved'
        AND TRUNC(mn.serve_date + 1) 
            BETWEEN TRUNC(la.start_date) AND TRUNC(la.end_date)
    GROUP BY m.meal_name
    ORDER BY leave_count ASC
)
WHERE ROWNUM = 1;

/* ===========================================================
QUERY 18 : VALIDATION DEMO: NO SCAN → NO RATING (TRIGGER TEST)
============================================================== */

-- STEP 1: Verify NO SCAN exists for chosen student

SELECT * FROM scans
WHERE user_id = 9 AND menu_id = 10;

-- STEP 2: Try rating WITHOUT scan (SHOULD FAIL)

INSERT INTO ratings
VALUES(
seq_rating_id.NEXTVAL,
9,
10,
4
);

-- STEP 3: Insert valid scan for another student

INSERT INTO scans
VALUES(
seq_scan_id.NEXTVAL,
8,
15,
TO_TIMESTAMP('2026-05-11 20:00:00','YYYY-MM-DD HH24:MI:SS')
);


-- STEP 4: Try rating AFTER scan (SHOULD SUCCEED)

SELECT mn.menu_id, mn.serve_date, m.meal_type
FROM menu mn
JOIN meals m ON mn.meal_id = m.meal_id
WHERE ROWNUM = 1;

SELECT u.user_id
FROM users u
WHERE u.role = 'student'
AND NOT EXISTS (
    SELECT 1 FROM scans s
    WHERE s.user_id = u.user_id
    AND s.menu_id = 22
)
AND ROWNUM = 1;

INSERT INTO scans
VALUES(
    seq_scan_id.NEXTVAL,
    7,
    22,
    TO_TIMESTAMP('2026-03-08 08:30:00','YYYY-MM-DD HH24:MI:SS')
);

COMMIT;

/* =========================================================
QUERY 19: BLOCK SCAN DURING APPROVED LEAVE (DEMO)
========================================================= */

-- STEP 0: Pick a menu inside leave range
SELECT menu_id, serve_date
FROM menu
WHERE serve_date BETWEEN DATE '2026-04-01' AND DATE '2026-04-03';

-- menu_id = 98 from above output

-- STEP 1: Insert APPROVED leave

INSERT INTO leave_application
VALUES(
seq_leave_id.NEXTVAL,
1,
DATE '2026-04-01',
DATE '2026-04-03',
SYSTIMESTAMP,
'approved'
);

COMMIT;

-- STEP 2: Try scan during leave (SHOULD FAIL)

SELECT 
    mn.menu_id,
    mn.serve_date,
    m.meal_id,
    m.meal_name,
    m.meal_type
FROM menu mn
JOIN meals m ON mn.meal_id = m.meal_id
WHERE mn.menu_id = 98;

INSERT INTO scans
VALUES(
seq_scan_id.NEXTVAL,
1,
98,
TO_TIMESTAMP('2026-04-02 13:00:00','YYYY-MM-DD HH24:MI:SS')
);

/* =========================================================
QUERY 20: BEST WEEK MENU TILL DATE
========================================================= */

SELECT *
FROM (
    SELECT
        TRUNC(mn.serve_date, 'IW') AS week_start_date,
        TRUNC(mn.serve_date, 'IW') + 6 AS week_end_date,

        COUNT(mn.menu_id) AS total_menus,

        ROUND(AVG(ma.avg_rating),2) AS avg_rating,
        ROUND(AVG(ma.total_waste),2) AS avg_waste,

        ROUND(
            (AVG(ma.avg_rating) * 2)
            - (AVG(ma.total_waste) / 5),
        2) AS performance_score

    FROM menu mn
    JOIN meal_analytics ma
        ON mn.menu_id = ma.menu_id

    GROUP BY TRUNC(mn.serve_date, 'IW')

    HAVING COUNT(mn.menu_id) >= 8   

    ORDER BY performance_score DESC
)
WHERE ROWNUM = 1;

/* =========================================================
QUERY 21: AUTO DETECT OVER-SERVING (FIXED DEMO)
========================================================= */

SET SERVEROUTPUT ON;

-- STEP 1: No trigger case (safe values)

UPDATE meal_analytics
SET total_waste = 10,
attendance_count = 50
WHERE menu_id = 30;

-- STEP 2: Trigger case (high waste + high attendance)

UPDATE meal_analytics
SET total_waste = 25,
attendance_count = 100
WHERE menu_id = 30;

COMMIT;


/* ============================================================================
QUERY 22: ADMIN: MEAL DEMAND FORECAST (AVERAGE STUDENT CONSUMPTION PER SERVING)
=============================================================================== */
SELECT
    m.meal_name,
    ROUND(COUNT(s.user_id) / COUNT(DISTINCT mn.menu_id),0) AS expected_demand
FROM scans s
JOIN menu mn ON s.menu_id = mn.menu_id
JOIN meals m ON mn.meal_id = m.meal_id
GROUP BY m.meal_name;

/* ==========================================================
QUERY 23 : ADMIN: SWAP EFFECTIVENESS (BEFORE VS AFTER RATING)
========================================================= */

SELECT
    oldm.meal_name old_meal,
    newm.meal_name new_meal,
    ROUND(AVG(ma1.avg_rating),2) old_rating,
    ROUND(AVG(ma2.avg_rating),2) new_rating,
    ROUND(AVG(ma2.avg_rating) - AVG(ma1.avg_rating),2) improvement
FROM swap_history sh
JOIN meals oldm ON sh.old_meal_id = oldm.meal_id
JOIN meals newm ON sh.new_meal_id = newm.meal_id

LEFT JOIN menu mn1 ON mn1.meal_id = sh.old_meal_id
LEFT JOIN meal_analytics ma1 ON ma1.menu_id = mn1.menu_id

LEFT JOIN menu mn2 ON mn2.meal_id = sh.new_meal_id
LEFT JOIN meal_analytics ma2 ON ma2.menu_id = mn2.menu_id

GROUP BY oldm.meal_name, newm.meal_name
ORDER BY improvement DESC;

/* ==========================================================
                            END
============================================================= */

