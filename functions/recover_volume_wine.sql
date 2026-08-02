BEGIN;

-- Recover "Volume B Wine, Cocktails & Grills" (never migrated from Firestore)
INSERT INTO businesses (name, business_type, owner_id, address, phone, email, currency, is_active, legacy_firestore_id, created_at, business_class)
VALUES ('Volume B Wine, Cocktails & Grills', 'retail', '0068e472-0d52-5ee3-a001-d6d42e4fc5a7', 'old airport road, besides mopol 8', '2348034568062', 'volumeb@gmail.com', 'NGN', true, 'bus_1785475772188', '2026-07-31T05:29:32.000Z', 'tier1')
RETURNING id \gset new_biz_

-- Link the existing owner to the recovered business
INSERT INTO business_members (user_id, business_id, role, is_owner, is_active)
VALUES ('0068e472-0d52-5ee3-a001-d6d42e4fc5a7', :'new_biz_id', 'owner', true, true);

-- Recover all 25 products
INSERT INTO inventory (business_id, name, sku, barcode, category, description, unit_price, cost_price, quantity, unit, is_active, legacy_firestore_id, created_at) VALUES (:'new_biz_id', 'budwiser', 'SKU-00002', NULL, 'Beverages', NULL, 1100, 812, 48, 'pcs', true, '2rDPwmCUnfFzRYI0ON85', '2026-07-31T21:01:48.000Z');
INSERT INTO inventory (business_id, name, sku, barcode, category, description, unit_price, cost_price, quantity, unit, is_active, legacy_firestore_id, created_at) VALUES (:'new_biz_id', 'Goldberg', 'SKU-00003', NULL, 'Beverages', NULL, 1000, 646, 48, 'pcs', true, '38UBJQtoCFnVAYrdOi8x', '2026-07-31T21:05:25.000Z');
INSERT INTO inventory (business_id, name, sku, barcode, category, description, unit_price, cost_price, quantity, unit, is_active, legacy_firestore_id, created_at) VALUES (:'new_biz_id', 'bar man wisky', 'SKU-00017', NULL, 'Beverages', NULL, 4500, 3085, 6, 'pcs', true, '3OLImhs4OE0El528oA3W', '2026-07-31T22:01:33.000Z');
INSERT INTO inventory (business_id, name, sku, barcode, category, description, unit_price, cost_price, quantity, unit, is_active, legacy_firestore_id, created_at) VALUES (:'new_biz_id', 'big ben', 'SKU-00019', NULL, 'Beverages', NULL, 3500, 2333, 6, 'pcs', true, '3W01Vok2xrHc8MEpJzie', '2026-07-31T22:03:28.000Z');
INSERT INTO inventory (business_id, name, sku, barcode, category, description, unit_price, cost_price, quantity, unit, is_active, legacy_firestore_id, created_at) VALUES (:'new_biz_id', 'veleta can', 'SKU-00008', NULL, 'Beverages', NULL, 1500, 959, 24, 'pcs', true, '54Rj6jCf7XScijDPNBaA', '2026-07-31T21:11:49.000Z');
INSERT INTO inventory (business_id, name, sku, barcode, category, description, unit_price, cost_price, quantity, unit, is_active, legacy_firestore_id, created_at) VALUES (:'new_biz_id', '8pm medium', 'SKU-00024', NULL, 'Beverages', NULL, 8000, 6000, 1, 'pcs', true, '57dYwAQLhU8fLaEYimSh', '2026-07-31T22:58:46.000Z');
INSERT INTO inventory (business_id, name, sku, barcode, category, description, unit_price, cost_price, quantity, unit, is_active, legacy_firestore_id, created_at) VALUES (:'new_biz_id', 'smirnoff X1', 'SKU-00018', NULL, 'Beverages', NULL, 6000, 5208, 6, 'pcs', true, '7KmRr5msb0s1VetwGegM', '2026-07-31T22:02:41.000Z');
INSERT INTO inventory (business_id, name, sku, barcode, category, description, unit_price, cost_price, quantity, unit, is_active, legacy_firestore_id, created_at) VALUES (:'new_biz_id', 'teezers', 'SKU-00013', NULL, 'Beverages', NULL, 600, 458, 24, 'pcs', true, 'CKUSAeeivY3WoCse5JlU', '2026-07-31T21:36:13.000Z');
INSERT INTO inventory (business_id, name, sku, barcode, category, description, unit_price, cost_price, quantity, unit, is_active, legacy_firestore_id, created_at) VALUES (:'new_biz_id', 'jack william', 'SKU-00023', NULL, 'Beverages', NULL, 8500, 6000, 12, 'pcs', true, 'Iz1qBu0YAWD9w9qLERJK', '2026-07-31T22:57:36.000Z');
INSERT INTO inventory (business_id, name, sku, barcode, category, description, unit_price, cost_price, quantity, unit, is_active, legacy_firestore_id, created_at) VALUES (:'new_biz_id', 'black and white', 'SKU-00020', NULL, 'Beverages', NULL, 15000, 11666, 3, 'pcs', true, 'LFmOyi7GEKFZYLZBzIkz', '2026-07-31T22:04:14.000Z');
INSERT INTO inventory (business_id, name, sku, barcode, category, description, unit_price, cost_price, quantity, unit, is_active, legacy_firestore_id, created_at) VALUES (:'new_biz_id', 'captian morgan', 'SKU-00025', NULL, 'Beverages', NULL, 9000, 7000, 2, 'pcs', true, 'MzcF76Pop2fIWeEL7tTN', '2026-07-31T23:00:19.000Z');
INSERT INTO inventory (business_id, name, sku, barcode, category, description, unit_price, cost_price, quantity, unit, is_active, legacy_firestore_id, created_at) VALUES (:'new_biz_id', 'bullet', 'SKU-00007', NULL, 'Beverages', NULL, 1500, 1188, 48, 'pcs', true, 'Qb2nuI3NLOYJxOBBeuvW', '2026-07-31T21:10:44.000Z');
INSERT INTO inventory (business_id, name, sku, barcode, category, description, unit_price, cost_price, quantity, unit, is_active, legacy_firestore_id, created_at) VALUES (:'new_biz_id', 'maltina  can', 'SKU-00009', NULL, 'Beverages', NULL, 700, 532, 48, 'pcs', true, 'RGjWOeambHxJYcjHk1q9', '2026-07-31T21:13:01.000Z');
INSERT INTO inventory (business_id, name, sku, barcode, category, description, unit_price, cost_price, quantity, unit, is_active, legacy_firestore_id, created_at) VALUES (:'new_biz_id', '8pm big', 'SKU-00022', NULL, 'Beverages', NULL, 8500, 6500, 1, 'pcs', true, 'RLBHVdtkSOuJRdTeQTzJ', '2026-07-31T22:49:33.000Z');
INSERT INTO inventory (business_id, name, sku, barcode, category, description, unit_price, cost_price, quantity, unit, is_active, legacy_firestore_id, created_at) VALUES (:'new_biz_id', 'origin palm', 'SKU-00014', NULL, 'Beverages', NULL, 1000, 866, 24, 'pcs', true, 'ZgyDk6ufzYIBvHQqueOo', '2026-07-31T21:38:10.000Z');
INSERT INTO inventory (business_id, name, sku, barcode, category, description, unit_price, cost_price, quantity, unit, is_active, legacy_firestore_id, created_at) VALUES (:'new_biz_id', 'Smirnoff white', 'SKU-00004', NULL, 'Beverages', NULL, 1100, 933, 24, 'pcs', true, 'aZHRBrJS8OjBcW2RNlJc', '2026-07-31T21:07:08.000Z');
INSERT INTO inventory (business_id, name, sku, barcode, category, description, unit_price, cost_price, quantity, unit, is_active, legacy_firestore_id, created_at) VALUES (:'new_biz_id', 'igboya', 'SKU-00012', NULL, 'Beverages', NULL, 1000, 729, 12, 'pcs', true, 'bTkParsgxBEzIwdfGTAU', '2026-07-31T21:35:19.000Z');
INSERT INTO inventory (business_id, name, sku, barcode, category, description, unit_price, cost_price, quantity, unit, is_active, legacy_firestore_id, created_at) VALUES (:'new_biz_id', 'malta guiness', 'SKU-00001', NULL, 'Beverages', NULL, 700, 500, 48, 'pcs', true, 'c9HjhH1XCcUPqOhUXUkr', '2026-07-31T21:00:53.000Z');
INSERT INTO inventory (business_id, name, sku, barcode, category, description, unit_price, cost_price, quantity, unit, is_active, legacy_firestore_id, created_at) VALUES (:'new_biz_id', 'legend can', 'SKU-00015', NULL, 'Beverages', NULL, 1000, 887, 24, 'pcs', true, 'eAM7b6aGvmU1qHe9JoYj', '2026-07-31T21:57:34.000Z');
INSERT INTO inventory (business_id, name, sku, barcode, category, description, unit_price, cost_price, quantity, unit, is_active, legacy_firestore_id, created_at) VALUES (:'new_biz_id', 'desperado', 'SKU-00010', NULL, 'Beverages', NULL, 1200, 937, 48, 'pcs', true, 'oDGTH4YD8jatq7WUOzNQ', '2026-07-31T21:14:19.000Z');
INSERT INTO inventory (business_id, name, sku, barcode, category, description, unit_price, cost_price, quantity, unit, is_active, legacy_firestore_id, created_at) VALUES (:'new_biz_id', 'heineken small', 'SKU-00006', NULL, 'Beverages', NULL, 1000, 758, 48, 'pcs', true, 'qyjiEuR8ccoJgqwlYeu9', '2026-07-31T21:09:17.000Z');
INSERT INTO inventory (business_id, name, sku, barcode, category, description, unit_price, cost_price, quantity, unit, is_active, legacy_firestore_id, created_at) VALUES (:'new_biz_id', 'origin bitters big', 'SKU-00016', NULL, 'Beverages', NULL, 4500, 3250, 6, 'pcs', true, 'skRVa1db51jpGfrmzFBB', '2026-07-31T21:59:22.000Z');
INSERT INTO inventory (business_id, name, sku, barcode, category, description, unit_price, cost_price, quantity, unit, is_active, legacy_firestore_id, created_at) VALUES (:'new_biz_id', 'double black', 'SKU-00011', NULL, 'Beverages', NULL, 1500, 937, 48, 'pcs', true, 'tLWdhdREB1nDzmA9dCmU', '2026-07-31T21:15:20.000Z');
INSERT INTO inventory (business_id, name, sku, barcode, category, description, unit_price, cost_price, quantity, unit, is_active, legacy_firestore_id, created_at) VALUES (:'new_biz_id', 'korean rasp berry', 'SKU-00021', NULL, 'Beverages', NULL, 9000, 7500, 3, 'pcs', true, 'u8Y6DlBsTrq0NYYknlR1', '2026-07-31T22:06:17.000Z');
INSERT INTO inventory (business_id, name, sku, barcode, category, description, unit_price, cost_price, quantity, unit, is_active, legacy_firestore_id, created_at) VALUES (:'new_biz_id', 'monster', 'SKU-00005', NULL, 'Beverages', NULL, 1200, 895, 24, 'pcs', true, 'zuoUhIr8MMXbCMSJIJxV', '2026-07-31T21:07:46.000Z');

-- The owner's current_business_id may point at one of the empty
-- duplicates (that FK has no ON DELETE action, unlike business_members'
-- cascade) - repoint it at the recovered business first so the deletes
-- below don't get blocked.
UPDATE profiles SET current_business_id = :'new_biz_id' WHERE current_business_id IN ('b7ba032e-706f-4bad-8e44-818843faeebd', '9d0d7856-641e-4708-875f-ceeef93ffdf8');

-- Remove the two empty duplicate businesses created today while the owner
-- was trying to recover the missing business by hand (business_members rows
-- cascade-delete via FK).
DELETE FROM businesses WHERE id = 'b7ba032e-706f-4bad-8e44-818843faeebd';
DELETE FROM businesses WHERE id = '9d0d7856-641e-4708-875f-ceeef93ffdf8';

COMMIT;