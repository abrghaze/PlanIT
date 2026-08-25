from app.infrastructure.security.passwords import PasswordService


def test_passwords_use_argon2id_and_verify_without_plaintext_storage() -> None:
    service = PasswordService()

    encoded = service.hash("correct horse battery staple")

    assert encoded.startswith("$argon2id$")
    assert "correct horse battery staple" not in encoded
    assert service.verify(encoded, "correct horse battery staple")
    assert not service.verify(encoded, "wrong password")
    assert not service.verify(None, "correct horse battery staple")
