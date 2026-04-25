# Navis Feature Roadmap

## Phase 1 — MVP (Minimum Viable Product)

Target: First TestFlight / internal release.

### Authentication
- Email + password sign-up / sign-in via Supabase Auth
- Password reset flow
- Session persistence (auto-refresh JWT)
- Profile screen with email display and sign-out

### Boat Management
- Add a boat: name, registration, type, length, home port (with map picker)
- Upload boat photo (Supabase Storage)
- Edit boat details
- Delete boat (with confirmation — cascades documents and trips)
- Boat list on home screen with summary cards

### Document Management
- Add a document to a boat: type, expiry date, photo scan, notes
- Computed status badges: OK (green), Warning (yellow, <90 days), Critical (orange, <30 days), Expired (red)
- Document list per boat, sorted by urgency
- Edit and renew documents (track renewal date, cost, provider)
- Delete documents
- Push notifications for upcoming expirations (30 days, 7 days before)
  - Go cron job checks daily and sends via Firebase Cloud Messaging
  - Notification deduplication via `notification_logs` table
- Configurable alert thresholds per document (`alert_days` array)

### Basic Logbook
- Start a new trip: select boat, departure port, crew members
- End a trip: arrival port, engine hours, fuel, notes
- Trip history list per boat (departure date, ports, distance)
- Trip detail view with all recorded data

---

## Phase 2 — Enhanced Experience

Target: Public beta release.

### Weather Integration
- Marine weather forecast for any location (Open-Meteo API)
- Current conditions: wind, waves, temperature, visibility
- 3-day hourly forecast with nautical-relevant data (wave height, wind gusts)
- Weather widget on home screen for home port
- Weather check before starting a trip

### Nautical Charts
- Interactive map using OpenSeaMap / flutter_map
- Display home port locations for all boats
- View trip tracks overlaid on the chart
- Nearby port information

### GPS Trip Recording
- Live GPS tracking during trips (10-second intervals)
- Background location capture (battery-optimized)
- Batch upload of GPS points to API (every 60 seconds)
- Trip track visualization on the map after completion
- Auto-calculated distance (from GPS track)
- Speed and heading recording at each point

### Offline Mode
- Local caching of boat and document data (Hive / Isar)
- Queue API writes when offline, sync when connectivity returns
- Visual indicator for offline/sync status
- Document photos available offline after first view

---

## Phase 3 — Social and Growth

Target: Public launch + monetization.

### Events
- Browse upcoming nautical events (regattas, exhibitions, courses, meetups)
- Filter by type, location radius, and date
- Featured events highlighted in the feed
- Mark interest in events (visible count for organizers)
- Event detail view with registration and document links

### Social Features
- Public trip sharing (generate a shareable link with map)
- Trip statistics: total distance sailed, hours at sea, ports visited
- Annual sailing summary (year in review)
- Boat profile page (shareable)

### Premium Subscription (Future)
- Free tier: 1 boat, basic document tracking
- Premium tier: unlimited boats, advanced analytics, priority notifications, export logbook to PDF
- Subscription via App Store / Google Play in-app purchase
- Server-side entitlement validation

### Admin / Organizer Panel (Future)
- Web dashboard for event organizers to create and manage events
- Analytics: views, interest count, demographics
- Push event updates to interested users

---

## Technical Debt and Infrastructure (Ongoing)

- Comprehensive test coverage (Go: 80%+, Flutter: widget + unit tests)
- CI/CD pipeline: automated builds, test runs, lint checks
- Staging environment with isolated Supabase project
- Error monitoring (Sentry)
- Analytics (PostHog or Mixpanel)
- App Store submission assets and metadata
- Privacy policy and terms of service
- GDPR compliance: data export, account deletion
