"""Deep links, topic switches and the new request rules (backend gaps from
the app's Step 20): no database needed."""

from __future__ import annotations

import uuid

import pytest
from pydantic import ValidationError

from app.models.identity import FavouritePlaceKind, NotificationPreference
from app.models.notifications import NotificationCategory, NotificationTopic, category_for
from app.schemas.auth import ResendOtpRequest, VerifyOtpRequest
from app.schemas.user import (
    FavouritePlaceCreateRequest,
    FavouritePlaceUpdateRequest,
    NotificationPreferencesUpdateRequest,
)
from app.services.notification_links import deep_link_for
from app.services.notification_service import delivers

BOOKING = str(uuid.uuid4())
TRIP = str(uuid.uuid4())
STOP = str(uuid.uuid4())


class TestDeepLinks:
    @pytest.mark.parametrize(
        ("data", "link"),
        [
            # Passengers
            ({"booking_id": BOOKING}, f"/bookings/{BOOKING}"),
            ({"booking_id": BOOKING, "action": "pay"}, f"/bookings/{BOOKING}"),
            ({"booking_id": BOOKING, "trip_id": TRIP, "action": "moved"}, f"/bookings/{BOOKING}"),
            ({"booking_id": BOOKING, "trip_id": TRIP}, f"/bookings/{BOOKING}"),
            ({"booking_id": BOOKING, "action": "search_again"}, "/search"),
            (
                {"booking_id": BOOKING, "stop_id": STOP, "action": "onward_trips"},
                f"/search?origin_stop_id={STOP}",
            ),
            # Drivers
            (
                {"booking_id": BOOKING, "trip_id": TRIP, "action": "booking_request"},
                f"/driver/trips/{TRIP}",
            ),
            ({"trip_id": TRIP, "action": "trip_assignment"}, f"/driver/trips/{TRIP}"),
            ({"trip_id": TRIP, "action": "trip_cancelled"}, f"/driver/trips/{TRIP}"),
            ({"action": "insurance_reminder", "expiry_date": "2026-12-01"}, "/driver/insurance"),
            ({"action": "insurance_blocked", "driver_id": str(uuid.uuid4())}, None),
            ({"type": "documents_requested", "driver_id": "d"}, "/driver/documents"),
            ({"type": "documents_requested", "vehicle_id": "v"}, None),
            # Anyone
            ({"type": "complaint_message", "complaint_id": "c1"}, "/complaints/c1"),
            ({"type": "password_changed"}, None),
            ({}, None),
            # An explicit link wins; one that isn't a path is ignored.
            ({"deep_link": "/wallet", "booking_id": BOOKING}, "/wallet"),
            ({"deep_link": "https://example.com", "booking_id": BOOKING}, f"/bookings/{BOOKING}"),
        ],
    )
    def test_each_notification_type(self, data: dict[str, object], link: str | None) -> None:
        assert deep_link_for(data) == link


def _preferences(**switches: bool) -> NotificationPreference:
    values = {
        "push_enabled": True,
        "sms_enabled": True,
        "email_enabled": True,
        "booking_updates_enabled": True,
        "payment_enabled": True,
        "promotional_opt_in": False,
    }
    values.update(switches)
    return NotificationPreference(user_id=uuid.uuid4(), **values)


class TestDelivery:
    def test_channel_and_topic_must_both_be_on(self) -> None:
        on = _preferences()
        assert delivers(on, NotificationTopic.BOOKING_UPDATES, "sms")
        assert not delivers(
            _preferences(sms_enabled=False), NotificationTopic.BOOKING_UPDATES, "sms"
        )
        assert delivers(_preferences(sms_enabled=False), NotificationTopic.BOOKING_UPDATES, "push")
        no_payments = _preferences(payment_enabled=False)
        assert not any(
            delivers(no_payments, NotificationTopic.PAYMENT, c) for c in ("push", "sms", "email")
        )
        assert delivers(no_payments, NotificationTopic.BOOKING_UPDATES, "push")

    def test_promotions_follow_the_opt_in(self) -> None:
        assert not delivers(_preferences(), NotificationTopic.PROMOTIONS, "push")
        assert delivers(_preferences(promotional_opt_in=True), NotificationTopic.PROMOTIONS, "push")

    def test_safety_and_account_ignore_every_switch(self) -> None:
        off = _preferences(
            push_enabled=False,
            sms_enabled=False,
            email_enabled=False,
            booking_updates_enabled=False,
            payment_enabled=False,
        )
        for topic in (NotificationTopic.SAFETY, NotificationTopic.ACCOUNT):
            assert all(delivers(off, topic, c) for c in ("push", "sms", "email"))

    def test_without_saved_preferences_the_defaults_apply(self) -> None:
        assert delivers(None, NotificationTopic.BOOKING_UPDATES, "sms")
        assert delivers(None, NotificationTopic.PAYMENT, "email")
        assert not delivers(None, NotificationTopic.PROMOTIONS, "push")

    def test_each_topic_has_its_older_category(self) -> None:
        assert category_for(NotificationTopic.SAFETY) == NotificationCategory.SAFETY
        assert category_for(NotificationTopic.PROMOTIONS) == NotificationCategory.PROMOTIONAL
        for topic in (
            NotificationTopic.BOOKING_UPDATES,
            NotificationTopic.PAYMENT,
            NotificationTopic.ACCOUNT,
        ):
            assert category_for(topic) == NotificationCategory.TRANSACTIONAL


class TestPreferencesRequest:
    def test_safety_and_account_cannot_be_turned_off(self) -> None:
        for field in ("safety_enabled", "account_enabled"):
            with pytest.raises(ValidationError, match="can't be turned off"):
                NotificationPreferencesUpdateRequest.model_validate({field: False})
            assert NotificationPreferencesUpdateRequest.model_validate({field: True})

    def test_promotions_map_to_the_stored_opt_in(self) -> None:
        request = NotificationPreferencesUpdateRequest(
            promotions_enabled=True, booking_updates_enabled=False, safety_enabled=True
        )
        assert request.stored_fields() == {
            "promotional_opt_in": True,
            "booking_updates_enabled": False,
        }
        old_name = NotificationPreferencesUpdateRequest(promotional_opt_in=True)
        assert old_name.stored_fields() == {"promotional_opt_in": True}

    def test_the_two_promotions_names_must_agree(self) -> None:
        with pytest.raises(ValidationError, match="disagree"):
            NotificationPreferencesUpdateRequest(promotions_enabled=True, promotional_opt_in=False)
        assert NotificationPreferencesUpdateRequest(
            promotions_enabled=True, promotional_opt_in=True
        )


class TestFavouritePlaceRequests:
    def test_a_stop_a_point_or_both(self) -> None:
        stop = uuid.uuid4()
        assert FavouritePlaceCreateRequest(kind=FavouritePlaceKind.HOME, stop_id=stop)
        assert FavouritePlaceCreateRequest(
            kind=FavouritePlaceKind.WORK, latitude=5.6, longitude=-0.18
        )
        assert FavouritePlaceCreateRequest(
            kind=FavouritePlaceKind.HOME, stop_id=stop, latitude=5.6, longitude=-0.18
        )
        with pytest.raises(ValidationError, match="stop_id, or a latitude"):
            FavouritePlaceCreateRequest(kind=FavouritePlaceKind.HOME)
        with pytest.raises(ValidationError, match="together"):
            FavouritePlaceCreateRequest(kind=FavouritePlaceKind.HOME, latitude=5.6)
        with pytest.raises(ValidationError):
            FavouritePlaceCreateRequest(kind=FavouritePlaceKind.HOME, latitude=91, longitude=0)

    def test_a_custom_place_needs_a_label(self) -> None:
        with pytest.raises(ValidationError, match="needs a label"):
            FavouritePlaceCreateRequest(
                kind=FavouritePlaceKind.CUSTOM, stop_id=uuid.uuid4(), label=" "
            )
        assert (
            FavouritePlaceCreateRequest(
                kind=FavouritePlaceKind.CUSTOM, stop_id=uuid.uuid4(), label="Gym"
            ).label
            == "Gym"
        )

    def test_an_update_moves_only_when_a_location_field_is_sent(self) -> None:
        assert not FavouritePlaceUpdateRequest(label="Mum's").moves
        assert FavouritePlaceUpdateRequest(latitude=5.6, longitude=-0.2).moves
        with pytest.raises(ValidationError, match="together"):
            FavouritePlaceUpdateRequest(longitude=-0.2)


class TestEmailChangeCodesStayOffThePublicEndpoints:
    def test_verify_and_resend_refuse_the_email_change_purpose(self) -> None:
        with pytest.raises(ValidationError, match="change-email"):
            VerifyOtpRequest(target="a@gmail.com", purpose="email_change", code="123456")
        with pytest.raises(ValidationError, match="change-email"):
            ResendOtpRequest(target="a@gmail.com", purpose="email_change")
        assert VerifyOtpRequest(target="a@gmail.com", purpose="registration", code="123456")
