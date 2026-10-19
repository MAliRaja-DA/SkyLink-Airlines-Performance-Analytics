-- ============================================================
--  SkyLink Airlines — Final Logical Data Model
--  PostgreSQL DDL — matches the validated DbSchema Pro model
-- ============================================================

-- ---------- AIRPORT ----------
CREATE TABLE airport (
    airport_id   SERIAL PRIMARY KEY,
    airport_code VARCHAR(10)  NOT NULL UNIQUE,
    name         VARCHAR(100) NOT NULL,
    city         VARCHAR(100) NOT NULL,
    country      VARCHAR(100) NOT NULL,
    timezone     VARCHAR(100) NOT NULL
);
COMMENT ON TABLE airport IS 'Every airport in SkyLink''s network, identified by its unique 3-letter code.';

-- ---------- ROUTE ----------
CREATE TABLE route (
    route_id                SERIAL PRIMARY KEY,
    origin_airport_id       INTEGER       NOT NULL REFERENCES airport(airport_id),
    destination_airport_id  INTEGER       NOT NULL REFERENCES airport(airport_id),
    distance_km             DECIMAL(8,2)  NOT NULL,
    duration_minutes        INTEGER       NOT NULL
);
COMMENT ON TABLE route IS 'A reusable path between two airports; the template that dated flights are scheduled against.';

-- ---------- AIRCRAFT ----------
CREATE TABLE aircraft (
    aircraft_id         SERIAL PRIMARY KEY,
    registration_number VARCHAR(50)     NOT NULL UNIQUE,
    model               VARCHAR(100)    NOT NULL,
    manufacturer        VARCHAR(100)    NOT NULL,
    total_seats         INTEGER         NOT NULL,
    status              VARCHAR(20)     NOT NULL CHECK (status IN ('active', 'maintenance', 'retired'))
);
COMMENT ON TABLE aircraft IS 'SkyLink''s fleet. One row per physical airframe.';

-- ---------- AIRCRAFT_SEAT ----------
CREATE TABLE aircraft_seat (
    seat_id     SERIAL PRIMARY KEY,
    aircraft_id INTEGER    NOT NULL REFERENCES aircraft(aircraft_id) ON DELETE CASCADE,
    seat_number VARCHAR(10) NOT NULL,
    seat_class  VARCHAR(20) NOT NULL CHECK (seat_class IN ('Economy', 'Business', 'First')),
    is_usable   BOOLEAN    NOT NULL
);
COMMENT ON TABLE aircraft_seat IS 'The fixed physical seat map of an aircraft; unchanged unless the aircraft is refitted.';

-- ---------- FLIGHT ----------
CREATE TABLE flight (
    flight_id           SERIAL PRIMARY KEY,
    flight_number       VARCHAR(20)   NOT NULL,
    route_id            INTEGER       NOT NULL REFERENCES route(route_id),
    aircraft_id         INTEGER       NULL REFERENCES aircraft(aircraft_id),
    scheduled_departure TIMESTAMP     NOT NULL,
    scheduled_arrival   TIMESTAMP     NOT NULL,
    status              VARCHAR(20)   NOT NULL CHECK (status IN ('Scheduled', 'Delayed', 'Cancelled', 'Departed', 'Landed'))
);
COMMENT ON TABLE flight IS 'One specific, dated departure of a route. aircraft_id is nullable: a flight may not yet have a confirmed aircraft.';

-- ---------- PASSENGER ----------
CREATE TABLE passenger (
    passenger_id       SERIAL PRIMARY KEY,
    full_name          VARCHAR(100) NOT NULL,
    passport_number    VARCHAR(50)  NOT NULL,
    email              VARCHAR(100) NOT NULL,
    phone              VARCHAR(20)  NOT NULL,
    frequent_flyer_no  VARCHAR(50)  NULL UNIQUE
);
COMMENT ON TABLE passenger IS 'Everyone registered with SkyLink, whether or not they currently hold a booking.';

-- ---------- BOOKING ----------
CREATE TABLE booking (
    booking_id           SERIAL PRIMARY KEY,
    booking_reference     VARCHAR(50)    NOT NULL UNIQUE,
    contact_passenger_id  INTEGER        NOT NULL REFERENCES passenger(passenger_id),
    booking_datetime      TIMESTAMP      NOT NULL,
    status                VARCHAR(20)    NOT NULL CHECK (status IN ('Confirmed', 'Cancelled', 'Completed'))
);
COMMENT ON TABLE booking IS 'One reservation transaction; may cover several passengers travelling together and several flights.';

-- ---------- TICKET (ternary junction: booking + passenger + flight) ----------
CREATE TABLE ticket (
    ticket_id    SERIAL PRIMARY KEY,
    booking_id   INTEGER       NOT NULL REFERENCES booking(booking_id) ON DELETE CASCADE,
    passenger_id INTEGER       NOT NULL REFERENCES passenger(passenger_id),
    flight_id    INTEGER       NOT NULL REFERENCES flight(flight_id),
    seat_id      INTEGER       NULL REFERENCES aircraft_seat(seat_id),
    fare_class   VARCHAR(20)   NULL CHECK (fare_class IS NULL OR fare_class IN ('Economy', 'Business', 'First')),
    price        DECIMAL(10,2) NOT NULL,
    status       VARCHAR(20)   NULL CHECK (status IS NULL OR status IN ('Booked', 'Checked In', 'Boarded', 'Cancelled'))
);
COMMENT ON TABLE ticket IS 'Ties ONE passenger to ONE flight within ONE booking - the three-way junction at the heart of the model. seat_id is filled in only at check-in.';

-- ---------- BAGGAGE ----------
CREATE TABLE baggage (
    bag_id         SERIAL PRIMARY KEY,
    ticket_id      INTEGER        NOT NULL REFERENCES ticket(ticket_id) ON DELETE CASCADE,
    bag_tag_number VARCHAR(30)    NOT NULL,
    weight_kg      DECIMAL(5,2)   NOT NULL,
    status         VARCHAR(20)    NOT NULL CHECK (status IN ('Checked', 'Loaded', 'Claimed', 'Lost'))
);
COMMENT ON TABLE baggage IS 'A checked bag, always linked to the specific ticket it was checked against. A ticket may have several bags.';

-- ---------- CREW_MEMBER ----------
CREATE TABLE crew_member (
    crew_id         SERIAL PRIMARY KEY,
    employee_number VARCHAR(30)    NOT NULL,
    full_name       VARCHAR(100)   NOT NULL,
    role_type       VARCHAR(20)    NOT NULL CHECK (role_type IN ('Pilot', 'First Officer', 'Attendant')),
    license_number  VARCHAR(50)    NULL
);
COMMENT ON TABLE crew_member IS 'Pilots and flight attendants employed by SkyLink. license_number is nullable - only pilots hold one.';

-- ---------- FLIGHT_CREW_ASSIGNMENT (junction: flight <-> crew_member) ----------
CREATE TABLE flight_crew_assignment (
    flight_crew_assignment_id SERIAL           PRIMARY KEY,
    flight_id                 INTEGER          NOT NULL REFERENCES flight(flight_id) ON DELETE CASCADE,
    crew_member_id             INTEGER          NOT NULL REFERENCES crew_member(crew_id),
    role_on_flight              VARCHAR(20)     NOT NULL CHECK (role_on_flight IN ('captain', 'first_officer', 'check_captain', 'purser', 'attendant'))
);
COMMENT ON TABLE flight_crew_assignment IS 'Junction table resolving the M:N relationship between flights and crew members; records the specific role worked on that flight.';

-- ---------- PAYMENT ----------
CREATE TABLE payment (
    payment_id     SERIAL PRIMARY KEY,
    booking_id     INTEGER        NOT NULL REFERENCES booking(booking_id) ON DELETE CASCADE,
    amount         NUMERIC(10,2)  NOT NULL,
    payment_method VARCHAR(30)    NULL,
    attempted_at   TIMESTAMP      NOT NULL,
    result         VARCHAR(20)    NULL CHECK (result IS NULL OR result IN ('succeeded', 'failed'))
);
COMMENT ON TABLE payment IS 'Each individual payment attempt against a booking. A booking is paid once at least one attempt succeeds for the full amount due.';

-- ---------- HELPFUL INDEXES ON FOREIGN KEYS ----------
CREATE INDEX ix_route_origin       ON route(origin_airport_id);
CREATE INDEX ix_route_destination  ON route(destination_airport_id);
CREATE INDEX ix_flight_route       ON flight(route_id);
CREATE INDEX ix_flight_aircraft    ON flight(aircraft_id);
CREATE INDEX ix_seat_aircraft      ON aircraft_seat(aircraft_id);
CREATE INDEX ix_ticket_booking     ON ticket(booking_id);
CREATE INDEX ix_ticket_passenger   ON ticket(passenger_id);
CREATE INDEX ix_ticket_flight      ON ticket(flight_id);
CREATE INDEX ix_ticket_seat        ON ticket(seat_id);
CREATE INDEX ix_baggage_ticket     ON baggage(ticket_id);
CREATE INDEX ix_fca_flight         ON flight_crew_assignment(flight_id);
CREATE INDEX ix_fca_crew           ON flight_crew_assignment(crew_member_id);
CREATE INDEX ix_payment_booking    ON payment(booking_id);
