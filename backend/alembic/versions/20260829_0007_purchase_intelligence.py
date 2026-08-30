"""Activate Milestone 5 purchase intelligence and private media.

Revision ID: 20260829_0007
Revises: 20260829_0006
Create Date: 2026-08-29
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260829_0007"
down_revision: str | None = "20260829_0006"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

MONEY = sa.Numeric(19, 4)
QUANTITY = sa.Numeric(19, 6)


def _timestamps() -> list[sa.Column[object]]:
    return [
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
    ]


def upgrade() -> None:
    op.create_table(
        "merchants",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(160), nullable=False),
        sa.Column("normalized_name", sa.String(160), nullable=False),
        sa.Column("category_id", sa.Uuid(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("archived_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        *_timestamps(),
        sa.CheckConstraint(
            "length(btrim(name)) BETWEEN 1 AND 160", name=op.f("ck_merchants_name_not_blank")
        ),
        sa.CheckConstraint("version > 0", name=op.f("ck_merchants_version_positive")),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], name=op.f("fk_merchants_user_id_users"), ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["category_id", "user_id"],
            ["categories.id", "categories.user_id"],
            name="fk_merchants_category_owner",
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_merchants")),
        sa.UniqueConstraint("id", "user_id", name=op.f("uq_merchants_id_user")),
    )
    op.create_index(
        "uq_merchants_user_active_normalized_name",
        "merchants",
        ["user_id", "normalized_name"],
        unique=True,
        postgresql_where=sa.text("archived_at IS NULL"),
    )
    op.create_index("ix_merchants_user_name", "merchants", ["user_id", "normalized_name", "id"])

    op.create_table(
        "merchant_locations",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("merchant_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(160), nullable=False),
        sa.Column("normalized_name", sa.String(160), nullable=False),
        sa.Column("location_text", sa.String(500), nullable=True),
        sa.Column("latitude", sa.Numeric(9, 6), nullable=True),
        sa.Column("longitude", sa.Numeric(9, 6), nullable=True),
        sa.Column("archived_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        *_timestamps(),
        sa.CheckConstraint(
            "length(btrim(name)) BETWEEN 1 AND 160",
            name=op.f("ck_merchant_locations_name_not_blank"),
        ),
        sa.CheckConstraint(
            "latitude IS NULL OR latitude BETWEEN -90 AND 90",
            name=op.f("ck_merchant_locations_latitude_valid"),
        ),
        sa.CheckConstraint(
            "longitude IS NULL OR longitude BETWEEN -180 AND 180",
            name=op.f("ck_merchant_locations_longitude_valid"),
        ),
        sa.CheckConstraint("version > 0", name=op.f("ck_merchant_locations_version_positive")),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name=op.f("fk_merchant_locations_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["merchant_id", "user_id"],
            ["merchants.id", "merchants.user_id"],
            name="fk_merchant_locations_merchant_owner",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_merchant_locations")),
        sa.UniqueConstraint("id", "user_id", name=op.f("uq_merchant_locations_id_user")),
        sa.UniqueConstraint(
            "id", "user_id", "merchant_id", name=op.f("uq_merchant_locations_id_user_merchant")
        ),
    )
    op.create_index(
        "uq_merchant_locations_merchant_active_name",
        "merchant_locations",
        ["merchant_id", "normalized_name"],
        unique=True,
        postgresql_where=sa.text("archived_at IS NULL"),
    )
    op.create_index(
        "ix_merchant_locations_user_merchant",
        "merchant_locations",
        ["user_id", "merchant_id", "id"],
    )

    op.create_table(
        "products",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("parent_product_id", sa.Uuid(), nullable=True),
        sa.Column("name", sa.String(160), nullable=False),
        sa.Column("normalized_name", sa.String(160), nullable=False),
        sa.Column("brand", sa.String(120), nullable=True),
        sa.Column("normalized_brand", sa.String(120), nullable=False, server_default=""),
        sa.Column("variant_label", sa.String(120), nullable=True),
        sa.Column("normalized_variant", sa.String(120), nullable=False, server_default=""),
        sa.Column("size_value", QUANTITY, nullable=True),
        sa.Column("size_unit", sa.String(12), nullable=True),
        sa.Column("barcode", sa.String(80), nullable=True),
        sa.Column("category_id", sa.Uuid(), nullable=True),
        sa.Column("default_merchant_id", sa.Uuid(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("archived_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        *_timestamps(),
        sa.CheckConstraint(
            "length(btrim(name)) BETWEEN 1 AND 160", name=op.f("ck_products_name_not_blank")
        ),
        sa.CheckConstraint(
            "parent_product_id IS NULL OR parent_product_id <> id",
            name=op.f("ck_products_parent_not_self"),
        ),
        sa.CheckConstraint(
            "size_value IS NULL OR size_value > 0", name=op.f("ck_products_size_positive")
        ),
        sa.CheckConstraint(
            "(size_value IS NULL) = (size_unit IS NULL)",
            name=op.f("ck_products_size_value_unit_coherent"),
        ),
        sa.CheckConstraint(
            "size_unit IS NULL OR size_unit IN ('COUNT','G','KG','ML','L')",
            name=op.f("ck_products_size_unit_valid"),
        ),
        sa.CheckConstraint("version > 0", name=op.f("ck_products_version_positive")),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], name=op.f("fk_products_user_id_users"), ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["parent_product_id", "user_id"],
            ["products.id", "products.user_id"],
            name="fk_products_parent_owner",
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["category_id", "user_id"],
            ["categories.id", "categories.user_id"],
            name="fk_products_category_owner",
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["default_merchant_id", "user_id"],
            ["merchants.id", "merchants.user_id"],
            name="fk_products_default_merchant_owner",
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_products")),
        sa.UniqueConstraint("id", "user_id", name=op.f("uq_products_id_user")),
    )
    op.create_index(
        "uq_products_user_active_identity",
        "products",
        ["user_id", "normalized_name", "normalized_brand", "normalized_variant"],
        unique=True,
        postgresql_where=sa.text("archived_at IS NULL"),
    )
    op.create_index(
        "uq_products_user_barcode",
        "products",
        ["user_id", "barcode"],
        unique=True,
        postgresql_where=sa.text("barcode IS NOT NULL AND archived_at IS NULL"),
    )
    op.create_index("ix_products_user_name", "products", ["user_id", "normalized_name", "id"])
    op.create_index("ix_products_parent", "products", ["parent_product_id", "id"])

    op.add_column("transactions", sa.Column("merchant_id", sa.Uuid(), nullable=True))
    op.add_column("transactions", sa.Column("merchant_location_id", sa.Uuid(), nullable=True))
    op.create_foreign_key(
        "fk_transactions_merchant_owner",
        "transactions",
        "merchants",
        ["merchant_id", "user_id"],
        ["id", "user_id"],
        ondelete="RESTRICT",
    )
    op.create_foreign_key(
        "fk_transactions_merchant_location_owner",
        "transactions",
        "merchant_locations",
        ["merchant_location_id", "user_id", "merchant_id"],
        ["id", "user_id", "merchant_id"],
        ondelete="RESTRICT",
    )
    op.create_index(
        "ix_transactions_merchant_occurred_id", "transactions", ["merchant_id", "occurred_at", "id"]
    )
    op.create_index(
        "ix_transactions_merchant_location_occurred",
        "transactions",
        ["merchant_location_id", "occurred_at", "id"],
    )

    op.create_table(
        "transaction_items",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("transaction_id", sa.Uuid(), nullable=False),
        sa.Column("product_id", sa.Uuid(), nullable=True),
        sa.Column("description_snapshot", sa.String(240), nullable=False),
        sa.Column("quantity", QUANTITY, nullable=False),
        sa.Column("unit_price", MONEY, nullable=False),
        sa.Column("discount", MONEY, nullable=False, server_default="0"),
        sa.Column("line_total", MONEY, nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        *_timestamps(),
        sa.CheckConstraint(
            "length(btrim(description_snapshot)) BETWEEN 1 AND 240",
            name=op.f("ck_transaction_items_description_not_blank"),
        ),
        sa.CheckConstraint("quantity > 0", name=op.f("ck_transaction_items_quantity_positive")),
        sa.CheckConstraint(
            "unit_price >= 0", name=op.f("ck_transaction_items_unit_price_non_negative")
        ),
        sa.CheckConstraint(
            "discount >= 0", name=op.f("ck_transaction_items_discount_non_negative")
        ),
        sa.CheckConstraint(
            "line_total >= 0", name=op.f("ck_transaction_items_line_total_non_negative")
        ),
        sa.CheckConstraint(
            "line_total = round(quantity * unit_price - discount, 4)",
            name=op.f("ck_transaction_items_line_total_exact"),
        ),
        sa.CheckConstraint(
            "position >= 0", name=op.f("ck_transaction_items_position_non_negative")
        ),
        sa.ForeignKeyConstraint(
            ["transaction_id", "user_id"],
            ["transactions.id", "transactions.user_id"],
            name="fk_transaction_items_transaction_owner",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["product_id", "user_id"],
            ["products.id", "products.user_id"],
            name="fk_transaction_items_product_owner",
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_transaction_items")),
        sa.UniqueConstraint(
            "transaction_id", "position", name=op.f("uq_transaction_items_position")
        ),
    )
    op.create_index(
        "ix_transaction_items_transaction_position",
        "transaction_items",
        ["transaction_id", "position", "id"],
    )
    op.create_index(
        "ix_transaction_items_user_product",
        "transaction_items",
        ["user_id", "product_id", "transaction_id"],
    )

    op.create_table(
        "media_assets",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("kind", sa.String(24), nullable=False),
        sa.Column("status", sa.String(16), nullable=False, server_default="PENDING"),
        sa.Column("storage_key", sa.String(500), nullable=False),
        sa.Column("mime_type", sa.String(80), nullable=False),
        sa.Column("size_bytes", sa.Integer(), nullable=False),
        sa.Column("finalized_at", sa.DateTime(timezone=True), nullable=True),
        *_timestamps(),
        sa.CheckConstraint(
            "kind IN ('MERCHANT_IMAGE','PRODUCT_IMAGE','RECEIPT','PURCHASE_IMAGE')",
            name=op.f("ck_media_assets_kind_valid"),
        ),
        sa.CheckConstraint(
            "status IN ('PENDING','FINALIZED')", name=op.f("ck_media_assets_status_valid")
        ),
        sa.CheckConstraint(
            "size_bytes BETWEEN 1 AND 10485760", name=op.f("ck_media_assets_size_valid")
        ),
        sa.CheckConstraint(
            "mime_type IN ('image/jpeg','image/png','image/webp')",
            name=op.f("ck_media_assets_mime_type_valid"),
        ),
        sa.CheckConstraint(
            "(status = 'FINALIZED') = (finalized_at IS NOT NULL)",
            name=op.f("ck_media_assets_finalization_coherent"),
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name=op.f("fk_media_assets_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_media_assets")),
        sa.UniqueConstraint("storage_key", name=op.f("uq_media_assets_storage_key")),
        sa.UniqueConstraint("id", "user_id", name=op.f("uq_media_assets_id_user")),
    )
    op.create_index(
        "ix_media_assets_user_status_created", "media_assets", ["user_id", "status", "created_at"]
    )

    op.create_table(
        "entity_media",
        sa.Column("media_asset_id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("entity_type", sa.String(16), nullable=False),
        sa.Column("entity_id", sa.Uuid(), nullable=False),
        sa.Column("role", sa.String(16), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
        sa.CheckConstraint(
            "entity_type IN ('MERCHANT','PRODUCT','TRANSACTION')",
            name=op.f("ck_entity_media_entity_type_valid"),
        ),
        sa.CheckConstraint("role IN ('IMAGE','RECEIPT')", name=op.f("ck_entity_media_role_valid")),
        sa.CheckConstraint("sort_order >= 0", name=op.f("ck_entity_media_sort_order_non_negative")),
        sa.ForeignKeyConstraint(
            ["media_asset_id", "user_id"],
            ["media_assets.id", "media_assets.user_id"],
            name="fk_entity_media_asset_owner",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("media_asset_id", name=op.f("pk_entity_media")),
    )
    op.create_index(
        "ix_entity_media_entity",
        "entity_media",
        ["user_id", "entity_type", "entity_id", "sort_order"],
    )

    op.execute("""
        CREATE FUNCTION planit_validate_purchase_items() RETURNS trigger LANGUAGE plpgsql AS $$
        DECLARE tx_id uuid; tx transactions%ROWTYPE; item_sum numeric(19,4);
        BEGIN
          IF TG_TABLE_NAME='transactions' THEN
            tx_id := NEW.id;
          ELSIF TG_OP='DELETE' THEN
            tx_id := OLD.transaction_id;
          ELSE
            tx_id := NEW.transaction_id;
          END IF;
          SELECT * INTO tx FROM transactions WHERE id=tx_id;
          IF NOT FOUND THEN RETURN COALESCE(NEW, OLD); END IF;
          IF TG_TABLE_NAME='transaction_items' AND tx.status <> 'DRAFT' THEN
            RAISE EXCEPTION 'Posted purchase items are immutable' USING ERRCODE='23514', CONSTRAINT='transaction_items_posted_immutable';
          END IF;
          IF EXISTS (SELECT 1 FROM transaction_items WHERE transaction_id=tx_id) AND tx.type <> 'EXPENSE' THEN
            RAISE EXCEPTION 'Only expenses can be itemized' USING ERRCODE='23514', CONSTRAINT='transaction_items_expense_only';
          END IF;
          IF tx.status IN ('POSTED','REVERSED') AND EXISTS (SELECT 1 FROM transaction_items WHERE transaction_id=tx_id) THEN
            SELECT COALESCE(sum(line_total),0) INTO item_sum FROM transaction_items WHERE transaction_id=tx_id;
            IF item_sum <> tx.amount THEN
              RAISE EXCEPTION 'Item total does not match transaction amount' USING ERRCODE='23514', CONSTRAINT='transaction_items_total_matches';
            END IF;
          END IF;
          RETURN COALESCE(NEW, OLD);
        END $$
    """)
    op.execute(
        "CREATE CONSTRAINT TRIGGER trg_transactions_validate_purchase AFTER INSERT OR UPDATE ON transactions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION planit_validate_purchase_items()"
    )
    op.execute(
        "CREATE CONSTRAINT TRIGGER trg_transaction_items_validate AFTER INSERT OR UPDATE OR DELETE ON transaction_items DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION planit_validate_purchase_items()"
    )
    op.execute("""
        CREATE FUNCTION planit_validate_entity_media() RETURNS trigger LANGUAGE plpgsql AS $$
        DECLARE found_owner uuid;
        BEGIN
          IF NEW.entity_type='MERCHANT' THEN SELECT user_id INTO found_owner FROM merchants WHERE id=NEW.entity_id;
          ELSIF NEW.entity_type='PRODUCT' THEN SELECT user_id INTO found_owner FROM products WHERE id=NEW.entity_id;
          ELSE SELECT user_id INTO found_owner FROM transactions WHERE id=NEW.entity_id; END IF;
          IF found_owner IS NULL OR found_owner <> NEW.user_id THEN
            RAISE EXCEPTION 'Media target is unavailable' USING ERRCODE='23503', CONSTRAINT='entity_media_target_owner';
          END IF;
          IF (NEW.entity_type='TRANSACTION') <> (NEW.role='RECEIPT') THEN
            RAISE EXCEPTION 'Media role does not match target' USING ERRCODE='23514', CONSTRAINT='entity_media_role_coherent';
          END IF;
          RETURN NEW;
        END $$
    """)
    op.execute(
        "CREATE TRIGGER trg_entity_media_validate BEFORE INSERT OR UPDATE ON entity_media FOR EACH ROW EXECUTE FUNCTION planit_validate_entity_media()"
    )


def downgrade() -> None:
    connection = op.get_bind()
    populated = connection.execute(
        sa.text(
            "SELECT EXISTS(SELECT 1 FROM merchants) OR EXISTS(SELECT 1 FROM products) OR EXISTS(SELECT 1 FROM transaction_items) OR EXISTS(SELECT 1 FROM media_assets)"
        )
    ).scalar_one()
    if populated:
        raise RuntimeError(
            "Refusing to downgrade Milestone 5 while purchase or media history exists."
        )
    op.execute("DROP TRIGGER trg_entity_media_validate ON entity_media")
    op.execute("DROP FUNCTION planit_validate_entity_media()")
    op.execute("DROP TRIGGER trg_transaction_items_validate ON transaction_items")
    op.execute("DROP TRIGGER trg_transactions_validate_purchase ON transactions")
    op.execute("DROP FUNCTION planit_validate_purchase_items()")
    op.drop_table("entity_media")
    op.drop_table("media_assets")
    op.drop_table("transaction_items")
    op.drop_index("ix_transactions_merchant_location_occurred", table_name="transactions")
    op.drop_index("ix_transactions_merchant_occurred_id", table_name="transactions")
    op.drop_constraint(
        "fk_transactions_merchant_location_owner", "transactions", type_="foreignkey"
    )
    op.drop_constraint("fk_transactions_merchant_owner", "transactions", type_="foreignkey")
    op.drop_column("transactions", "merchant_location_id")
    op.drop_column("transactions", "merchant_id")
    op.drop_table("products")
    op.drop_table("merchant_locations")
    op.drop_table("merchants")
