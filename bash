mkdir -p ~/local-races-mvp/public
cd ~/local-races-mvp

cat > package.json <<'EOF'
{
  "name": "local-races-mvp",
  "version": "0.1.0",
  "description": "MVP to find local road races near you (Eventbrite-backed + mock fallback)",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "start:dev": "nodemon server.js"
  },
  "keywords": ["races","events","eventbrite","geolocation","leaflet"],
  "author": "github:copilot",
  "license": "MIT",
  "dependencies": {
    "cors": "^2.8.5",
    "dotenv": "^16.0.0",
    "express": "^4.18.2",
    "node-fetch": "^2.6.7"
  },
  "devDependencies": {
    "nodemon": "^2.0.22"
  }
}
EOF

cat > .env.example <<'EOF'
# Optional: Eventbrite API token. If you have one, set it here (or in your environment) to fetch real events.
# Create a personal token at: https://www.eventbrite.com/platform/api-keys
EVENTBRITE_TOKEN=
# Port for the server
PORT=3000
EOF

cat > .env <<'EOF'
EVENTBRITE_TOKEN=
PORT=3000
EOF

cat > server.js <<'EOF'
const express = require('express');
const fetch = require('node-fetch');
const dotenv = require('dotenv');
const cors = require('cors');
const path = require('path');
const mockRaces = require('./mock_races.json');

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

// Serve static frontend
app.use(express.static(path.join(__dirname, 'public')));

/**
 * Normalize Eventbrite event to our shape
 * shape: { id, name, start_time, url, venue_name, address, latitude, longitude }
 */
function normalizeEventbriteEvent(ev) {
  const venue = ev.venue || {};
  const address = venue.address || {};
  return {
    id: ev.id,
    name: ev.name && ev.name.text ? ev.name.text : ev.name,
    start_time: ev.start && ev.start.local ? ev.start.local : ev.start,
    url: ev.url,
    venue_name: venue.name || '',
    address: [address.address_1, address.address_2, address.city, address.region, address.postal_code]
      .filter(Boolean)
      .join(', '),
    latitude: venue.latitude ? parseFloat(venue.latitude) : null,
    longitude: venue.longitude ? parseFloat(venue.longitude) : null,
    source: 'eventbrite'
  };
}

// GET /api/races?lat=..&lon=..&radius_km=..&q=run
app.get('/api/races', async (req, res) => {
  const lat = parseFloat(req.query.lat);
  const lon = parseFloat(req.query.lon);
  const radius_km = req.query.radius_km || '10';
  const q = req.query.q || 'run OR race OR 5k OR 10k OR half marathon';

  if (isNaN(lat) || isNaN(lon)) {
    // Return mock data if location not provided or invalid
    return res.json({
      source: 'mock',
      events: mockRaces
    });
  }

  const token = process.env.EVENTBRITE_TOKEN;
  if (!token) {
    // Fallback: return mock data
    return res.json({
      source: 'mock',
      events: mockRaces
    });
  }

  try {
    const within = `${radius_km}km`;
    const url = `https://www.eventbriteapi.com/v3/events/search/?q=${encodeURIComponent(q)}&location.latitude=${lat}&location.longitude=${lon}&location.within=${within}&expand=venue&sort_by=date`;
    const resp = await fetch(url, {
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    });

    if (!resp.ok) {
      const text = await resp.text();
      return res.status(resp.status).json({ error: 'Eventbrite error', details: text });
    }

    const data = await resp.json();
    const events = (data.events || [])
      .map(normalizeEventbriteEvent)
      .filter(e => e.latitude && e.longitude);

    return res.json({
      source: 'eventbrite',
      pagination: data.pagination || {},
      events
    });
  } catch (err) {
    console.error('Error fetching Eventbrite:', err);
    res.status(500).json({ error: 'server_error', details: err.message });
  }
});

// Fallback route for unhandled requests — serve the frontend
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`local-races-mvp listening on http://localhost:${PORT}`);
});
EOF

cat > mock_races.json <<'EOF'
[
  {
    "id": "mock-1",
    "name": "Downtown 5K Fun Run",
    "start_time": "2025-06-14T09:00:00",
    "url": "https://example.com/races/downtown-5k",
    "venue_name": "Downtown Park",
    "address": "123 Park Ave, YourCity, ST 12345",
    "latitude": 40.7128,
    "longitude": -74.0060,
    "source": "mock"
  },
  {
    "id": "mock-2",
    "name": "Riverside Half Marathon",
    "start_time": "2025-07-20T07:00:00",
    "url": "https://example.com/races/riverside-half",
    "venue_name": "Riverside Trailhead",
    "address": "456 River Rd, YourCity, ST 12345",
    "latitude": 40.7158,
    "longitude": -74.0150,
    "source": "mock"
  },
  {
    "id": "mock-3",
    "name": "Neighborhood 10K",
    "start_time": "2025-08-09T08:00:00",
    "url": "https://example.com/races/neighborhood-10k",
    "venue_name": "Neighborhood Center",
    "address": "789 Community Ln, YourCity, ST 12345",
    "latitude": 40.7090,
    "longitude": -74.0005,
    "source": "mock"
  }
]
EOF

cat > README.md <<'EOF'
# Local Races MVP

Tiny full-stack app that finds local road races near you using the Eventbrite API (if you provide a token) or mock data otherwise.

Features:
- Use your browser's geolocation to find your coordinates
- Query an Express backend for nearby events
- Map display via Leaflet + list view
- Simple, easily-extendable codebase

Setup
1. Clone or copy files into a directory.
2. Install dependencies:
