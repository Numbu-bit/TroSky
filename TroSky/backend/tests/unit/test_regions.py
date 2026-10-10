"""Where passengers may sign up from: Ghana, border towns included."""

from __future__ import annotations

import pytest
from pydantic import ValidationError

from app.core.config import Settings
from app.utilities.regions import country_at, country_names

GHANA = frozenset({"GH"})

IN_GHANA = {
    "Accra": (5.6037, -0.1870),
    "Kumasi": (6.6885, -1.6244),
    "Tamale": (9.4008, -0.8393),
    "Takoradi": (4.8845, -1.7554),
    "Ho": (6.6008, 0.4713),
    "Wa": (10.0601, -2.5099),
    # On the borders: these must never be turned away.
    "Aflao": (6.1167, 1.1917),
    "Paga": (10.9853, -1.1129),
    "Bawku": (11.0616, -0.2417),
    "Elubo": (5.2833, -2.7667),
    "Half Assini": (5.0517, -2.8796),
    "Hamile": (10.99, -2.60),
    "Wli": (7.12, 0.59),
}

ABROAD = {
    "Abidjan": (5.36, -4.01),
    "Ouagadougou": (12.37, -1.52),
    "Lagos": (6.52, 3.38),
    "Cotonou": (6.37, 2.39),
    "Kara": (9.55, 1.19),
    "London": (51.5, -0.13),
}


@pytest.mark.parametrize("town", sorted(IN_GHANA))
def test_towns_in_ghana_are_in_ghana(town: str) -> None:
    latitude, longitude = IN_GHANA[town]
    assert country_at(latitude, longitude, GHANA) == "GH"


@pytest.mark.parametrize("place", sorted(ABROAD))
def test_places_abroad_are_not(place: str) -> None:
    latitude, longitude = ABROAD[place]
    assert country_at(latitude, longitude, GHANA) is None


def test_no_countries_means_nowhere() -> None:
    assert country_at(5.6037, -0.1870, frozenset()) is None


def test_countries_are_named_for_messages() -> None:
    assert country_names(GHANA) == "Ghana"


def test_a_country_without_an_outline_is_refused_at_startup() -> None:
    with pytest.raises(ValidationError, match="without an outline"):
        Settings.model_validate(
            {
                "SECRET_KEY": "x" * 32,
                "JWT_SECRET_KEY": "y" * 32,
                "PAYMENTS_WEBHOOK_SIGNING_SECRET": "z" * 32,
                "TICKET_QR_SIGNING_SECRET": "w" * 32,
                "PASSENGER_SIGNUP_COUNTRIES": "GH,ZZ",
            }
        )


def test_settings_parse_the_countries() -> None:
    settings = Settings.model_validate(
        {
            "SECRET_KEY": "x" * 32,
            "JWT_SECRET_KEY": "y" * 32,
            "PAYMENTS_WEBHOOK_SIGNING_SECRET": "z" * 32,
            "TICKET_QR_SIGNING_SECRET": "w" * 32,
            "PASSENGER_SIGNUP_COUNTRIES": " gh ",
        }
    )
    assert settings.passenger_signup_countries == GHANA
