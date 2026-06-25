-- Plant Journal — seed data
-- Auto-runs on first docker-compose up via docker-entrypoint-initdb.d

CREATE TABLE IF NOT EXISTS plants (
  id         SERIAL PRIMARY KEY,
  name       VARCHAR(120) NOT NULL,
  latin_name VARCHAR(120),
  tag        VARCHAR(40)  NOT NULL DEFAULT 'flower',
  notes      TEXT,
  image_url  TEXT
);

INSERT INTO plants (name, latin_name, tag, notes, image_url) VALUES
(
  'Lavender',
  'Lavandula angustifolia',
  'herb',
  'Purple flowering herb with a calming scent. Grows well in sunny, dry spots. Blooms June–August. Great for attracting bees.',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7b/Lavendelfeld.jpg/1280px-Lavendelfeld.jpg'
),
(
  'Bird of Paradise',
  'Strelitzia reginae',
  'flower',
  'Striking orange and blue flower that looks like a tropical bird in flight. Needs full sun and warm temperatures. Blooms winter to spring.',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/6/60/Strelitzia_reginae_-_flower.jpg/800px-Strelitzia_reginae_-_flower.jpg'
),
(
  'Monstera',
  'Monstera deliciosa',
  'shrub',
  'Iconic split-leaf tropical plant. Perfect indoors in indirect light. Water once a week. My friends say this one is nearly impossible to kill.',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/6/6d/Monstera_deliciosa_-_2.jpg/800px-Monstera_deliciosa_-_2.jpg'
),
(
  'Cherry Blossom',
  'Prunus serrulata',
  'tree',
  'Japanese flowering cherry. Blooms for just 1–2 weeks in spring with stunning pink flowers. Symbolises the fleeting nature of life.',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/2/22/FlowersOfJapan.jpg/1280px-FlowersOfJapan.jpg'
),
(
  'Basil',
  'Ocimum basilicum',
  'herb',
  'Essential kitchen herb with a sweet, peppery aroma. Grows fast in warm weather. Pinch the flowers off to keep leaves coming. Hates cold.',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/9/90/Basil-Basilico-Ocimum_basilicum-albahaca.jpg/1280px-Basil-Basilico-Ocimum_basilicum-albahaca.jpg'
),
(
  'Sunflower',
  'Helianthus annuus',
  'flower',
  'Tall, cheerful annual that tracks the sun when young. Can grow up to 3 metres. Seeds are edible and loved by birds. Easy to grow from seed.',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/4/40/Sunflower_sky_backdrop.jpg/800px-Sunflower_sky_backdrop.jpg'
);

