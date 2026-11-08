-- Checks that schema.sql enforces what the specification says. A failed check raises an
-- error, which makes psql -v ON_ERROR_STOP=1 exit with a failure.

DO $$
DECLARE
    the_vehicle uuid;
    the_layout uuid;
    the_trip uuid;
    the_booking uuid;
    seat_1 uuid;
    seat_2 uuid;
    rider_a uuid;
    rider_b uuid;
    rider_c uuid;
    rider_d uuid;
    assignment_a uuid;
    assignment_b uuid;
    audit_row bigint;
    refused boolean;
BEGIN
    INSERT INTO vehicles DEFAULT VALUES RETURNING id INTO the_vehicle;
    INSERT INTO vehicle_seat_layouts (vehicle_id) VALUES (the_vehicle) RETURNING id INTO the_layout;
    INSERT INTO trips DEFAULT VALUES RETURNING id INTO the_trip;
    INSERT INTO bookings (trip_id) VALUES (the_trip) RETURNING id INTO the_booking;
    INSERT INTO vehicle_seats (layout_id, seat_number) VALUES (the_layout, '1') RETURNING id INTO seat_1;
    INSERT INTO vehicle_seats (layout_id, seat_number) VALUES (the_layout, '2') RETURNING id INTO seat_2;
    INSERT INTO booking_passengers (booking_id, seat_id) VALUES (the_booking, seat_1) RETURNING id INTO rider_a;
    INSERT INTO booking_passengers (booking_id, seat_id) VALUES (the_booking, seat_2) RETURNING id INTO rider_b;
    INSERT INTO booking_passengers (booking_id, seat_id) VALUES (the_booking, seat_1) RETURNING id INTO rider_c;
    INSERT INTO booking_passengers (booking_id, seat_id) VALUES (the_booking, seat_1) RETURNING id INTO rider_d;

    -- A seat can be shared by stretches that do not overlap, including one boarding at
    -- the stop where the other gets off.
    INSERT INTO seat_assignments (trip_id, booking_passenger_id, seat_id, board_position, alight_position)
    VALUES (the_trip, rider_a, seat_1, 0, 5) RETURNING id INTO assignment_a;
    INSERT INTO seat_assignments (trip_id, booking_passenger_id, seat_id, board_position, alight_position)
    VALUES (the_trip, rider_c, seat_1, 5, 9);
    SET CONSTRAINTS seat_assignments_no_overlap IMMEDIATE;
    SET CONSTRAINTS seat_assignments_no_overlap DEFERRED;
    RAISE NOTICE 'ok: non-overlapping stretches share a seat';

    -- It cannot be promised to two passengers on overlapping stretches.
    refused := false;
    BEGIN
        INSERT INTO seat_assignments (trip_id, booking_passenger_id, seat_id, board_position, alight_position)
        VALUES (the_trip, rider_d, seat_1, 3, 8);
        SET CONSTRAINTS seat_assignments_no_overlap IMMEDIATE;
    EXCEPTION WHEN exclusion_violation THEN
        refused := true;
    END;
    SET CONSTRAINTS seat_assignments_no_overlap DEFERRED;
    IF NOT refused THEN RAISE EXCEPTION 'overlapping stretches were allowed in one seat'; END IF;
    RAISE NOTICE 'ok: overlapping stretches are refused';

    -- Two passengers can swap seats in one transaction.
    INSERT INTO seat_assignments (trip_id, booking_passenger_id, seat_id, board_position, alight_position)
    VALUES (the_trip, rider_b, seat_2, 0, 5) RETURNING id INTO assignment_b;
    UPDATE seat_assignments SET seat_id = seat_2 WHERE id = assignment_a;
    UPDATE seat_assignments SET seat_id = seat_1 WHERE id = assignment_b;
    -- Rider c shares seat 1 from km 5, and rider b is now in seat 1 until km 5: still fine.
    SET CONSTRAINTS seat_assignments_no_overlap IMMEDIATE;
    SET CONSTRAINTS seat_assignments_no_overlap DEFERRED;
    RAISE NOTICE 'ok: a swap inside one transaction succeeds';

    -- A cancelled passenger no longer holds the seat.
    UPDATE seat_assignments SET status = 'cancelled' WHERE id = assignment_b;
    INSERT INTO seat_assignments (trip_id, booking_passenger_id, seat_id, board_position, alight_position)
    VALUES (the_trip, rider_d, seat_1, 0, 5);
    SET CONSTRAINTS seat_assignments_no_overlap IMMEDIATE;
    SET CONSTRAINTS seat_assignments_no_overlap DEFERRED;
    RAISE NOTICE 'ok: a cancelled passenger frees the seat';

    -- A passenger who has boarded never moves.
    UPDATE seat_assignments SET status = 'boarded' WHERE id = assignment_a;
    refused := false;
    BEGIN
        UPDATE seat_assignments SET seat_id = seat_1 WHERE id = assignment_a;
    EXCEPTION WHEN check_violation THEN
        refused := true;
    END;
    IF NOT refused THEN RAISE EXCEPTION 'a boarded passenger was moved'; END IF;
    RAISE NOTICE 'ok: a boarded passenger cannot be moved';

    -- A ride must go forward.
    refused := false;
    BEGIN
        UPDATE seat_assignments SET alight_position = 0 WHERE id = assignment_a;
    EXCEPTION WHEN check_violation THEN
        refused := true;
    END;
    IF NOT refused THEN RAISE EXCEPTION 'a ride ending at or before its start was allowed'; END IF;
    RAISE NOTICE 'ok: the alight position must come after the boarding position';

    -- The audit log is append-only and every entry has a reason.
    INSERT INTO seat_audit_log (trip_id, action, reason)
    VALUES (the_trip, 'seat_changed', 'new booking') RETURNING id INTO audit_row;
    refused := false;
    BEGIN
        UPDATE seat_audit_log SET reason = 'edited' WHERE id = audit_row;
    EXCEPTION WHEN raise_exception THEN
        refused := true;
    END;
    IF NOT refused THEN RAISE EXCEPTION 'an audit entry was edited'; END IF;
    refused := false;
    BEGIN
        DELETE FROM seat_audit_log WHERE id = audit_row;
    EXCEPTION WHEN raise_exception THEN
        refused := true;
    END;
    IF NOT refused THEN RAISE EXCEPTION 'an audit entry was deleted'; END IF;
    refused := false;
    BEGIN
        INSERT INTO seat_audit_log (trip_id, action, reason) VALUES (the_trip, 'seat_changed', '');
    EXCEPTION WHEN check_violation THEN
        refused := true;
    END;
    IF NOT refused THEN RAISE EXCEPTION 'an audit entry with no reason was allowed'; END IF;
    RAISE NOTICE 'ok: the audit log is append-only and needs a reason';

    -- A seat cannot block itself.
    refused := false;
    BEGIN
        INSERT INTO vehicle_seat_blockers (seat_id, blocker_seat_id) VALUES (seat_1, seat_1);
    EXCEPTION WHEN check_violation THEN
        refused := true;
    END;
    IF NOT refused THEN RAISE EXCEPTION 'a seat was allowed to block itself'; END IF;
    INSERT INTO vehicle_seat_blockers (seat_id, blocker_seat_id) VALUES (seat_2, seat_1);
    RAISE NOTICE 'ok: seat blockers are checked';

    -- Passenger categories are a closed list.
    refused := false;
    BEGIN
        UPDATE booking_passengers SET category = 'vip' WHERE id = rider_a;
    EXCEPTION WHEN check_violation THEN
        refused := true;
    END;
    IF NOT refused THEN RAISE EXCEPTION 'an unknown passenger category was allowed'; END IF;
    RAISE NOTICE 'ok: passenger categories are checked';

    RAISE NOTICE 'all schema checks passed';
END $$;
