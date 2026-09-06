from app.application.privacy import PrivacyService


def test_spreadsheet_text_neutralizes_formula_prefixes() -> None:
    for value in ("=1+1", "+cmd", "-2+3", "@SUM(A1:A2)", "\tformula", "\rformula"):
        assert PrivacyService._spreadsheet_text(value) == "'" + value


def test_spreadsheet_text_preserves_normal_values() -> None:
    assert PrivacyService._spreadsheet_text("Groceries") == "Groceries"
    assert PrivacyService._spreadsheet_text(None) == ""


def test_legacy_recurring_rule_restores_original_local_day() -> None:
    row: dict[str, object] = {
        "next_due_at": "2026-03-31T23:30:00Z",
        "timezone": "Africa/Casablanca",
    }

    assert PrivacyService._legacy_anchor_day(row) == 1


def test_legacy_transaction_item_adds_empty_package_snapshot() -> None:
    expected = {"id", "package_size_value_snapshot", "package_size_unit_snapshot"}

    upgraded = PrivacyService._upgrade_v1_row("transaction_items", {"id": "item-1"}, expected)

    assert upgraded == {
        "id": "item-1",
        "package_size_value_snapshot": None,
        "package_size_unit_snapshot": None,
    }
