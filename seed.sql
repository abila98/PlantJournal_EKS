-- Plant Journal v2 — seed data
CREATE TABLE IF NOT EXISTS plants (
  id               SERIAL PRIMARY KEY,
  name             VARCHAR(120) NOT NULL,
  latin_name       VARCHAR(120),
  tag              VARCHAR(40)  NOT NULL DEFAULT 'flower',
  bloom_seasons    TEXT[],
  sent_by          VARCHAR(80),
  spotted_at       VARCHAR(80),
  special_features TEXT[],
  water_req        VARCHAR(20),
  notes            TEXT,
  image_url        TEXT,
  created_at       TIMESTAMPTZ  DEFAULT NOW()
);

INSERT INTO plants (name, latin_name, tag, bloom_seasons, sent_by, spotted_at, special_features, water_req, notes, image_url) VALUES
(
  'Lavender',
  'Lavandula angustifolia',
  'herb',
  ARRAY['Summer'],
  'Priya',
  'garden',
  ARRAY['fragrant','attracts bees'],
  'low',
  'Purple flowering herb with a calming scent. Grows well in sunny dry spots.',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7b/Lavendelfeld.jpg/1280px-Lavendelfeld.jpg'
),
(
  'Bird of Paradise',
  'Strelitzia reginae',
  'flower',
  ARRAY['Winter','Spring'],
  'Meera',
  'park',
  ARRAY['rare'],
  'medium',
  'Striking orange and blue flower that looks like a tropical bird in flight.',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/6/60/Strelitzia_reginae_-_flower.jpg/800px-Strelitzia_reginae_-_flower.jpg'
),
(
  'Monstera',
  'Monstera deliciosa',
  'shrub',
  ARRAY[]::TEXT[],
  'Priya',
  'pot',
  ARRAY['rare'],
  'medium',
  'Iconic split-leaf tropical plant. Perfect indoors in indirect light.',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/6/6d/Monstera_deliciosa_-_2.jpg/800px-Monstera_deliciosa_-_2.jpg'
),
(
  'Cherry Blossom',
  'Prunus serrulata',
  'tree',
  ARRAY['Spring'],
  'Meera',
  'park',
  ARRAY['rare'],
  'medium',
  'Blooms for just 1-2 weeks in spring. Stunning pink flowers.',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/2/22/FlowersOfJapan.jpg/1280px-FlowersOfJapan.jpg'
),
(
  'Basil',
  'Ocimum basilicum',
  'herb',
  ARRAY['Summer'],
  'Priya',
  'pot',
  ARRAY['fragrant','edible'],
  'high',
  'Essential kitchen herb. Pinch the flowers off to keep leaves coming.',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/9/90/Basil-Basilico-Ocimum_basilicum-albahaca.jpg/1280px-Basil-Basilico-Ocimum_basilicum-albahaca.jpg'
),
(
  'Sunflower',
  'Helianthus annuus',
  'flower',
  ARRAY['Summer'],
  'Meera',
  'garden',
  ARRAY['edible','attracts bees'],
  'medium',
  'Tall cheerful annual that tracks the sun. Seeds are edible and loved by birds.',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/4/40/Sunflower_sky_backdrop.jpg/800px-Sunflower_sky_backdrop.jpg'
);

