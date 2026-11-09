-- Minimal copies of the existing TroSky tables that schema.sql extends, for checking it
-- on its own. These are not the real definitions: see backend/app/models.

CREATE TABLE vehicles (id uuid PRIMARY KEY DEFAULT gen_random_uuid());

CREATE TABLE vehicle_seat_layouts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id uuid NOT NULL REFERENCES vehicles (id) ON DELETE CASCADE
);

CREATE TABLE vehicle_seats (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    layout_id uuid NOT NULL REFERENCES vehicle_seat_layouts (id) ON DELETE CASCADE,
    seat_number varchar(10) NOT NULL
);

CREATE TABLE trips (id uuid PRIMARY KEY DEFAULT gen_random_uuid());

CREATE TABLE bookings (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id uuid NOT NULL REFERENCES trips (id)
);

CREATE TABLE booking_passengers (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id uuid NOT NULL REFERENCES bookings (id) ON DELETE CASCADE,
    seat_id uuid NOT NULL REFERENCES vehicle_seats (id)
);
