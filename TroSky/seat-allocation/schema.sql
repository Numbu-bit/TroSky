-- Smart Seat Allocation: proposed additions to the TroSky database.
--
-- Additive: it extends the existing tables (vehicle_seats, vehicle_seat_layouts, trips,
-- booking_passengers) and adds new ones. It is not yet an Alembic migration, and the
-- backend does not use it. tests/schema_stubs.sql holds minimal copies of the existing
-- tables so CI can load this file and run tests/schema_checks.sql against real Postgres.
--
-- Positions are km along the route, or stop sequence numbers on a route with no measured
-- distances. Each trip uses one or the other.

CREATE EXTENSION IF NOT EXISTS btree_gist;

-- SeatLayout: how each seat reaches its door. All of it comes from a survey of the real
-- vehicle, or is marked unverified.
ALTER TABLE vehicle_seat_layouts
    ADD COLUMN model text,
    ADD COLUMN verification text NOT NULL DEFAULT 'verify against the actual fleet before launch';

ALTER TABLE vehicle_seats
    ADD COLUMN depth_rank integer CHECK (depth_rank >= 1),
    ADD COLUMN exit_door text,
    ADD COLUMN near_driver boolean NOT NULL DEFAULT false,
    ADD COLUMN accessible boolean NOT NULL DEFAULT false,
    ADD COLUMN bookable boolean NOT NULL DEFAULT true,
    ADD COLUMN folding boolean NOT NULL DEFAULT false,
    ADD COLUMN reserved_for text[] NOT NULL DEFAULT '{}',
    ADD COLUMN tags text[] NOT NULL DEFAULT '{}';

-- blocked_by: the seats directly on a seat's way to its door. The application works out
-- the full set, and refuses loops, as layout.py does.
CREATE TABLE vehicle_seat_blockers (
    seat_id uuid NOT NULL REFERENCES vehicle_seats (id) ON DELETE CASCADE,
    blocker_seat_id uuid NOT NULL REFERENCES vehicle_seats (id) ON DELETE CASCADE,
    PRIMARY KEY (seat_id, blocker_seat_id),
    CHECK (seat_id <> blocker_seat_id)
);

-- Trip: when seats lock. NULL seats_locked_at means they can still move.
ALTER TABLE trips
    ADD COLUMN seat_lock_at timestamptz,
    ADD COLUMN seats_locked_at timestamptz;

-- Booking: one row of booking_passengers is one traveller. A booking with several
-- passengers is a group unless group_id says otherwise.
ALTER TABLE booking_passengers
    ADD COLUMN category text NOT NULL DEFAULT 'standard'
        CHECK (category IN ('standard', 'elderly', 'pregnant', 'disabled', 'child', 'other_priority')),
    ADD COLUMN group_id uuid,
    ADD COLUMN seat_preference text,
    ADD COLUMN needs_accessible boolean NOT NULL DEFAULT false,
    ADD COLUMN luggage text NOT NULL DEFAULT 'none' CHECK (luggage IN ('none', 'small', 'bulky'));

-- AssignmentRun: one row each time the allocator ran, and what it achieved.
CREATE TABLE seat_assignment_runs (
    id bigserial PRIMARY KEY,
    trip_id uuid NOT NULL REFERENCES trips (id) ON DELETE CASCADE,
    trigger text NOT NULL,
    mode text NOT NULL CHECK (mode IN ('batch', 'online')),
    config_version text NOT NULL,
    blocking_before integer NOT NULL CHECK (blocking_before >= 0),
    blocking_after integer NOT NULL CHECK (blocking_after >= 0),
    minimum_blocking integer CHECK (minimum_blocking >= 0),  -- NULL: not proven
    proof text NOT NULL,
    seats_changed integer NOT NULL DEFAULT 0,
    ran_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_seat_assignment_runs_trip ON seat_assignment_runs (trip_id, ran_at);

-- SeatAssignment: who has which seat, and for which stretch of the route.
--
-- The exclusion constraint is the database's guarantee that no seat is promised to two
-- passengers on overlapping stretches. A stretch includes its boarding position and not
-- its alighting position, so someone can board at the stop where another gets off.
-- Being deferrable, it lets two passengers swap seats inside one transaction, which the
-- existing partial unique index on seat_reservations cannot do.
CREATE TABLE seat_assignments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id uuid NOT NULL REFERENCES trips (id) ON DELETE CASCADE,
    booking_passenger_id uuid NOT NULL UNIQUE REFERENCES booking_passengers (id) ON DELETE CASCADE,
    seat_id uuid NOT NULL REFERENCES vehicle_seats (id),
    board_position numeric(8, 3) NOT NULL,
    alight_position numeric(8, 3) NOT NULL,
    occupied numrange GENERATED ALWAYS AS (numrange(board_position, alight_position, '[)')) STORED,
    status text NOT NULL DEFAULT 'provisional'
        CHECK (status IN ('provisional', 'locked', 'boarded', 'alighted', 'cancelled', 'no_show')),
    run_id bigint REFERENCES seat_assignment_runs (id),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK (alight_position > board_position),
    CONSTRAINT seat_assignments_no_overlap EXCLUDE USING gist (
        trip_id WITH =,
        seat_id WITH =,
        occupied WITH &&
    ) WHERE (status IN ('provisional', 'locked', 'boarded'))
        DEFERRABLE INITIALLY DEFERRED
);
CREATE INDEX ix_seat_assignments_trip ON seat_assignments (trip_id, status);

-- A passenger who has boarded never moves, whatever the application does. Staff recording
-- where someone really sat do it before setting them boarded.
CREATE FUNCTION seat_assignments_guard() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.status = 'boarded' AND NEW.seat_id <> OLD.seat_id THEN
        RAISE EXCEPTION 'a boarded passenger never moves (assignment %)', OLD.id
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER seat_assignments_boarded_never_move
    BEFORE UPDATE ON seat_assignments
    FOR EACH ROW EXECUTE FUNCTION seat_assignments_guard();

-- Override: a passenger chose a seat, having seen what it costs.
CREATE TABLE seat_overrides (
    id bigserial PRIMARY KEY,
    trip_id uuid NOT NULL REFERENCES trips (id) ON DELETE CASCADE,
    booking_passenger_id uuid NOT NULL REFERENCES booking_passengers (id) ON DELETE CASCADE,
    previous_seat_id uuid REFERENCES vehicle_seats (id),
    seat_id uuid NOT NULL REFERENCES vehicle_seats (id),
    added_blocking integer NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- The audit log: every assignment and re-assignment, with its reason. Append-only.
CREATE TABLE seat_audit_log (
    id bigserial PRIMARY KEY,
    trip_id uuid NOT NULL,  -- no foreign key: the record outlives the trip
    booking_passenger_id uuid,
    action text NOT NULL,
    from_seat_id uuid,
    to_seat_id uuid,
    reason text NOT NULL CHECK (reason <> ''),
    run_id bigint,
    actor_id uuid,  -- NULL when the system did it
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_seat_audit_log_trip ON seat_audit_log (trip_id, id);

CREATE FUNCTION seat_audit_log_forbid_change() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'the seat audit log is append-only';
END $$;

CREATE TRIGGER seat_audit_log_append_only
    BEFORE UPDATE OR DELETE ON seat_audit_log
    FOR EACH ROW EXECUTE FUNCTION seat_audit_log_forbid_change();
